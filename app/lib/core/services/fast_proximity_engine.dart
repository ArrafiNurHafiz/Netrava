import 'package:camera/camera.dart';
import '../constants/haptic_patterns.dart';

class ProximityAnalysis {
  final ProximityZone zone;
  final double centralOccupancy;
  final double upperHazardScore;
  final String label;
  final int latencyMs;

  ProximityAnalysis({
    required this.zone,
    required this.centralOccupancy,
    required this.upperHazardScore,
    required this.label,
    required this.latencyMs,
  });
}

class FastProximityEngine {
  static bool _isProcessing = false;
  static const int sampleStep = 8; // Step lebih lebar (subsample) untuk meredam noise sensor

  /// Menghitung ambang bahaya dengan algoritma True Obstacle vs Background Open Space
  static ProximityAnalysis? processFrame(CameraImage image) {
    if (_isProcessing) return null;
    _isProcessing = true;

    final stopwatch = Stopwatch()..start();

    try {
      final yPlane = image.planes[0];
      final yBytes = yPlane.bytes;
      final width = image.width;
      final height = image.height;
      final rowStride = yPlane.bytesPerRow;

      // Area fokus pandangan depan (Tengah 40% horizontal, 15%-60% vertikal)
      final startX = (width * 0.30).toInt();
      final endX = (width * 0.70).toInt();
      final startY = (height * 0.15).toInt();
      final endY = (height * 0.60).toInt();

      int totalPixels = 0;
      int highContrastEdges = 0;
      int totalLuminance = 0;

      // Ambang batas ketat gradien untuk membedakan tekstur lantai/dinding jauh vs benda dekat
      const int edgeThreshold = 65; // Dinaikkan dari 28 ke 65 agar ruang kosong bertekstur tidak dianggap halangan

      for (int y = startY; y < endY - sampleStep; y += sampleStep) {
        final rowOffset = y * rowStride;
        final nextRowOffset = (y + sampleStep) * rowStride;

        for (int x = startX; x < endX - sampleStep; x += sampleStep) {
          final pCurrent = yBytes[rowOffset + x];
          final pRight = yBytes[rowOffset + x + sampleStep];
          final pDown = yBytes[nextRowOffset + x];

          final gx = (pRight - pCurrent).abs();
          final gy = (pDown - pCurrent).abs();
          final gradient = gx + gy;

          totalLuminance += pCurrent;
          totalPixels++;

          if (gradient >= edgeThreshold) {
            highContrastEdges++;
          }
        }
      }

      if (totalPixels == 0) {
        return ProximityAnalysis(
          zone: ProximityZone.clear,
          centralOccupancy: 0.0,
          upperHazardScore: 0.0,
          label: 'Jalur Bersih',
          latencyMs: 1,
        );
      }

      final edgeDensity = highContrastEdges / totalPixels;
      final avgLuminance = totalLuminance / totalPixels;

      // Oklusi masif: Hanya jika lensa tertutup rapat oleh benda sangat dekat (< 20 cm)
      // Ditandai dengan hampir seluruh piksel menjadi gelap pekat (rata-rata < 18)
      // atau sangat silau tertutup (< 10 cm dari lampu/benda putih > 248)
      final bool isLensBlocked = avgLuminance < 18 || avgLuminance > 248;

      ProximityZone zone = ProximityZone.clear;
      String label = 'Jalur Bersih';

      // Kalibrasi REALISTIS (Anti-False-Positive):
      // Ruang kosong normal (meski ada keramik/motif karpet) biasanya hanya menghasilkan edgeDensity 0.02 - 0.15.
      // Benda nyata mendekat (< 1 meter) menghasilkan edgeDensity masif (> 0.40) atau lensa tertutup (> 0.65).
      if (isLensBlocked || edgeDensity >= 0.45) {
        zone = ProximityZone.critical;
        label = 'BERHENTI! DEKAT (< 1M)';
      } else if (edgeDensity >= 0.28) {
        zone = ProximityZone.caution;
        label = 'WASPADA RINTANGAN (1-2M)';
      } else if (edgeDensity >= 0.18) {
        zone = ProximityZone.awareness;
        label = 'Rintangan Jauh (> 2M)';
      }

      stopwatch.stop();

      return ProximityAnalysis(
        zone: zone,
        centralOccupancy: edgeDensity,
        upperHazardScore: edgeDensity,
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
