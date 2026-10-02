import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FuelPriceService {
  final Dio _dio = Dio();

  /// Bulunulan şehre göre güncel benzin, motorin ve LPG fiyatlarını çeker.
  Future<Map<String, double>> getCurrentFuelPrices(String city) async {
    try {
      // CollectAPI veya benzeri bir servisin anahtarını .env'den alıyoruz
      final apiKey = dotenv.env['COLLECT_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        return _getFallbackPrices();
      }

      // Şehir ismini API'nin anlayacağı formata (küçük harf vb.) çevirebiliriz
      final safeCity = city.toLowerCase().replaceAll(' ', '');

      final response = await _dio.get(
          'https://api.collectapi.com/gasPrice/turkeyGasoline?district=$safeCity',
          options: Options(
            headers: {
              'authorization': 'apikey $apiKey',
              'content-type': 'application/json'
            },
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          )
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List results = response.data['result'];

        // API'den gelen veriyi parse ediyoruz
        double gasoline = 0.0;
        double diesel = 0.0;
        double lpg = 0.0;

        for (var item in results) {
          final mark = item['marka'].toString().toLowerCase();
          // Ortalama bir markayı (örn: Opet veya Petrol Ofisi) baz alabiliriz
          if (mark.contains('opet')) {
            gasoline = double.tryParse(item['benzin']) ?? _getFallbackPrices()['gasoline']!;
            diesel = double.tryParse(item['motorin']) ?? _getFallbackPrices()['diesel']!;
            lpg = double.tryParse(item['katkilimotorin']) ?? _getFallbackPrices()['lpg']!; // lpg bazen farklı alanda dönebilir
            break;
          }
        }

        // Eğer marka bulunamadıysa ilk sıradakini al
        if (gasoline == 0.0 && results.isNotEmpty) {
          gasoline = double.tryParse(results[0]['benzin']) ?? _getFallbackPrices()['gasoline']!;
          diesel = double.tryParse(results[0]['motorin']) ?? _getFallbackPrices()['diesel']!;
        }

        return {
          "gasoline": gasoline,
          "diesel": diesel,
          "lpg": lpg,
        };
      }

      return _getFallbackPrices();
    } catch (e) {
      // İnternet yoksa veya API patlarsa çökme, yedek fiyatları dön
      return _getFallbackPrices();
    }
  }

  /// API'ye ulaşılamadığında kullanılacak varsayılan güncel fiyatlar
  Map<String, double> _getFallbackPrices() {
    return {
      "gasoline": 92.50, // Benzin ortalama
      "diesel": 94.30,   // Motorin (Mazot) ortalama
      "lpg": 45.10,      // LPG ortalama
      "electric": 4.50   // kWh başına elektrik (Ev/İstasyon ortalaması)
    };
  }
}

/// Uygulama içinde hazır sunulacak araç modelleri ve 100km'deki ortalama tüketimleri
class VehicleModels {
  static const List<Map<String, dynamic>> presetCars = [
    {"name": "Skoda Octavia 1.0 e-TEC (Sedan)", "type": "gasoline", "consumption": 5.2},
    {"name": "Toyota Corolla 1.5 (Sedan)", "type": "gasoline", "consumption": 6.5},
    {"name": "Honda Civic 1.5 VTEC (Sedan)", "type": "gasoline", "consumption": 6.7},
    {"name": "Volkswagen T-Roc 1.5 TSI (SUV)", "type": "gasoline", "consumption": 6.3},
    {"name": "Mercedes C200d (Sedan)", "type": "diesel", "consumption": 5.5},
    {"name": "Togg T10X V2 (Elektrikli SUV)", "type": "electric", "consumption": 18.5}, // 100km'de 18.5 kWh
    {"name": "Kendi Aracım (Manuel Gir)", "type": "custom", "consumption": 7.0},
  ];
}