import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/itinerary_day_entity.dart';
import '../../domain/entities/spot_entity.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../domain/usecases/get_city_spots_usecase.dart';
import '../../domain/usecases/optimize_route_usecase.dart';
import 'trip_optimizer_state.dart';
import 'package:travel_route_optimizer/core/services/ai_route_service.dart';
// spot_model.dart büyük ihtimalle data/models altındadır:
import '../../data/models/spot_model.dart';
class TripOptimizerCubit extends Cubit<TripOptimizerState> {
  final GetCitySpotsUseCase getCitySpotsUseCase;
  final OptimizeRouteUseCase optimizeRouteUseCase;
  final TripRepository repository;

  // YENİ: AI Servisimizi başlatıyoruz
  final AIRouteService aiRouteService = AIRouteService();

  double currentTotalBudget = 0.0;
  List<Map<String, dynamic>> extraExpenses = [];
  String currentCity = "Bilinmeyen Şehir";

  String? mlBudgetWarning; // Makine öğrenmesi uyarısı
  double? mlPredictedCost;

  TripOptimizerCubit({
    required this.getCitySpotsUseCase,
    required this.optimizeRouteUseCase,
    required this.repository,
  }) : super(TripOptimizerInitial());

  Future<void> fetchCitySpots(String city) async {
    emit(TripOptimizerLoading());
    try {
      currentCity = city;
      final spots = await getCitySpotsUseCase(city);
      emit(CitySpotsLoaded(spots));
    } catch (e) {
      emit(TripOptimizerError("Mekanlar yüklenirken hata oluştu: ${e.toString()}"));
    }
  }

  Future<void> optimizeRoute({
    required List<String> userInterests,
    required double maxBudget,
    required int totalDays,
    required double maxWalkPerDay,
    required List<SpotEntity> places,
  }) async {
    emit(TripOptimizerLoading());
    try {
      currentTotalBudget = maxBudget;
      extraExpenses.clear();

      final params = OptimizeRouteParams(
        userInterests: userInterests,
        maxBudget: maxBudget,
        totalDays: totalDays,
        maxWalkPerDay: maxWalkPerDay,
        places: places,
      );
      final itinerary = await optimizeRouteUseCase(params);

      if (itinerary.isEmpty) {
        emit(const TripOptimizerError("Bu parametrelerle rota çizilemedi. Lütfen şehir veya bütçe değiştirin."));
      } else {
        emit(RouteOptimized(itinerary));
      }

    } catch (e) {
      if (e is DioException) {
        if (e.response != null && e.response?.data is Map) {
          final errorData = e.response?.data as Map;
          final detail = errorData['detail'] ?? "Sunucu işleyemedi.";
          emit(TripOptimizerError("Sunucu Hatası: $detail"));
        } else {
          emit(TripOptimizerError("Sunucuya ulaşılamadı. Lütfen bağlantınızı kontrol edin."));
        }
      } else {
        emit(TripOptimizerError("Rota oluşturulamadı: ${e.toString()}"));
      }
    }
  }

  void updateBudget(double newBudget) {
    currentTotalBudget = newBudget;
    emit(BudgetUpdatedState());
  }

  void addExtraExpense(String title, double amount) {
    extraExpenses.add({'title': title, 'amount': amount});
    emit(BudgetUpdatedState());
  }

  Future<void> saveItinerary(List<ItineraryDayEntity> itinerary) async {
    try {
      await repository.saveItinerary(itinerary);
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (currentUserId != null) {
        try {
          await repository.saveItineraryToCloud(
            userId: currentUserId,
            city: currentCity,
            maxBudget: currentTotalBudget,
            itinerary: itinerary,
          );
          debugPrint("Buluta kayıt işlemi başarılı! ☁️✅");
        } catch (cloudError) {
          debugPrint("Buluta kayıt hatası (Lokalde güvende): $cloudError");
        }
      } else {
        debugPrint("Kullanıcı oturum açmadığı için rota sadece yerel hafızaya kaydedildi.");
      }
      emit(ItinerarySaved());
    } catch (e) {
      emit(TripOptimizerError("Rota kaydedilirken hata oluştu: ${e.toString()}"));
    }
  }

  Future<void> autoSaveItinerary(List<ItineraryDayEntity> itinerary) async {
    try {
      await repository.saveItinerary(itinerary);
    } catch (e) {
      debugPrint("Otomatik kaydetme hatası: $e");
    }
  }

  Future<void> getSavedItineraries() async {
    emit(TripOptimizerLoading());
    try {
      final savedItineraries = await repository.getSavedItineraries();
      emit(SavedItinerariesLoaded(savedItineraries));
    } catch (e) {
      emit(TripOptimizerError("Kayıtlı rotalar getirilirken hata: ${e.toString()}"));
    }
  }

  Future<void> loadTravelerStats() async {
    emit(TripOptimizerLoading());
    try {
      final savedItineraries = await repository.getSavedItineraries();
      emit(TravelerStatsLoaded(savedItineraries));
    } catch (e) {
      emit(TripOptimizerError("İstatistikler getirilirken hata: ${e.toString()}"));
    }
  }

  Future<void> exploreItineraries() async {
    emit(TripOptimizerLoading());
    try {
      final itineraries = await repository.exploreItineraries();
      emit(PublicItinerariesLoaded(itineraries));
    } catch (e) {
      emit(TripOptimizerError("Keşfet rotaları yüklenirken hata oluştu: ${e.toString()}"));
    }
  }

  Future<void> shareItinerary({
    required String title,
    required List<ItineraryDayEntity> itinerary,
    String? city,
    double? budget,
  }) async {
    emit(TripOptimizerLoading());
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id ?? "anonim_kullanici";
      final authorName = currentUser?.email?.split('@').first ?? "Gezgin";

      final targetCity = (city != null && city.isNotEmpty) ? city : currentCity;
      final targetBudget = budget ?? currentTotalBudget;

      await repository.shareItinerary(
        userId: userId,
        authorName: authorName,
        city: targetCity,
        title: title,
        maxBudget: targetBudget,
        itinerary: itinerary,
      );
      emit(ItinerarySharedSuccessfully());
    } catch (e) {
      emit(TripOptimizerError("Rota paylaşılırken hata oluştu: ${e.toString()}"));
    }
  }

  Future<void> generateRouteFromAIFlow(String prompt) async {
    emit(TripOptimizerLoading());
    try {
      final aiParams = await repository.analyzePromptWithAI(prompt);

      final city = aiParams['city']?.toString() ?? 'İstanbul';
      double budget = double.tryParse(aiParams['max_budget'].toString()) ?? 1000.0;
      int days = int.tryParse(aiParams['total_days'].toString()) ?? 2;

      List<String> interests = ['history'];
      if (aiParams['user_interests'] is List) {
        interests = List<String>.from(aiParams['user_interests'].map((e) => e.toString()));
        if (interests.isEmpty) interests = ['history'];
      }

      currentCity = city;
      final spots = await getCitySpotsUseCase(city);

      if (spots.isEmpty) {
        emit(const TripOptimizerError("Bu şehir için uygun mekan bulunamadı."));
        return;
      }

      currentTotalBudget = budget;
      extraExpenses.clear();

      final params = OptimizeRouteParams(
        userInterests: interests,
        maxBudget: budget,
        totalDays: days,
        maxWalkPerDay: 5.0,
        places: spots,
      );

      final itinerary = await optimizeRouteUseCase(params);

      if (itinerary.isEmpty) {
        emit(const TripOptimizerError("Mekanlar bulundu ancak ayarlara uygun rota çizilemedi."));
        return;
      }

      emit(RouteOptimized(itinerary));
    } catch (e) {
      emit(TripOptimizerError("AI Asistan Hatası: ${e.toString()}"));
    }
  }

  // ==========================================
  // YENİ: TEKİL MEKAN İÇİN AI ALTERNATİF MOTORU
  // ==========================================
  /// Null dönerse başarılı, String dönerse hata mesajı içerir.
  Future<String?> replaceSpotWithAIAlternatives(ItineraryDayEntity dayPlan, SpotEntity oldSpot) async {
    try {
      debugPrint("🔄 [AI] Alternatif mekan üretme başlıyor... Şehir: $currentCity, Mekan: ${oldSpot.name}");

      // 1. Gemini servisini çağır
      final newSpotsData = await aiRouteService.getAlternatives(
        city: currentCity,
        placeToReplace: oldSpot.name,
      );

      debugPrint("🔄 [AI] Gemini'den ${newSpotsData.length} adet alternatif döndü.");

      if (newSpotsData.isNotEmpty) {
        // 2. Dönen JSON objelerini SpotModel'e çevir
        List<SpotEntity> newSpots = newSpotsData.map((json) {
          debugPrint("🔄 [AI] JSON parse ediliyor: $json");
          return SpotModel.fromJson(json);
        }).toList();

        debugPrint("🔄 [AI] ${newSpots.length} adet SpotModel oluşturuldu.");

        // 3. Eski mekanı listeden bul (isim bazlı arama — Equatable uyumsuzluğunu önler)
        final spotIndex = dayPlan.places.indexWhere((s) => s.name == oldSpot.name);
        debugPrint("🔄 [AI] Eski mekan index: $spotIndex");

        if (spotIndex != -1) {
          // Listeyi mutable hale getir (const constructor'dan gelmiş olabilir)
          final mutablePlaces = List<SpotEntity>.from(dayPlan.places);
          mutablePlaces.removeAt(spotIndex);
          mutablePlaces.insertAll(spotIndex, newSpots);

          // places listesini güncelle
          dayPlan.places.clear();
          dayPlan.places.addAll(mutablePlaces);

          debugPrint("✅ [AI] Mekan başarıyla değiştirildi! Yeni liste: ${dayPlan.places.map((s) => s.name).toList()}");

          // State'i tazeleyerek tüm UI'ın haberdar olmasını sağla
          emit(BudgetUpdatedState());
          return null; // Başarılı
        } else {
          debugPrint("❌ [AI] Eski mekan '${oldSpot.name}' listede bulunamadı!");
          return "Eski mekan '${oldSpot.name}' listede bulunamadı.";
        }
      } else {
        debugPrint("❌ [AI] Gemini alternatif üretemedi (boş liste döndü).");
        return "Gemini boş yanıt döndü. API key veya ağ bağlantısını kontrol edin.";
      }
    } catch (e, stackTrace) {
      debugPrint("❌ [AI] AI Alternatif Hatası: $e");
      debugPrint("❌ [AI] Stack Trace: $stackTrace");
      return "AI Hatası: $e";
    }
  }

  Future<void> checkBudgetWithML(List<ItineraryDayEntity> itinerary) async {
    try {
      debugPrint("🔮 [ML] Bütçe Kâhini çalışıyor...");

      // Tüm rotadaki mekan kategorilerini tek bir listede topluyoruz
      List<String> allCategories = [];
      for (var day in itinerary) {
        for (var spot in day.places) {
          allCategories.add(spot.category.toLowerCase());
        }
      }

      // FastAPI'deki modele (RandomForest) istek atıyoruz
      final result = await repository.predictBudget(
        city: currentCity,
        places: allCategories,
        userBudget: currentTotalBudget,
      );

      debugPrint("🔮 [ML] Sonuç: $result");

      // Eğer bütçe aşımı varsa uyarıyı state'e kaydediyoruz
      if (result['budget_status'] == 'warning') {
        mlBudgetWarning = result['message'];
      } else {
        mlBudgetWarning = null;
      }

      mlPredictedCost = (result['predicted_cost'] as num).toDouble();

      // Arayüzü (itinerary_view) tetikleyip uyarıyı ekranda gösteriyoruz
      emit(BudgetUpdatedState());

    } catch (e) {
      debugPrint("❌ [ML] Bütçe Kâhini Hatası: $e");
    }
  }
}
