import 'package:equatable/equatable.dart';
import '../../domain/entities/itinerary_day_entity.dart';
import '../../domain/entities/spot_entity.dart';

abstract class TripOptimizerState extends Equatable {
  const TripOptimizerState();

  @override
  List<Object?> get props => [];
}

class TripOptimizerInitial extends TripOptimizerState {}

class TripOptimizerLoading extends TripOptimizerState {}

class CitySpotsLoaded extends TripOptimizerState {
  final List<SpotEntity> spots;

  const CitySpotsLoaded(this.spots);

  @override
  List<Object?> get props => [spots];
}

class RouteOptimized extends TripOptimizerState {
  final List<ItineraryDayEntity> itinerary;

  const RouteOptimized(this.itinerary);

  @override
  List<Object?> get props => [itinerary];
}

// YENİ: Rota başarıyla kaydedildiğinde arayüzü tetikleyecek state
class ItinerarySaved extends TripOptimizerState {}

// YENİ: Kayıtlı rotalar veritabanından çekildiğinde arayüzü tetikleyecek state
class SavedItinerariesLoaded extends TripOptimizerState {
  final List<List<ItineraryDayEntity>> savedItineraries;

  const SavedItinerariesLoaded(this.savedItineraries);

  @override
  List<Object?> get props => [savedItineraries];
}

class TripOptimizerError extends TripOptimizerState {
  final String message;

  const TripOptimizerError(this.message);

  @override
  List<Object?> get props => [message];
}

class BudgetUpdatedState extends TripOptimizerState {}

// YENİ: Topluluk keşfet rotaları yüklendiğinde arayüzü tetikleyecek state
class PublicItinerariesLoaded extends TripOptimizerState {
  final List<Map<String, dynamic>> publicItineraries;

  const PublicItinerariesLoaded(this.publicItineraries);

  @override
  List<Object?> get props => [publicItineraries];
}

// YENİ: Rota başarıyla toplulukta paylaşıldığında tetiklenecek state
class ItinerarySharedSuccessfully extends TripOptimizerState {}