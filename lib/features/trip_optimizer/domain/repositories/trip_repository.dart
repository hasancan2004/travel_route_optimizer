import '../entities/itinerary_day_entity.dart';
import '../entities/spot_entity.dart';

abstract class TripRepository {
  /// Backend'den (GET /spots/{city}) belirtilen şehrin mekanlarını çeker.
  Future<List<SpotEntity>> getCitySpots(String city);

  /// Kullanıcı tercihlerini backend'e (POST /optimize-route) gönderip
  /// günlere bölünmüş optimize seyahat rotasını döndürür.
  Future<List<ItineraryDayEntity>> optimizeRoute({
    required List<String> userInterests,
    required double maxBudget,
    required int totalDays,
    required double maxWalkPerDay,
    required List<SpotEntity> places,
  });

  // Çevrimdışı (Yerel Veritabanı) kayıt işlemleri
  Future<void> saveItinerary(List<ItineraryDayEntity> itinerary);
  Future<List<List<ItineraryDayEntity>>> getSavedItineraries();

  // YENİ: Bulut (Supabase) kayıt işlemi
  Future<void> saveItineraryToCloud({
    required String userId,
    required String city,
    required double maxBudget,
    required List<ItineraryDayEntity> itinerary,
  });

  // YENİ: Topluluk rotalarını keşfetmek için
  Future<List<Map<String, dynamic>>> exploreItineraries();

  // YENİ: Rotayı topluluk havuzunda paylaşmak için
  Future<void> shareItinerary({
    required String userId,
    required String authorName,
    required String city,
    required String title,
    required double maxBudget,
    required List<ItineraryDayEntity> itinerary,
  });
}