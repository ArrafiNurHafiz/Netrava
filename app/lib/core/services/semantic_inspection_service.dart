import 'dart:convert';
import 'package:http/http.dart' as http;

class SemanticInspectionService {
  // Alamat gateway 9Router lokal host & API Key
  // Default port: 20128
  static String baseUrl = 'http://192.168.1.104:20128/v1';
  static String apiKey = 'sk-dde...1e47'; // 9Router default key
  static String model = 'rap'; // Combo rap (Google Gemini flash backend)

  static bool _isInspecting = false;
  static bool get isInspecting => _isInspecting;

  /// Konfigurasi URL gateway 9Router jika IP perangkat berubah
  static void configure({String? url, String? key, String? modelName}) {
    if (url != null && url.isNotEmpty) baseUrl = url;
    if (key != null && key.isNotEmpty) apiKey = key;
    if (modelName != null && modelName.isNotEmpty) model = modelName;
  }

  /// Analisis citra frame kamera secara semantik cerdas
  static Future<String?> inspectScene({
    required List<int> imageJpgBytes,
    String? userPrompt,
  }) async {
    if (_isInspecting) return null;
    _isInspecting = true;

    try {
      final base64Image = base64Encode(imageJpgBytes);
      final promptText = userPrompt ??
          'Anda adalah asisten tunanetra Netrava. Jelaskan foto ini dalam maksimal 2 kalimat lugas Bahasa Indonesia: '
          '1. Apa objek atau rintangan utama di depan (posisi kiri/kanan/tengah). '
          '2. Berikan instruksi langkah aman.';

      final url = Uri.parse('$baseUrl/chat/completions');

      final requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': promptText,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
            ],
          },
        ],
        'max_tokens': 120,
      };

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        return content?.toString().trim();
      } else {
        return null;
      }
    } catch (_) {
      return null;
    } finally {
      _isInspecting = false;
    }
  }
}
