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

  Future<List<Map<String, dynamic>>> exploreItineraries();

  Future<void> shareItinerary({
    required String userId,
    required String authorName,
    required String city,
    required String title,
    required double maxBudget,
    required List<Map<String, dynamic>> itinerary,
  });

  Future<List<List<ItineraryDayModel>>> getUserItinerariesFromCloud(String userId);

  Future<Map<String, dynamic>> analyzePromptWithAI(String prompt);

  // YENİ: Makine Öğrenmesi (Bütçe Kâhini) için API imzamız
  Future<Map<String, dynamic>> predictBudget({
    required String city,
    required List<String> places,
    required double userBudget,
  });
}

class TripRemoteDataSourceImpl implements TripRemoteDataSource {
  final Dio dio;
  final String baseUrl = 'https://travel-optimizer-api.onrender.com';
  //final String baseUrl = 'http://10.0.2.2:8000';

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

  @override
  Future<List<List<ItineraryDayModel>>> getUserItinerariesFromCloud(String userId) async {
    try {
      final response = await dio.get('$baseUrl/user-itineraries/$userId');
      if (response.statusCode == 200) {
        final List data = response.data['itineraries'];
        return data.map<List<ItineraryDayModel>>((itineraryJson) {
          final List daysList = itineraryJson['itinerary'];
          return daysList.map((dayJson) => ItineraryDayModel.fromJson(dayJson)).toList();
        }).toList();
      } else {
        throw Exception('Bulut rotaları çekilemedi');
      }
    } catch (e) {
      throw Exception('Buluttan veri getirilirken hata: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> analyzePromptWithAI(String prompt) async {
    try {
      final response = await dio.post(
        '$baseUrl/ai-analyze-prompt',
        data: {"prompt": prompt},
      );

      if (response.statusCode == 200) {
        return response.data['data'] as Map<String, dynamic>;
      } else {
        throw Exception('Sunucu Hatası: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMessage = errorData != null && errorData['detail'] != null
          ? errorData['detail']
          : e.message;
      throw Exception('Backend Diyor ki: $errorMessage');
    } catch (e) {
      throw Exception('Bilinmeyen Hata: $e');
    }
  }

  // ==========================================
  // YENİ: MAKİNE ÖĞRENMESİ (BÜTÇE KÂHİNİ) İSTEĞİ
  // ==========================================
  @override
  Future<Map<String, dynamic>> predictBudget({
    required String city,
    required List<String> places,
    required double userBudget,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/predict-budget',
        data: {
          "city": city,
          "places": places,
          "user_budget": userBudget,
        },
      );

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Bütçe Kâhini Sunucu Hatası: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorData = e.response?.data;
      final errorMessage = errorData != null && errorData['detail'] != null
          ? errorData['detail']
          : e.message;
      throw Exception('Bütçe Kâhini Hatası: $errorMessage');
    } catch (e) {
      throw Exception('Bilinmeyen Kâhin Hatası: $e');
    }
  }
}