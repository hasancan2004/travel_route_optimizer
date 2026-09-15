import '../entities/spot_entity.dart';
import '../repositories/trip_repository.dart';

class GetCitySpotsUseCase {
  final TripRepository repository;

  GetCitySpotsUseCase(this.repository);

  Future<List<SpotEntity>> call(String city) {
    return repository.getCitySpots(city);
  }
}