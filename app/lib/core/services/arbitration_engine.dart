import 'dart:async';
import '../constants/haptic_patterns.dart';
import 'haptic_service.dart';
import 'tts_service.dart';
import 'vision_service.dart';
import 'depth_estimation_service.dart';
import 'fast_proximity_engine.dart';
import 'yolo_detection_service.dart';

class ArbitrationEngine {
  ProximityZone _currentZone = ProximityZone.clear;
  bool _isSilentMode = false;
  bool _isActive = true;

  DateTime _lastHapticTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSpeechAlertTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAutoAiInspectionTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Interval anti-fatigue agar tidak terjadi haptic & speech saturation
  static const Duration _hapticCooldown = Duration(milliseconds: 300);
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

  /// Evaluasi hasil YOLO Object Detection (Akurasi Tinggi untuk Objek Nyata: Orang, Motor, Kursi, Tiang)
  Future<ProximityZone> evaluateYoloResult(
    YoloResult result, {
    Function()? onAutoAiTrigger,
  }) async {
    if (!_isActive) return ProximityZone.clear;

    final zone = result.zone;
    _currentZone = zone;

    final now = DateTime.now();

    // 1. Eksekusi Haptik Taktil
    if (zone != ProximityZone.clear) {
      if (now.difference(_lastHapticTriggerTime) >= _hapticCooldown) {
        _lastHapticTriggerTime = now;
        await HapticService.triggerZone(zone);
      }
    } else {
      await HapticService.cancel();
    }

    // 2. Eksekusi Suara Deskriptif Cepat (Sebutkan apa rintangannya)
    if (!_isSilentMode && now.difference(_lastSpeechAlertTime) >= _speechCooldown) {
      if (zone == ProximityZone.critical) {
        _lastSpeechAlertTime = now;
        await TtsService.speakAlert(result.alertMessage);
      } else if (zone == ProximityZone.caution) {
        _lastSpeechAlertTime = now;
        await TtsService.speakAlert(result.alertMessage);
      }
    }

    // 3. Proaktif Otomatis AI jika terhenti
    if (_isAutoAiInspectionEligible(zone) && onAutoAiTrigger != null) {
      onAutoAiTrigger();
    }

    return zone;
  }

  /// Evaluasi hasil Fast Proximity Engine (Latensi 1-3 ms, Tanggap Seketika)
  Future<ProximityZone> evaluateProximityAnalysis(
    ProximityAnalysis analysis, {
    Function()? onAutoAiTrigger,
  }) async {
    if (!_isActive) return ProximityZone.clear;

    final zone = analysis.zone;
    _currentZone = zone;

    final now = DateTime.now();

    // 1. Eksekusi Haptik Taktil (80% Jalur Komunikasi)
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
        if (analysis.upperHazardScore >= 0.45) {
          await TtsService.speakAlert('Awas kepala!');
        } else {
          await TtsService.speakAlert('Berhenti!');
        }
      } else if (zone == ProximityZone.caution) {
        _lastSpeechAlertTime = now;
        await TtsService.speakAlert('Waspada!');
      }
    }

    // 3. Proaktif Otomatis: Saat pengguna terhenti di depan objek kritis (gerbang/pintu/tembok)
    if (_isAutoAiInspectionEligible(zone) && onAutoAiTrigger != null) {
      onAutoAiTrigger();
    }

    return zone;
  }

  /// Evaluasi hasil estimasi kedalaman fisik MiDaS (Prioritas Primer)
  Future<ProximityZone> evaluateDepthResult(
    DepthResult result, {
    Function()? onAutoAiTrigger,
  }) async {
    if (!_isActive) return ProximityZone.clear;

    final highestZone = result.zone;
    _currentZone = highestZone;

    final now = DateTime.now();

    // 1. Eksekusi Haptik Taktil (80% Jalur Utama)
    if (highestZone != ProximityZone.clear) {
      if (now.difference(_lastHapticTriggerTime) >= _hapticCooldown) {
        _lastHapticTriggerTime = now;
        await HapticService.triggerZone(highestZone);
      }
    } else {
      await HapticService.cancel();
    }

    // 2. Eksekusi Suara Darurat Luring
    if (!_isSilentMode && now.difference(_lastSpeechAlertTime) >= _speechCooldown) {
      if (highestZone == ProximityZone.critical) {
        _lastSpeechAlertTime = now;
        await TtsService.speakAlert('Awas depan!');
      } else if (highestZone == ProximityZone.caution) {
        _lastSpeechAlertTime = now;
        await TtsService.speakAlert('Waspada!');
      }
    }

    // 3. Proaktif Otomatis AI Inspection jika terhenti di depan objek kritis
    if (_isAutoAiInspectionEligible(highestZone) && onAutoAiTrigger != null) {
      onAutoAiTrigger();
    }

    return highestZone;
  }

  /// Evaluasi daftar deteksi rintangan bounding box (Fallback Sekunder)
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
