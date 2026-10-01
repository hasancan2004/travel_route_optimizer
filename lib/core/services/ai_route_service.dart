import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';

class AIRouteService {
  final Dio _dio = Dio();

  Future<List<Map<String, dynamic>>> getAlternatives({
    required String city,
    required String placeToReplace,
    String? weatherCondition,
    String? preferences,
  }) async {
    // 1. API Key'i .env dosyasından çekiyoruz
    final rawApiKey = dotenv.env['GEMINI_API_KEY'];

    if (rawApiKey == null || rawApiKey.isEmpty) {
      throw Exception('Gemini API Key .env dosyasında bulunamadı!');
    }

    // Olası tırnak ve boşlukları temizle
    final apiKey = rawApiKey.replaceAll('"', '').replaceAll("'", '').trim();
    debugPrint("🔑 [AI] API Key uzunluğu: ${apiKey.length}, ilk 4 karakter: '${apiKey.substring(0, apiKey.length >= 4 ? 4 : apiKey.length)}'");

    // 2. Prompt Mühendisliği
    final prompt = '''
Kullanıcı şu an $city şehrinde seyahat ediyor. Rotasındaki "$placeToReplace" adlı mekana gitmekten vazgeçti veya gidemiyor.
Hava durumu durumu: ${weatherCondition ?? 'Bilinmiyor / Açık'}
Kullanıcının ilgi alanları: ${preferences ?? 'Tarih, Doğa, Genel'}

Bunun yerine gidebileceği 2 harika alternatif mekan öner. 
Mekanlar GERÇEK mekanlar olsun ve koordinatları doğru olsun.
Yanıtta ASLA giriş veya sonuç cümlesi kurma. 
Yanıtta ASLA markdown (\`\`\`json vb.) kullanma.
SADECE aşağıdaki yapıya birebir uyan geçerli bir JSON dizisi döndür:

[
  {
    "name": "Gerçek Mekan Adı",
    "category": "Doğa/Tarih/Yemek/Alışveriş/Eğlence",
    "rating": 4.5,
    "entry_fee": 150.0,
    "lat": 36.908123,
    "lng": 30.695123,
    "is_outdoor": false
  },
  {
    "name": "Diğer Gerçek Mekan Adı",
    "category": "Doğa/Tarih/Yemek/Alışveriş/Eğlence",
    "rating": 4.2,
    "entry_fee": 100.0,
    "lat": 36.901234,
    "lng": 30.701234,
    "is_outdoor": true
  }
]
''';

    debugPrint("🤖 [AI] Gemini REST API'ye istek gönderiliyor... Şehir: $city, Mekan: $placeToReplace");

    // 3. Gemini REST API'ye doğrudan HTTP isteği at
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$apiKey';

    Response response;
    try {
      response = await _dio.post(
        url,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => true, // Tüm status kodlarını kabul et (hata fırlatmasın)
        ),
        data: {
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 2048,
            // gemini-3.8-flash bir "thinking" modelidir. Thinking açık kalırsa
            // düşünme tokenları maxOutputTokens bütçesini aşıp yanıtı (JSON'u)
            // kesiyordu (finishReason: MAX_TOKENS) ve API bazen 503 dönüyordu.
            'thinkingConfig': {
              'thinkingBudget': 0,
            },
          },
        },
      );
    } on DioException catch (e) {
      debugPrint("❌ [AI] Dio Ağ Hatası: ${e.type} - ${e.message}");
      throw Exception('Ağ hatası: ${e.type} - ${e.message}');
    }

    debugPrint("🤖 [AI] HTTP Status: ${response.statusCode}");
    debugPrint("🤖 [AI] Tam Yanıt: ${response.data}");

    // 4. HTTP hata kontrolü
    if (response.statusCode != 200) {
      final errorBody = response.data;
      String errorDetail = 'HTTP ${response.statusCode}';
      if (errorBody is Map) {
        final errorMsg = errorBody['error']?['message'] ?? errorBody.toString();
        final errorStatus = errorBody['error']?['status'] ?? '';
        errorDetail = '[$errorStatus] $errorMsg';
      }
      debugPrint("❌ [AI] API Hatası: $errorDetail");
      throw Exception('Gemini API: $errorDetail');
    }

    // 5. Response'tan text'i çıkar
    final responseData = response.data;
    String? text;

    final candidates = responseData['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      // promptFeedback kontrolü (güvenlik filtresine takılmış olabilir)
      final promptFeedback = responseData['promptFeedback'];
      debugPrint("❌ [AI] Candidates boş! promptFeedback: $promptFeedback");
      throw Exception('Gemini yanıt döndürmedi. promptFeedback: $promptFeedback');
    }

    final candidate = candidates[0];
    final finishReason = candidate['finishReason'];
    debugPrint("🤖 [AI] Finish Reason: $finishReason");

    // Safety ile engellenmiş mi?
    if (finishReason == 'SAFETY') {
      final safetyRatings = candidate['safetyRatings'];
      debugPrint("❌ [AI] Güvenlik filtresi engelledi! Ratings: $safetyRatings");
      throw Exception('Güvenlik filtresi engelledi: $safetyRatings');
    }

    final content = candidate['content'];
    if (content == null) {
      throw Exception('Gemini content alanı boş. finishReason: $finishReason');
    }

    final parts = content['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini parts alanı boş. finishReason: $finishReason');
    }

    text = parts[0]['text'] as String?;
    debugPrint("🤖 [AI] Çıkarılan text: $text");

    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini boş text döndü. finishReason: $finishReason');
    }

    // 6. JSON temizleme ve parse
    String cleanJson = text
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final startIndex = cleanJson.indexOf('[');
    final endIndex = cleanJson.lastIndexOf(']');

    if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
      debugPrint("❌ [AI] Geçerli JSON bulunamadı: $cleanJson");
      throw Exception('Gemini geçersiz JSON döndü: ${cleanJson.substring(0, cleanJson.length > 100 ? 100 : cleanJson.length)}');
    }

    cleanJson = cleanJson.substring(startIndex, endIndex + 1);
    debugPrint("✅ [AI] Temizlenmiş JSON: $cleanJson");

    final List<dynamic> decoded = jsonDecode(cleanJson);
    debugPrint("✅ [AI] Başarıyla ${decoded.length} alternatif mekan parse edildi.");

    return List<Map<String, dynamic>>.from(decoded);
  }
}