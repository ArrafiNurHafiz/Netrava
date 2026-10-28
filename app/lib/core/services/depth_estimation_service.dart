import 'dart:math';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../constants/haptic_patterns.dart';

class DepthResult {
  final ProximityZone zone;
  final double maxDepthScore;      // 0.0 (jauh/terbuka) - 1.0 (sangat dekat)
  final double upperHazardScore;   // Skor kedalaman rintangan di area kepala/dada
  final String label;

  DepthResult({
    required this.zone,
    required this.maxDepthScore,
    required this.upperHazardScore,
    required this.label,
  });
}

class DepthEstimationService {
  static Interpreter? _interpreter;
  static bool _isProcessing = false;
  static bool _isLoaded = false;

  static const int inputSize = 256;

  // Mean dan Std ImageNet untuk normalisasi MiDaS
  static const List<double> mean = [0.485, 0.456, 0.406];
  static const List<double> std = [0.229, 0.224, 0.225];

  /// Inisialisasi model MiDaS Small v2.1 TFLite
  static Future<bool> initialize() async {
    if (_isLoaded && _interpreter != null) return true;

    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/midas_small.tflite',
        options: options,
      );
      _isLoaded = true;
      return true;
    } catch (_) {
      _isLoaded = false;
      return false;
    }
  }

  /// Proses frame CameraImage langsung menggunakan Monocular Depth Estimation
  static Future<DepthResult?> processCameraFrame(CameraImage image) async {
    if (!_isLoaded || _interpreter == null) {
      final ok = await initialize();
      if (!ok) return null;
    }

    if (_isProcessing) return null;
    _isProcessing = true;

    try {
      // 1. Konversi CameraImage YUV420 ke RGB Image (256x256)
      final rgbImage = _convertYUV420ToImage(image);
      final resized = img.copyResize(rgbImage, width: inputSize, height: inputSize);

      // 2. Siapkan input tensor [1, 256, 256, 3] Float32 ternormalisasi
      final inputBuffer = List.generate(
        1,
        (_) => List.generate(
          inputSize,
          (y) => List.generate(
            inputSize,
            (x) {
              final pixel = resized.getPixel(x, y);
              final r = (pixel.r / 255.0 - mean[0]) / std[0];
              final g = (pixel.g / 255.0 - mean[1]) / std[1];
              final b = (pixel.b / 255.0 - mean[2]) / std[2];
              return [r, g, b];
            },
          ),
        ),
      );

      // 3. Siapkan output tensor [1, 256, 256] Float32 (relative inverse depth)
      final outputBuffer = List.generate(
        1,
        (_) => List.generate(inputSize, (_) => List.filled(inputSize, 0.0)),
      );

      // 4. Jalankan inferensi neural network lokal
      _interpreter!.run(inputBuffer, outputBuffer);

      // 5. Analisis peta kedalaman (Inverse depth: nilai tinggi = dekat, nilai rendah = jauh)
      final depthMap = outputBuffer[0];
      return evaluateDepthMap(depthMap);
    } catch (_) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Evaluasi matriks kedalaman 256x256
  static DepthResult evaluateDepthMap(List<List<double>> depthMap) {
    double minVal = double.infinity;
    double maxVal = -double.infinity;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final val = depthMap[y][x];
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    final range = max(maxVal - minVal, 0.0001);

    // Fokus pada Central ROI (Area depan langkah) & Upper ROI (Area kepala/dada)
    // Sumbu X: 25% - 75% (tengah jalur langkah kaki)
    // Sumbu Y: 10% - 65% (area dada dan kepala pengguna)
    double sumUpperDepth = 0.0;
    int upperPixels = 0;

    double maxRelativeDepth = 0.0;

    const startX = 64; // 25% dari 256
    const endX = 192;   // 75% dari 256
    const startY = 25; // 10% dari 256
    const endY = 166;  // 65% dari 256 (Area dada & kepala)

    for (int y = startY; y < endY; y++) {
      for (int x = startX; x < endX; x++) {
        // Normalisasi ke rentang 0.0 (jauh) sampai 1.0 (sangat dekat)
        final normalized = (depthMap[y][x] - minVal) / range;
        sumUpperDepth += normalized;
        upperPixels++;

        if (normalized > maxRelativeDepth) {
          maxRelativeDepth = normalized;
        }
      }
    }

    final avgUpperScore = upperPixels > 0 ? (sumUpperDepth / upperPixels) : 0.0;

    ProximityZone zone = ProximityZone.clear;
    String label = 'Jalur Bersih';

    // Ambang batas ketat kedalaman fisik nyata (MiDaS Inverse Depth):
    // Nilai rata-rata area tengah > 0.62 atau titik kritis puncak > 0.82 = Halangan fisik sangat dekat (< 1 meter)
    if (avgUpperScore >= 0.60 || maxRelativeDepth >= 0.80) {
      zone = ProximityZone.critical;
      label = 'Rintangan Kritis (< 1M)';
    } else if (avgUpperScore >= 0.40 || maxRelativeDepth >= 0.60) {
      zone = ProximityZone.caution;
      label = 'Rintangan Mendekat (1-2M)';
    } else if (avgUpperScore >= 0.25 || maxRelativeDepth >= 0.45) {
      zone = ProximityZone.awareness;
      label = 'Rintangan Jauh (> 2M)';
    }

    return DepthResult(
      zone: zone,
      maxDepthScore: maxRelativeDepth,
      upperHazardScore: avgUpperScore,
      label: label,
    );
  }

  /// Konversi efisien CameraImage YUV420 ke RGB image
  static img.Image _convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final outImg = img.Image(width: width, height: height);

    final planeY = image.planes[0];
    final planeU = image.planes[1];
    final planeV = image.planes[2];

    final yBytes = planeY.bytes;
    final uBytes = planeU.bytes;
    final vBytes = planeV.bytes;

    final yRowStride = planeY.bytesPerRow;
    final uvRowStride = planeU.bytesPerRow;
    final uvPixelStride = planeU.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final Y = yBytes[yIndex];
        final U = uBytes[uvIndex] - 128;
        final V = vBytes[uvIndex] - 128;

        final r = (Y + 1.370705 * V).clamp(0, 255).toInt();
        final g = (Y - 0.337633 * U - 0.698001 * V).clamp(0, 255).toInt();
        final b = (Y + 1.732446 * U).clamp(0, 255).toInt();

        outImg.setPixelRgb(x, y, r, g, b);
      }
    }

    return outImg;
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
