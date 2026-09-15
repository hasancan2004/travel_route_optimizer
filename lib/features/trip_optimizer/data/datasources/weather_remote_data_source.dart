import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class WeatherRemoteDataSource {
  final String apiKey = "9371a2a336b19b29916ecf48d793db30";

  // Anlık hava durumu (Mevcut fonksiyon)
  Future<WeatherModel?> getWeather(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&units=metric&lang=tr&appid=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonMap = json.decode(response.body);
        return WeatherModel.fromJson(jsonMap);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // YENİ: Hava durumu tahminlerini (Forecast) çeken fonksiyon (Yağmur optimizasyonu için)
  Future<List<WeatherModel>?> getWeatherForecast(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lng&units=metric&lang=tr&appid=$apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonMap = json.decode(response.body);
        final List<dynamic> list = jsonMap['list'] ?? [];

        // Gelen 3 saatlik tahmin listesini WeatherModel nesnelerine dönüştürüyoruz
        return list.map((item) => WeatherModel.fromJson(item)).toList();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}