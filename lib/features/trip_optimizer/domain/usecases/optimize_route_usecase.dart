import '../entities/itinerary_day_entity.dart';
import '../entities/spot_entity.dart';
import '../repositories/trip_repository.dart';

class OptimizeRouteParams {
  final List<String> userInterests;
  final double maxBudget;
  final int totalDays;
  final double maxWalkPerDay;
  final List<SpotEntity> places;

  OptimizeRouteParams({
    required this.userInterests,
    required this.maxBudget,
    required this.totalDays,
    required this.maxWalkPerDay,
    required this.places,
  });
}

class OptimizeRouteUseCase {
  final TripRepository repository;

  OptimizeRouteUseCase(this.repository);

  Future<List<ItineraryDayEntity>> call(OptimizeRouteParams params) {
    return repository.optimizeRoute(
      userInterests: params.userInterests,
      maxBudget: params.maxBudget,
      totalDays: params.totalDays,
      maxWalkPerDay: params.maxWalkPerDay,
      places: params.places,
    );
  }
}