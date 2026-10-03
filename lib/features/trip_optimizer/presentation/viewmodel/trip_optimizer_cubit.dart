import 'dart:async';

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
import 'package:travel_route_optimizer/core/services/fuel_price_service.dart'; // YENİ: Yakıt Servisi
import '../../data/models/spot_model.dart';

class TripOptimizerCubit extends Cubit<TripOptimizerState> {
  final GetCitySpotsUseCase getCitySpotsUseCase;
  final OptimizeRouteUseCase optimizeRouteUseCase;
  final TripRepository repository;

  final AIRouteService aiRouteService = AIRouteService();

  double currentTotalBudget = 0.0;
  List<Map<String, dynamic>> extraExpenses = [];
  String currentCity = "Bilinmeyen Şehir";

  String? mlBudgetWarning;
  double? mlPredictedCost;

  // ==========================================
  // YENİ: YAKIT VE ROADTRIP DEĞİŞKENLERİ
  // ==========================================
  final FuelPriceService fuelPriceService = FuelPriceService();
  bool isRoadtripMode = false;
  Map<String, dynamic>? selectedVehicle;
  Map<String, double>? currentFuelPrices;
  double totalFuelCost = 0.0;

  StreamSubscription? _itinerarySubscription;
  String? currentCloudItineraryId; // O an dinlenen rotanın ID'si

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
          final cloudItineraryId = await repository.saveItineraryToCloud(
            itineraryId: currentCloudItineraryId, // CAN ALICI DOKUNUŞ BURASI!
            userId: currentUserId,
            city: currentCity,
            maxBudget: currentTotalBudget,
            itinerary: itinerary,
          );

          debugPrint("Buluta kayıt/güncelleme başarılı! ☁️✅ ID: $cloudItineraryId");

          if (cloudItineraryId != null) {
            listenToCloudItinerary(cloudItineraryId);
          }

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

  Future<String?> replaceSpotWithAIAlternatives(ItineraryDayEntity dayPlan, SpotEntity oldSpot) async {
    try {
      debugPrint("🔄 [AI] Alternatif mekan üretme başlıyor... Şehir: $currentCity, Mekan: ${oldSpot.name}");

      final newSpotsData = await aiRouteService.getAlternatives(
        city: currentCity,
        placeToReplace: oldSpot.name,
      );

      debugPrint("🔄 [AI] Gemini'den ${newSpotsData.length} adet alternatif döndü.");

      if (newSpotsData.isNotEmpty) {
        List<SpotEntity> newSpots = newSpotsData.map((json) {
          debugPrint("🔄 [AI] JSON parse ediliyor: $json");
          return SpotModel.fromJson(json);
        }).toList();

        debugPrint("🔄 [AI] ${newSpots.length} adet SpotModel oluşturuldu.");

        final spotIndex = dayPlan.places.indexWhere((s) => s.name == oldSpot.name);
        debugPrint("🔄 [AI] Eski mekan index: $spotIndex");

        if (spotIndex != -1) {
          final mutablePlaces = List<SpotEntity>.from(dayPlan.places);
          mutablePlaces.removeAt(spotIndex);
          mutablePlaces.insertAll(spotIndex, newSpots);

          dayPlan.places.clear();
          dayPlan.places.addAll(mutablePlaces);

          debugPrint("✅ [AI] Mekan başarıyla değiştirildi! Yeni liste: ${dayPlan.places.map((s) => s.name).toList()}");

          emit(BudgetUpdatedState());
          return null;
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

      List<String> allCategories = [];
      for (var day in itinerary) {
        for (var spot in day.places) {
          allCategories.add(spot.category.toLowerCase());
        }
      }

      final result = await repository.predictBudget(
        city: currentCity,
        places: allCategories,
        userBudget: currentTotalBudget,
      );

      debugPrint("🔮 [ML] Sonuç: $result");

      if (result['budget_status'] == 'warning') {
        mlBudgetWarning = result['message'];
      } else {
        mlBudgetWarning = null;
      }

      mlPredictedCost = (result['predicted_cost'] as num).toDouble();

      emit(BudgetUpdatedState());

    } catch (e) {
      debugPrint("❌ [ML] Bütçe Kâhini Hatası: $e");
    }
  }

  // ==========================================
  // YENİ: ROADTRIP VE YAKIT HESAPLAMA MOTORU
  // ==========================================
  Future<void> calculateRoadtripCost(Map<String, dynamic> vehicle, List<ItineraryDayEntity> itinerary) async {
    emit(TripOptimizerLoading());
    try {
      isRoadtripMode = true;
      selectedVehicle = vehicle;

      if (currentFuelPrices == null) {
        debugPrint("⛽ Yakıt fiyatları CollectAPI'den çekiliyor... Şehir: $currentCity");
        currentFuelPrices = await fuelPriceService.getCurrentFuelPrices(currentCity);
      }

      double totalKm = 0.0;
      for (var day in itinerary) {
        totalKm += day.estimatedWalkingKm;
      }

      double realDrivingKm = (totalKm * 1.5) + 10.0;

      double consumption = (vehicle['consumption'] as num).toDouble();
      String fuelType = vehicle['type'];

      double pricePerUnit = currentFuelPrices![fuelType] ?? currentFuelPrices!['gasoline']!;

      totalFuelCost = (realDrivingKm / 100) * consumption * pricePerUnit;

      extraExpenses.removeWhere((expense) => expense['title'].toString().startsWith("🚗 Araç Yakıtı"));
      addExtraExpense("🚗 Araç Yakıtı (${vehicle['name']})", totalFuelCost);

      debugPrint("🚙 Roadtrip Hesaplandı: $realDrivingKm km, Tutar: $totalFuelCost TL");

      emit(RoadtripModeActivated(totalFuelCost, vehicle['name']));
      emit(BudgetUpdatedState());

    } catch (e) {
      debugPrint("❌ Yakıt hesaplanırken hata oluştu: $e");
      emit(TripOptimizerError("Yakıt hesaplanırken hata: $e"));
    }
  }

  void disableRoadtripMode() {
    isRoadtripMode = false;
    selectedVehicle = null;
    totalFuelCost = 0.0;

    extraExpenses.removeWhere((expense) => expense['title'].toString().startsWith("🚗 Araç Yakıtı"));

    emit(BudgetUpdatedState());
  }

  void listenToCloudItinerary(String itineraryId) {
    // Eğer halihazırda başka bir rotayı dinliyorsak önce onu iptal et
    _itinerarySubscription?.cancel();
    currentCloudItineraryId = itineraryId;

    debugPrint("📡 Supabase Real-time dinlemesi başlatılıyor... Rota ID: $itineraryId");

    try {
      _itinerarySubscription = repository.listenToItineraryChanges(itineraryId).listen((cloudData) {
        if (cloudData.isNotEmpty) {
          debugPrint("⚡ [REAL-TIME] Buluttan yeni veri geldi!");

          // Buluttan gelen JSON'ı Entity'ye çeviriyoruz
          final List<ItineraryDayEntity> updatedItinerary = cloudData.map((dayJson) {
            final List placesList = dayJson['places'] ?? [];
            return ItineraryDayEntity(
              day: dayJson['day'],
              estimatedWalkingKm: (dayJson['estimated_walking_km'] as num).toDouble(),
              places: placesList.map((spotJson) => SpotModel(
                name: spotJson['name'],
                category: spotJson['category'],
                rating: (spotJson['rating'] as num).toDouble(),
                entryFee: (spotJson['entry_fee'] as num).toDouble(),
                lat: (spotJson['lat'] as num).toDouble(),
                lng: (spotJson['lng'] as num).toDouble(),
                isOutdoor: spotJson['is_outdoor'] ?? false,
              )).toList(),
            );
          }).toList();

          // Arayüzü tetiklemek için State güncelliyoruz
          emit(RouteOptimized(updatedItinerary));

          // Eğer araç modu açıksa mesafeler değiştiği için maliyeti yeniden hesapla
          if (isRoadtripMode && selectedVehicle != null) {
            calculateRoadtripCost(selectedVehicle!, updatedItinerary);
          }
        }
      });
    } catch (e) {
      debugPrint("❌ Real-time dinleme hatası: $e");
    }
  }

  /// Haritadan çıkıldığında veya başka rotaya geçildiğinde Stream'i kapat
  void stopListeningToCloud() {
    _itinerarySubscription?.cancel();
    _itinerarySubscription = null;
    currentCloudItineraryId = null;
    debugPrint("🔇 Supabase Real-time dinlemesi durduruldu.");
  }

  // Kübit kapandığında Stream'in açık kalıp hafıza sızdırmasını (memory leak) önle
  @override
  Future<void> close() {
    _itinerarySubscription?.cancel();
    return super.close();
  }


}