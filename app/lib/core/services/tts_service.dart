import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInitialized = false;

  /// Inisialisasi Google TTS dengan parameter offline dan bahasa Indonesia
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage("id-ID");
      await _flutterTts.setSpeechRate(0.6); // Sedikit lebih cepat agar tanggap
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Pastikan mode interupsi suara aktif untuk peringatan darurat
      await _flutterTts.setQueueMode(0); // 0 = flush / overwrite queue
      _isInitialized = true;
    } catch (_) {}
  }

  /// Peringatan darurat satu kata ringkas (Auditory Preservation)
  static Future<void> speakAlert(String word) async {
    if (!_isInitialized) await initialize();
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(word);
    } catch (_) {}
  }

  /// Pengumuman status saat layar disentuh (Zero-UI feedback)
  static Future<void> speakStatus(String message) async {
    if (!_isInitialized) await initialize();
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(message);
    } catch (_) {}
  }

  /// Hentikan suara seketika
  static Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
