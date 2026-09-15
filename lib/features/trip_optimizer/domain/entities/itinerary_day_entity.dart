import 'package:equatable/equatable.dart';
import 'spot_entity.dart';

class ItineraryDayEntity extends Equatable {
  final int day;
  final List<SpotEntity> places;
  final double estimatedWalkingKm;

  const ItineraryDayEntity({
    required this.day,
    required this.places,
    required this.estimatedWalkingKm,
  });

  @override
  List<Object?> get props => [day, places, estimatedWalkingKm];
}