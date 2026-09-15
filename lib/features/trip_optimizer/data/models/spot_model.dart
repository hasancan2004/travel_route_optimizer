import 'package:hive/hive.dart';
import '../../domain/entities/spot_entity.dart';

part 'spot_model.g.dart';

@HiveType(typeId: 0)
class SpotModel extends SpotEntity {
  @override
  @HiveField(0)
  final String name;

  @override
  @HiveField(1)
  final String category;

  @override
  @HiveField(2)
  final double rating;

  @override
  @HiveField(3)
  final double entryFee;

  @override
  @HiveField(4)
  final double lat;

  @override
  @HiveField(5)
  final double lng;

  @override
  @HiveField(6)
  final double? calculatedScore;

  @override
  @HiveField(7)
  final String? imagePath;

  @override
  @HiveField(8) // YENİ: Yağmur / hava durumu optimizasyonu için açık hava alanı
  final bool isOutdoor;

  const SpotModel({
    required this.name,
    required this.category,
    required this.rating,
    required this.entryFee,
    required this.lat,
    required this.lng,
    this.calculatedScore,
    this.imagePath,
    this.isOutdoor = false, // YENİ
  }) : super(
    name: name,
    category: category,
    rating: rating,
    entryFee: entryFee,
    lat: lat,
    lng: lng,
    calculatedScore: calculatedScore,
    imagePath: imagePath,
    isOutdoor: isOutdoor, // YENİ
  );

  factory SpotModel.fromJson(Map<String, dynamic> json) {
    return SpotModel(
      name: json['name'] ?? '',
      category: json['category'] ?? 'custom',
      rating: (json['rating'] ?? 0.0).toDouble(),
      entryFee: (json['entry_fee'] ?? json['entryFee'] ?? 0.0).toDouble(),
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      calculatedScore: json['calculated_score'] != null
          ? (json['calculated_score'] as num).toDouble()
          : null,
      imagePath: json['imagePath'],
      isOutdoor: json['is_outdoor'] ?? json['isOutdoor'] ?? false, // YENİ
    );
  }
}