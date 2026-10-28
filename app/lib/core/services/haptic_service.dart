import 'package:flutter/services.dart';
import '../constants/haptic_patterns.dart';

class HapticService {
  static const MethodChannel _channel = MethodChannel('netrava.app/haptics');

  /// Batalkan getaran aktif
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod('cancel');
    } catch (_) {}
  }

  /// Cek apakah hardware ponsel mendukung modulasi amplitudo (0-255)
  static Future<bool> hasAmplitudeControl() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('hasAmplitudeControl');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Pemicuan pola getaran taktil berjenjang sesuai zona bahaya
  static Future<void> triggerZone(ProximityZone zone) async {
    try {
      switch (zone) {
        case ProximityZone.clear:
          await cancel();
          break;
        case ProximityZone.awareness:
          await _channel.invokeMethod('vibrateWaveform', {
            'timings': HapticPatterns.awarenessTimings,
            'amplitudes': HapticPatterns.awarenessAmplitudes,
          });
          break;
        case ProximityZone.caution:
          await _channel.invokeMethod('vibrateWaveform', {
            'timings': HapticPatterns.cautionTimings,
            'amplitudes': HapticPatterns.cautionAmplitudes,
          });
          break;
        case ProximityZone.critical:
          await _channel.invokeMethod('vibrateWaveform', {
            'timings': HapticPatterns.criticalTimings,
            'amplitudes': HapticPatterns.criticalAmplitudes,
          });
          break;
      }
    } catch (_) {}
  }
}
