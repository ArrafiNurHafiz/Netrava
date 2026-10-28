import 'dart:async';
import '../constants/haptic_patterns.dart';
import 'haptic_service.dart';
import 'tts_service.dart';
import 'deterministic_proximity_engine.dart';

class ArbitrationEngine {
  ProximityZone _currentZone = ProximityZone.clear;
  bool _isSilentMode = false;
  bool _isActive = true;

  DateTime _lastHapticTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSpeechAlertTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAutoAiInspectionTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Interval anti-fatigue agar tidak terjadi haptic & speech saturation
  static const Duration _hapticCooldown = Duration(milliseconds: 250);
  static const Duration _speechCooldown = Duration(milliseconds: 1800);
  static const Duration _autoAiCooldown = Duration(seconds: 8);

  bool _isAutoAiInspectionEligible(ProximityZone zone) {
    if (zone != ProximityZone.critical) return false;
    final now = DateTime.now();
    if (now.difference(_lastAutoAiInspectionTime) >= _autoAiCooldown) {
      _lastAutoAiInspectionTime = now;
      return true;
    }
    return false;
  }

  ProximityZone get currentZone => _currentZone;
  bool get isSilentMode => _isSilentMode;
  bool get isActive => _isActive;

  void setSilentMode(bool silent) {
    _isSilentMode = silent;
    if (_isSilentMode) {
      TtsService.stop();
    }
  }

  void setActive(bool active) {
    _isActive = active;
    if (!_isActive) {
      _currentZone = ProximityZone.clear;
      HapticService.cancel();
      TtsService.stop();
    }
  }

  /// Evaluasi bacaan sensor deterministik ringan (< 2 ms)
  Future<ProximityZone> evaluateReading(
    ProximityReading reading, {
    Function()? onAutoAiTrigger,
  }) async {
    if (!_isActive) return ProximityZone.clear;

    final zone = reading.zone;
    _currentZone = zone;

    final now = DateTime.now();

    // 1. Eksekusi Haptik Taktil (80% Jalur Utama)
    if (zone != ProximityZone.clear) {
      if (now.difference(_lastHapticTriggerTime) >= _hapticCooldown) {
        _lastHapticTriggerTime = now;
        await HapticService.triggerZone(zone);
      }
    } else {
      await HapticService.cancel();
    }

    // 2. Eksekusi Suara Darurat Luring
    if (!_isSilentMode && now.difference(_lastSpeechAlertTime) >= _speechCooldown) {
      if (zone == ProximityZone.critical) {
        _lastSpeechAlertTime = now;
        await TtsService.speakAlert('Berhenti!');
      } else if (zone == ProximityZone.caution) {
        _lastSpeechAlertTime = now;
        await TtsService.speakAlert('Waspada!');
      }
    }

    // 3. Proaktif Otomatis AI Inspection jika terhenti di depan objek kritis
    if (_isAutoAiInspectionEligible(zone) && onAutoAiTrigger != null) {
      onAutoAiTrigger();
    }

    return zone;
  }
}
