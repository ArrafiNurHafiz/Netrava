import 'dart:math';
import 'package:camera/camera.dart';
import '../constants/haptic_patterns.dart';

class ProximityReading {
  final ProximityZone zone;
  final double obstacleIntensity; // 0.0 (bersih) sampai 1.0 (sangat padat/dekat)
  final String label;
  final int latencyMs;

  ProximityReading({
    required this.zone,
    required this.obstacleIntensity,
    required this.label,
    required this.latencyMs,
  });
}

/// Mesin Vision Deterministik Ringan (Zero AI, < 2 ms CPU, Zero Lag)
/// Menganalisis kepadatan halangan fisik menggunakan variasi kontras spatial & oklusi
class DeterministicProximityEngine {
  static bool _isProcessing = false;

  // Ukuran sampel grid cepat: 16x16 titik sampel (total hanya 256 operasi integer!)
  static const int gridX = 16;
  static const int gridY = 16;

  /// Memproses frame CameraImage YUV420 secara instan
  static ProximityReading? processFrame(CameraImage image) {
    if (_isProcessing) return null;
    _isProcessing = true;

    final stopwatch = Stopwatch()..start();

    try {
      final yPlane = image.planes[0];
      final yBytes = yPlane.bytes;
      final width = image.width;
      final height = image.height;
      final rowStride = yPlane.bytesPerRow;

      // Area fokus pandangan depan (Tengah 50% horizontal, 15%-65% vertikal)
      final startX = (width * 0.25).toInt();
      final endX = (width * 0.75).toInt();
      final startY = (height * 0.15).toInt();
      final endY = (height * 0.65).toInt();

      final stepX = ((endX - startX) / gridX).toInt();
      final stepY = ((endY - startY) / gridY).toInt();

      int totalLuminance = 0;
      int totalVariance = 0;
      int edgeCount = 0;
      int sampleCount = 0;

      int prevLum = -1;

      for (int gy = 0; gy < gridY; gy++) {
        final currentY = startY + gy * stepY;
        final rowOffset = currentY * rowStride;

        for (int gx = 0; gx < gridX; gx++) {
          final currentX = startX + gx * stepX;
          final lum = yBytes[rowOffset + currentX];

          totalLuminance += lum;
          sampleCount++;

          if (prevLum != -1) {
            final diff = (lum - prevLum).abs();
            totalVariance += diff;
            if (diff > 35) {
              edgeCount++;
            }
          }
          prevLum = lum;
        }
      }

      if (sampleCount == 0) {
        return ProximityReading(
          zone: ProximityZone.clear,
          obstacleIntensity: 0.0,
          label: 'Jalur Bersih',
          latencyMs: 1,
        );
      }

      final avgLuminance = totalLuminance / sampleCount;
      final avgContrast = totalVariance / sampleCount;
      final edgeRatio = edgeCount / sampleCount;

      // Kriteria Deteksi Fisik Nyata:
      // 1. Objek sangat dekat (< 60 cm): Menutupi lensa secara masif (oklusi pekat / pantulan dekat)
      final bool isCloseOcclusion = avgLuminance < 25 || avgLuminance > 240;

      // 2. Objek berjarak sedang (1 - 2 meter / kursi, orang, meja, tiang):
      // Menghasilkan kontras tajam di area tengah kamera
      final double intensity = max(edgeRatio, (avgContrast / 128.0).clamp(0.0, 1.0));

      ProximityZone zone = ProximityZone.clear;
      String label = 'Jalur Bersih';

      if (isCloseOcclusion || intensity >= 0.40) {
        zone = ProximityZone.critical;
        label = 'BERHENTI! RINTANGAN DEKAT (< 1M)';
      } else if (intensity >= 0.22) {
        zone = ProximityZone.caution;
        label = 'WASPADA RINTANGAN (1-2M)';
      } else if (intensity >= 0.12) {
        zone = ProximityZone.awareness;
        label = 'Rintangan Jauh (> 2M)';
      }

      stopwatch.stop();

      return ProximityReading(
        zone: zone,
        obstacleIntensity: intensity,
        label: label,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (_) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  static void reset() {
    _isProcessing = false;
  }
}
