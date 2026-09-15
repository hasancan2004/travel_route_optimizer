import 'package:dio/dio.dart';
import '../models/itinerary_day_model.dart';
import '../models/spot_model.dart';

abstract class TripRemoteDataSource {
  Future<List<SpotModel>> getCitySpots(String city);

  Future<List<SpotModel>> getRadarSpots(double lat, double lng, {double radius = 1500});

  Future<List<ItineraryDayModel>> optimizeRoute({
    required List<String> userInterests,
    required double maxBudget,
    required int totalDays,
    required double maxWalkPerDay,
    required List<Map<String, dynamic>> places,
  });

  Future<void> saveItineraryToCloud({
    required String userId,
    required String city,
    required double maxBudget,
    required List<Map<String, dynamic>> itinerary,
  });

  // 1. Arayüze keşfet imzasını ekledik
  Future<List<Map<String, dynamic>>> exploreItineraries();

  // 2. Arayüze paylaş imzasını ekledik
  Future<void> shareItinerary({
    required String userId,
    required String authorName,
    required String city,
    required String title,
    required double maxBudget,
    required List<Map<String, dynamic>> itinerary,
  });
}

class TripRemoteDataSourceImpl implements TripRemoteDataSource {
  final Dio dio;
  final String baseUrl = 'https://travel-optimizer-api.onrender.com';

  TripRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<SpotModel>> getCitySpots(String city) async {
    final response = await dio.get('$baseUrl/spots/$city');
    if (response.statusCode == 200) {
      final List spotsJson = response.data['spots'];
      return spotsJson.map((json) => SpotModel.fromJson(json)).toList();
    } else {
      throw Exception('Mekanlar getirilirken hata oluştu');
    }
  }

  @override
  Future<List<SpotModel>> getRadarSpots(double lat, double lng, {double radius = 1500}) async {
    final response = await dio.get('$baseUrl/radar', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radius': radius.toInt(),
    });

    if (response.statusCode == 200) {
      final List spotsJson = response.data['spots'];
      return spotsJson.map((json) => SpotModel.fromJson(json)).toList();
    } else {
      throw Exception('Radar taraması başarısız oldu');
    }
  }

  @override
  Future<List<ItineraryDayModel>> optimizeRoute({
    required List<String> userInterests,
    required double maxBudget,
    required int totalDays,
    required double maxWalkPerDay,
    required List<Map<String, dynamic>> places,
  }) async {
    final response = await dio.post(
      '$baseUrl/optimize-route',
      data: {
        "user_interests": userInterests,
        "max_budget": maxBudget,
        "total_days": totalDays,
        "max_walk_per_day": maxWalkPerDay,
        "places": places,
      },
    );

    if (response.statusCode == 200) {
      final List itineraryJson = response.data['itinerary'];
      return itineraryJson.map((json) => ItineraryDayModel.fromJson(json)).toList();
    } else {
      throw Exception('Rota optimize edilirken hata oluştu');
    }
  }

  @override
  Future<void> saveItineraryToCloud({
    required String userId,
    required String city,
    required double maxBudget,
    required List<Map<String, dynamic>> itinerary,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/save-itinerary',
        data: {
          "user_id": userId,
          "city": city,
          "max_budget": maxBudget,
          "itinerary": itinerary,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('API Hatası: ${response.data}');
      }
    } catch (e) {
      throw Exception('Buluta kaydedilirken bağlantı hatası oluştu: $e');
    }
  }

  // 3. BURASI ÖNEMLİ: exploreItineraries fonksiyonunun gövdesi
  @override
  Future<List<Map<String, dynamic>>> exploreItineraries() async {
    try {
      final response = await dio.get('$baseUrl/explore-itineraries');
      if (response.statusCode == 200) {
        final List itinerariesJson = response.data['itineraries'];
        return itinerariesJson.map((json) => json as Map<String, dynamic>).toList();
      } else {
        throw Exception('Keşfet rotaları yüklenirken hata oluştu');
      }
    } catch (e) {
      throw Exception('Bağlantı hatası: $e');
    }
  }

  // 4. BURASI ÖNEMLİ: shareItinerary fonksiyonunun gövdesi
  @override
  Future<void> shareItinerary({
    required String userId,
    required String authorName,
    required String city,
    required String title,
    required double maxBudget,
    required List<Map<String, dynamic>> itinerary,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/share-itinerary',
        data: {
          "user_id": userId,
          "author_name": authorName,
          "city": city,
          "title": title,
          "max_budget": maxBudget,
          "itinerary": itinerary,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('API Paylaşım Hatası: ${response.data}');
      }
    } catch (e) {
      throw Exception('Toplulukta paylaşılırken hata oluştu: $e');
    }
  }
}