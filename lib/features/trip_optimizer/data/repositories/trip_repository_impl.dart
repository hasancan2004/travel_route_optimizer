import '../../domain/entities/itinerary_day_entity.dart';
import '../../domain/entities/spot_entity.dart';
import '../../domain/repositories/trip_repository.dart';
import '../datasources/trip_remote_data_source.dart';
import '../datasources/trip_local_data_source.dart';
import '../datasources/weather_remote_data_source.dart'; // YENİ: Hava durumu servisi
import '../models/itinerary_day_model.dart';
import '../models/spot_model.dart';

class TripRepositoryImpl implements TripRepository {
  final TripRemoteDataSource remoteDataSource;
  final TripLocalDataSource localDataSource;
  final WeatherRemoteDataSource weatherRemoteDataSource; // YENİ: Enjekte ediliyor

  TripRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.weatherRemoteDataSource,
  });

  @override
  Future<List<SpotEntity>> getCitySpots(String city) async {
    return await remoteDataSource.getCitySpots(city);
  }

  @override
  Future<List<ItineraryDayEntity>> optimizeRoute({
    required List<String> userInterests,
    required double maxBudget,
    required int totalDays,
    required double maxWalkPerDay,
    required List<SpotEntity> places,
  }) async {
    final placesMap = places.map((place) => {
      "name": place.name,
      "category": place.category,
      "rating": place.rating,
      "entry_fee": place.entryFee,
      "lat": place.lat,
      "lng": place.lng,
      "is_outdoor": place.isOutdoor, // YENİ: Backend'e de gönderelim
    }).toList();

    // 1. Önce normal rota optimizasyonunu alıyoruz
    final itinerary = await remoteDataSource.optimizeRoute(
      userInterests: userInterests,
      maxBudget: maxBudget,
      totalDays: totalDays,
      maxWalkPerDay: maxWalkPerDay,
      places: placesMap,
    );

    // 2. YENİ: Hava Durumuna Göre Akıllı Swap (Yağmur Optimizasyonu)
    try {
      if (places.isNotEmpty) {
        // Şehrin merkez koordinatları üzerinden 5 günlük hava tahminini çekiyoruz
        final forecastList = await weatherRemoteDataSource.getWeatherForecast(
          places.first.lat,
          places.first.lng,
        );

        if (forecastList != null && forecastList.isNotEmpty) {
          // Yedek kapalı mekanları SpotModel olarak filtreliyoruz
          final availableIndoorSpots = places.map((p) => SpotModel(
            name: p.name,
            category: p.category,
            rating: p.rating,
            entryFee: p.entryFee,
            lat: p.lat,
            lng: p.lng,
            calculatedScore: p.calculatedScore,
            imagePath: p.imagePath,
            isOutdoor: p.isOutdoor,
          )).where((p) => !p.isOutdoor).toList();

          for (var dayEntity in itinerary) {
            final dayForecasts = forecastList.where((w) {
              return true;
            }).toList();

            bool isRainyDay = dayForecasts.any((w) =>
            w.description.toLowerCase().contains('yağmur') ||
                w.description.toLowerCase().contains('sağanak') ||
                w.description.toLowerCase().contains('rain')
            );

            if (isRainyDay) {
              for (int i = 0; i < dayEntity.places.length; i++) {
                if (dayEntity.places[i].isOutdoor && availableIndoorSpots.isNotEmpty) {
                  final indoorSpot = availableIndoorSpots.removeAt(0);
                  // Artık türler birebir uyuşuyor (SpotModel -> SpotEntity ataması sorunsuz geçer)
                  dayEntity.places[i] = indoorSpot;
                }
              }
            }
          }
        }
      }
    } catch (weatherError) {
      // Hava durumu servisi hata verse bile rota optimizasyonu asla çökmemeli!
      print("Hava durumu optimizasyon hatası (Es geçildi): $weatherError");
    }

    return itinerary;
  }

  // Rotayı yerel veritabanına kaydetme işlemi
  @override
  Future<void> saveItinerary(List<ItineraryDayEntity> itinerary) async {
    final itineraryModels = itinerary.map((day) => ItineraryDayModel(
      day: day.day,
      places: day.places.map((spot) => SpotModel(
        name: spot.name,
        category: spot.category,
        rating: spot.rating,
        entryFee: spot.entryFee,
        lat: spot.lat,
        lng: spot.lng,
        calculatedScore: spot.calculatedScore,
        imagePath: spot.imagePath,
        isOutdoor: spot.isOutdoor,
      )).toList(),
      estimatedWalkingKm: day.estimatedWalkingKm,
    )).toList();

    await localDataSource.saveItinerary(itineraryModels);
  }

  // Kaydedilen rotaları yerel veritabanından getirme
  @override
  Future<List<List<ItineraryDayEntity>>> getSavedItineraries() async {
    return await localDataSource.getSavedItineraries();
  }

  // Buluta kaydetme
  @override
  Future<void> saveItineraryToCloud({
    required String userId,
    required String city,
    required double maxBudget,
    required List<ItineraryDayEntity> itinerary,
  }) async {
    final itineraryJson = itinerary.map((day) => {
      "day": day.day,
      "estimated_walking_km": day.estimatedWalkingKm,
      "places": day.places.map((spot) => {
        "name": spot.name,
        "category": spot.category,
        "rating": spot.rating,
        "entry_fee": spot.entryFee,
        "lat": spot.lat,
        "lng": spot.lng,
        "is_outdoor": spot.isOutdoor,
      }).toList(),
    }).toList();

    await remoteDataSource.saveItineraryToCloud(
      userId: userId,
      city: city,
      maxBudget: maxBudget,
      itinerary: itineraryJson,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> exploreItineraries() async {
    return await remoteDataSource.exploreItineraries();
  }

  @override
  Future<void> shareItinerary({
    required String userId,
    required String authorName,
    required String city,
    required String title,
    required double maxBudget,
    required List<ItineraryDayEntity> itinerary,
  }) async {
    final itineraryJson = itinerary.map((day) => {
      "day": day.day,
      "estimated_walking_km": day.estimatedWalkingKm,
      "places": day.places.map((spot) => {
        "name": spot.name,
        "category": spot.category,
        "rating": spot.rating,
        "entry_fee": spot.entryFee,
        "lat": spot.lat,
        "lng": spot.lng,
        "is_outdoor": spot.isOutdoor,
      }).toList(),
    }).toList();

    await remoteDataSource.shareItinerary(
      userId: userId,
      authorName: authorName,
      city: city,
      title: title,
      maxBudget: maxBudget,
      itinerary: itineraryJson,
    );
  }
}