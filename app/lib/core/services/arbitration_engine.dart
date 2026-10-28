import 'dart:async';
import '../constants/haptic_patterns.dart';
import 'haptic_service.dart';
import 'tts_service.dart';
import 'vision_service.dart';

class ArbitrationEngine {
  ProximityZone _currentZone = ProximityZone.clear;
  bool _isSilentMode = false;
  bool _isActive = true;

  DateTime _lastHapticTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSpeechAlertTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Interval anti-fatigue agar tidak terjadi haptic & speech saturation
  static const Duration _hapticCooldown = Duration(milliseconds: 350);
  static const Duration _speechCooldown = Duration(milliseconds: 2000);

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

  /// Evaluasi daftar deteksi rintangan dan tetapkan prioritas sensorik
  Future<ProximityZone> evaluateObstacles(List<DetectedObstacle> obstacles) async {
    if (!_isActive) return ProximityZone.clear;

    if (obstacles.isEmpty) {
      if (_currentZone != ProximityZone.clear) {
        _currentZone = ProximityZone.clear;
        await HapticService.cancel();
      }
      return ProximityZone.clear;
    }

    // Cari rintangan dengan tingkat bahaya tertinggi, prioritaskan rintangan atas
    ProximityZone highestZone = ProximityZone.clear;
    bool hasCriticalUpperHazard = false;

    for (final obs in obstacles) {
      if (obs.zone.index > highestZone.index) {
        highestZone = obs.zone;
      }
      if (obs.zone == ProximityZone.critical && obs.isUpperBodyHazard) {
        hasCriticalUpperHazard = true;
      }
    }

    _currentZone = highestZone;

    final now = DateTime.now();

    // 1. Eksekusi Haptik Taktil (80% Jalur Utama Komunikasi)
    if (highestZone != ProximityZone.clear) {
      if (now.difference(_lastHapticTriggerTime) >= _hapticCooldown) {
        _lastHapticTriggerTime = now;
        await HapticService.triggerZone(highestZone);
      }
    } else {
      await HapticService.cancel();
    }

    // 2. Eksekusi Suara Darurat Luring (20% - Hanya saat Kritis & Bukan Mode Senyap)
    if (!_isSilentMode && now.difference(_lastSpeechAlertTime) >= _speechCooldown) {
      if (highestZone == ProximityZone.critical) {
        _lastSpeechAlertTime = now;
        if (hasCriticalUpperHazard) {
          await TtsService.speakAlert('Awas kepala!');
        } else {
          await TtsService.speakAlert('Berhenti!');
        }
      } else if (highestZone == ProximityZone.caution) {
        _lastSpeechAlertTime = now;
        await TtsService.speakAlert('Waspada!');
      }
    }

    return highestZone;
  }
}
