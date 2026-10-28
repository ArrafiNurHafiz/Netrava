import 'dart:math';
import 'package:camera/camera.dart';
import '../constants/haptic_patterns.dart';

class ProximityAnalysis {
  final ProximityZone zone;
  final double centralOccupancy; // Persentase kepadatan di tengah jalur (0.0 - 1.0)
  final double upperHazardScore;  // Skor halangan setinggi dada/kepala (0.0 - 1.0)
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

  // Baseline ambang kecerahan & gradien
  static const int sampleStep = 4; // Sub-sampling 4x4 untuk kecepatan 1-2 ms per frame

  /// Analisis kedekatan fisik rintangan instan (1-3 ms) menggunakan Y-plane (Luminance)
  /// Bebas lag, tidak membebani garbage collector, dan tidak mengunci CPU thread
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

      // Fokus pada Jalur Langkah:
      // X: 25% - 75% lebar kamera (jalur jalan lurus ke depan)
      // Y: 10% - 70% tinggi kamera (area kepala, dada, dan pinggang)
      final startX = (width * 0.25).toInt();
      final endX = (width * 0.75).toInt();
      final startY = (height * 0.10).toInt();
      final endY = (height * 0.70).toInt();

      // Hitung variasi gradien tepi (Edge Density) dan Kerapatan Tekstur
      // Benda padat dekat (tembok, orang, tiang) menyebabkan oklusi masif & perubahan gradien drastis
      int totalSamples = 0;
      int highGradientCount = 0;
      int darkOcclusionCount = 0;
      int brightOcclusionCount = 0;

      double upperWeightedGradient = 0.0;
      int upperSamples = 0;

      final midY = (startY + (endY - startY) * 0.55).toInt();

      for (int y = startY; y < endY - sampleStep; y += sampleStep) {
        final rowOffset = y * rowStride;
        final nextRowOffset = (y + sampleStep) * rowStride;

        for (int x = startX; x < endX - sampleStep; x += sampleStep) {
          final pCurrent = yBytes[rowOffset + x];
          final pRight = yBytes[rowOffset + x + sampleStep];
          final pDown = yBytes[nextRowOffset + x];

          // Hitung magnitudo gradien Sobel sederhana
          final gx = (pRight - pCurrent).abs();
          final gy = (pDown - pCurrent).abs();
          final grad = gx + gy;

          totalSamples++;

          if (grad > 28) {
            highGradientCount++;
          }

          // Cek jika rintangan menutupi ruang (kamera tertutup bayangan dekat atau permukaan terang dekat)
          if (pCurrent < 35) darkOcclusionCount++;
          if (pCurrent > 230) brightOcclusionCount++;

          // Bobot ekstra untuk area kepala dan dada (Y < midY)
          if (y < midY) {
            upperSamples++;
            if (grad > 28) {
              upperWeightedGradient++;
            }
          }
        }
      }

      final gradientDensity = totalSamples > 0 ? (highGradientCount / totalSamples) : 0.0;
      final occlusionRatio = totalSamples > 0 ? ((darkOcclusionCount + brightOcclusionCount) / totalSamples) : 0.0;
      final upperDensity = upperSamples > 0 ? (upperWeightedGradient / upperSamples) : 0.0;

      // Skor Kepadatan Rintangan Nyata
      final obstacleScore = max(gradientDensity, occlusionRatio);

      ProximityZone zone = ProximityZone.clear;
      String label = 'Jalur Bersih';

      // Kalibrasi zona kedekatan:
      // Kritis (< 1.0M): Objek menutupi > 42% area jalur depan atau oklusi dekat > 50%
      if (obstacleScore >= 0.42 || occlusionRatio >= 0.48 || upperDensity >= 0.45) {
        zone = ProximityZone.critical;
        label = upperDensity >= 0.45 ? 'AWAS KEPALA / DADA!' : 'BERHENTI! DEKAT (< 1M)';
      } else if (obstacleScore >= 0.25 || occlusionRatio >= 0.28 || upperDensity >= 0.28) {
        zone = ProximityZone.caution;
        label = 'WASPADA RINTANGAN (1-2M)';
      } else if (obstacleScore >= 0.12 || upperDensity >= 0.15) {
        zone = ProximityZone.awareness;
        label = 'Rintangan Terdeteksi (> 2M)';
      }

      stopwatch.stop();

      return ProximityAnalysis(
        zone: zone,
        centralOccupancy: obstacleScore,
        upperHazardScore: upperDensity,
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
