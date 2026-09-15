import 'package:equatable/equatable.dart';

class WeatherEntity extends Equatable {
  final double temperature;
  final String description;
  final String iconCode;

  const WeatherEntity({
    required this.temperature,
    required this.description,
    required this.iconCode,
  });

  @override
  List<Object?> get props => [temperature, description, iconCode];
}