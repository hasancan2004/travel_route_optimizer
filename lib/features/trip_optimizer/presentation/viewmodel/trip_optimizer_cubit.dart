import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart'; // YENİ: Dio hatalarını yakalamak için
import '../../domain/entities/itinerary_day_entity.dart';
import '../../domain/entities/spot_entity.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../domain/usecases/get_city_spots_usecase.dart';
import '../../domain/usecases/optimize_route_usecase.dart';
import 'trip_optimizer_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripOptimizerCubit extends Cubit<TripOptimizerState> {
  final GetCitySpotsUseCase getCitySpotsUseCase;
  final OptimizeRouteUseCase optimizeRouteUseCase;
  final TripRepository repository;

  double currentTotalBudget = 0.0;
  List<Map<String, dynamic>> extraExpenses = [];
  String currentCity = "Bilinmeyen Şehir";

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

      // Eğer backend boş bir liste dönerse (Mekan yoksa vb.)
      if (itinerary.isEmpty) {
        emit(const TripOptimizerError("Bu parametrelerle rota çizilemedi. Lütfen şehir veya bütçe değiştirin."));
      } else {
        emit(RouteOptimized(itinerary));
      }

    } catch (e) {
      // YENİ ZIRH: DioException (Network/HTTP) hatalarını ayıkla ve insancıl hale getir.
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

  // YENİ: Tamamen otonom Yapay Zeka Akışı
  Future<void> generateRouteFromAIFlow(String prompt) async {
    emit(TripOptimizerLoading());
    try {
      // 1. AI'dan parametreleri al (Sayı/Metin hatalarına karşı korumalı)
      final aiParams = await repository.analyzePromptWithAI(prompt);

      final city = aiParams['city']?.toString() ?? 'İstanbul';
      double budget = double.tryParse(aiParams['max_budget'].toString()) ?? 1000.0;
      int days = int.tryParse(aiParams['total_days'].toString()) ?? 2;

      List<String> interests = ['history'];
      if (aiParams['user_interests'] is List) {
        interests = List<String>.from(aiParams['user_interests'].map((e) => e.toString()));
        if (interests.isEmpty) interests = ['history'];
      }

      // 2. Mekanları sessizce çek (CitySpotsLoaded YAYINLAMIYORUZ)
      currentCity = city;
      final spots = await getCitySpotsUseCase(city);

      if (spots.isEmpty) {
        emit(const TripOptimizerError("Bu şehir için uygun mekan bulunamadı."));
        return;
      }

      // 3. Rotayı sessizce optimize et
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

      // 4. Her şey sorunsuz bittiyse tek seferde ekrana yansıt
      emit(RouteOptimized(itinerary));
    } catch (e) {
      emit(TripOptimizerError("AI Asistan Hatası: ${e.toString()}"));
    }
  }
}