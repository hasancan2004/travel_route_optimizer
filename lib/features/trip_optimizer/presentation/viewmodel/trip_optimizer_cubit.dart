import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  // Bütçe asistanı için kalıcı state verileri
  double currentTotalBudget = 0.0;
  List<Map<String, dynamic>> extraExpenses = [];

  // Hangi şehirde olduğumuzu buluta yazmak için hafızada tutuyoruz
  String currentCity = "Bilinmeyen Şehir";

  TripOptimizerCubit({
    required this.getCitySpotsUseCase,
    required this.optimizeRouteUseCase,
    required this.repository,
  }) : super(TripOptimizerInitial());

  Future<void> fetchCitySpots(String city) async {
    emit(TripOptimizerLoading());
    try {
      currentCity = city; // Şehri bulut kaydı için hafızaya al
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
      // Rota ilk oluşturulurken girilen bütçeyi hafızaya alıyoruz
      currentTotalBudget = maxBudget;
      extraExpenses.clear(); // Yeni rotada eski ekstraları temizle

      final params = OptimizeRouteParams(
        userInterests: userInterests,
        maxBudget: maxBudget,
        totalDays: totalDays,
        maxWalkPerDay: maxWalkPerDay,
        places: places,
      );
      final itinerary = await optimizeRouteUseCase(params);
      emit(RouteOptimized(itinerary));
    } catch (e) {
      emit(TripOptimizerError("Rota oluşturulurken hata oluştu: ${e.toString()}"));
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

  // Manuel Kaydetme (Hem Yerele Hem Supabase Buluta)
  Future<void> saveItinerary(List<ItineraryDayEntity> itinerary) async {
    try {
      // 1. Önce Hive'a (Çevrimdışı yerel veritabanına) kaydet
      await repository.saveItinerary(itinerary);

      // 2. Supabase oturum açmış olan gerçek kullanıcının ID'sini alıyoruz
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
        debugPrint("Kullanıcı oturum açmadığı için rota sadece yerel hafızaya (Hive) kaydedildi.");
      }

      emit(ItinerarySaved());
    } catch (e) {
      emit(TripOptimizerError("Rota kaydedilirken hata oluştu: ${e.toString()}"));
    }
  }

  // Sessiz Otomatik Kaydetme (Sadece Yerele)
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

  // Keşfet ekranı için topluluk rotalarını çekme
  Future<void> exploreItineraries() async {
    emit(TripOptimizerLoading());
    try {
      final itineraries = await repository.exploreItineraries();
      emit(PublicItinerariesLoaded(itineraries));
    } catch (e) {
      emit(TripOptimizerError("Keşfet rotaları yüklenirken hata oluştu: ${e.toString()}"));
    }
  }

  // Rotayı topluluk havuzunda paylaşma
  Future<void> shareItinerary({
    required String title,
    required List<ItineraryDayEntity> itinerary,
    String? city, // Opsiyonel: Eğer dışarıdan şehir gönderilirse onu baz al
    double? budget, // Opsiyonel: Özel bütçe
  }) async {
    emit(TripOptimizerLoading());
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id ?? "anonim_kullanici";
      final authorName = currentUser?.email?.split('@').first ?? "Gezgin";

      // Eğer dışarıdan city veya budget gelmediyse Cubit'in mevcut hafızasındakini kullan
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
}