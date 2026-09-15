import 'package:equatable/equatable.dart';

class SpotEntity extends Equatable {
  final String name;
  final String category;
  final double rating;
  final double entryFee;
  final double lat;
  final double lng;
  final double? calculatedScore;
  final String? imagePath;
  final bool isOutdoor; // YENİ: Mekan açık hava mı? (Yağmur kontrolü için)

  const SpotEntity({
    required this.name,
    required this.category,
    required this.rating,
    required this.entryFee,
    required this.lat,
    required this.lng,
    this.calculatedScore,
    this.imagePath,
    this.isOutdoor = false, // Varsayılan olarak kapalı alan/müze kabul edelim
  });

  @override
  List<Object?> get props => [
    name,
    category,
    rating,
    entryFee,
    lat,
    lng,
    calculatedScore,
    imagePath,
    isOutdoor,
  ];
}