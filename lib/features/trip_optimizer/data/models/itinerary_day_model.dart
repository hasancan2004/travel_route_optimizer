import 'package:hive/hive.dart';
import '../../domain/entities/itinerary_day_entity.dart';
import 'spot_model.dart';

part 'itinerary_day_model.g.dart';

@HiveType(typeId: 1)
class ItineraryDayModel extends ItineraryDayEntity {
  @override
  @HiveField(0)
  final int day;

  @override
  @HiveField(1)
  final List<SpotModel> places;

  @override
  @HiveField(2)
  final double estimatedWalkingKm;

  const ItineraryDayModel({
    required this.day,
    required this.places,
    required this.estimatedWalkingKm,
  }) : super(
    day: day,
    places: places,
    estimatedWalkingKm: estimatedWalkingKm,
  );

  factory ItineraryDayModel.fromJson(Map<String, dynamic> json) {
    var placesList = json['places'] as List;
    List<SpotModel> mappedPlaces = placesList.map((e) => SpotModel.fromJson(e)).toList();

    return ItineraryDayModel(
      day: json['day'],
      places: mappedPlaces,
      estimatedWalkingKm: (json['estimated_walking_km'] as num).toDouble(),
    );
  }
}