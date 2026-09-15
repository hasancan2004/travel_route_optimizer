import '../../domain/entities/weather_entity.dart';

class WeatherModel extends WeatherEntity {
  const WeatherModel({
    required super.temperature,
    required super.description,
    required super.iconCode,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      // OpenWeatherMap sıcaklığı 'main.temp' içinde gönderiyor
      temperature: (json['main']['temp'] as num).toDouble(),
      // Hava durumu açıklaması 'weather' listesinin ilk elemanında
      description: json['weather'][0]['description'],
      // İkon kodu (örn: 10d, 01n)
      iconCode: json['weather'][0]['icon'],
    );
  }
}