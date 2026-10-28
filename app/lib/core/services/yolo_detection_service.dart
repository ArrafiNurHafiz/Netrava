import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../constants/haptic_patterns.dart';

class YoloDetection {
  final String label;
  final double confidence;
  final ProximityZone zone;
  final double heightRatio;
  final double centerX;
  final bool isUpperHazard;

  YoloDetection({
    required this.label,
    required this.confidence,
    required this.zone,
    required this.heightRatio,
    required this.centerX,
    required this.isUpperHazard,
  });
}

class YoloResult {
  final ProximityZone zone;
  final String alertMessage;
  final List<YoloDetection> detections;
  final int latencyMs;

  YoloResult({
    required this.zone,
    required this.alertMessage,
    required this.detections,
    required this.latencyMs,
  });
}

class YoloDetectionService {
  static Interpreter? _interpreter;
  static bool _isProcessing = false;
  static bool _isLoaded = false;

  static const int inputSize = 640;

  // 80 Kelas COCO Terstandarisasi
  static const List<String> cocoLabels = [
    'Orang', 'Sepeda', 'Mobil', 'Motor', 'Pesawat', 'Bus', 'Kereta', 'Truk', 'Perahu',
    'Lampu Merah', 'Keran Air', 'Rambu Stop', 'Meteran Parkir', 'Bangku Taman', 'Burung',
    'Kucing', 'Anjing', 'Kuda', 'Domba', 'Sapi', 'Gajah', 'Beruang', 'Zebra', 'Jerapah',
    'Ransel', 'Payung', 'Tas Tangan', 'Dasi', 'Koper', 'Frisbee', 'Ski', 'Papan Salju',
    'Bola Olahraga', 'Layang-layang', 'Tongkat Bisbol', 'Sarung Bisbol', 'Skateboard',
    'Papan Selancar', 'Raket Tenis', 'Botol', 'Gelas Anggur', 'Cangkir', 'Garpu', 'Pisau',
    'Sendok', 'Mangkuk', 'Pisang', 'Apel', 'Sandwich', 'Jeruk', 'Brokoli', 'Wortel',
    'Hot Dog', 'Pizza', 'Donat', 'Kue', 'Kursi', 'Sofa', 'Tanaman Pot', 'Tempat Tidur',
    'Meja Makan', 'Toilet', 'Monitor TV', 'Laptop', 'Mouse', 'Remote', 'Keyboard',
    'Ponsel', 'Microwave', 'Oven', 'Pemanggang', 'Wastafel', 'Kulkas', 'Buku', 'Jam Dinding',
    'Vas Bunga', 'Gunting', 'Boneka', 'Pengering Rambut', 'Sikat Gigi'
  ];

  // Pre-allocated flat buffer input [1, 640, 640, 3] Float32
  static final List<List<List<List<double>>>> _inputTensor = List.generate(
    1,
    (_) => List.generate(
      inputSize,
      (_) => List.generate(
        inputSize,
        (_) => List.filled(3, 0.0),
      ),
    ),
  );

  // Pre-allocated flat buffer output YOLOv8 [1, 84, 8400] Float32
  static final List<List<List<double>>> _outputTensor = List.generate(
    1,
    (_) => List.generate(
      84,
      (_) => List.filled(8400, 0.0),
    ),
  );

  /// Inisialisasi model YOLOv8n TFLite
  static Future<bool> initialize() async {
    if (_isLoaded && _interpreter != null) return true;

    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/models/yolov8n.tflite',
        options: options,
      );
      _isLoaded = true;
      return true;
    } catch (_) {
      _isLoaded = false;
      return false;
    }
  }

  /// Ekstraksi objek rintangan instan dari frame kamera
  static Future<YoloResult?> detectObstacles(CameraImage image) async {
    if (!_isLoaded || _interpreter == null) {
      final ok = await initialize();
      if (!ok) return null;
    }

    if (_isProcessing) return null;
    _isProcessing = true;

    final stopwatch = Stopwatch()..start();

    try {
      final yPlane = image.planes[0];
      final yBytes = yPlane.bytes;
      final srcW = image.width;
      final srcH = image.height;
      final rowStride = yPlane.bytesPerRow;

      final double scaleX = srcW / inputSize;
      final double scaleY = srcH / inputSize;
      final inputList = _inputTensor[0];

      // Fast Resample Y-plane (Luminance) langsung ke RGB input tensor [1, 640, 640, 3] (0.0 - 1.0)
      for (int y = 0; y < inputSize; y++) {
        final srcY = (y * scaleY).toInt().clamp(0, srcH - 1);
        final rowOffset = srcY * rowStride;
        final rowTensor = inputList[y];

        for (int x = 0; x < inputSize; x++) {
          final srcX = (x * scaleX).toInt().clamp(0, srcW - 1);
          final normLum = yBytes[rowOffset + srcX] / 255.0;

          final pixel = rowTensor[x];
          pixel[0] = normLum;
          pixel[1] = normLum;
          pixel[2] = normLum;
        }
      }

      // Jalankan inferensi neural network YOLO
      _interpreter!.run(_inputTensor, _outputTensor);

      // Parsing Output Tensor YOLOv8: [1, 84, 8400]
      // 84 baris: 0=cx, 1=cy, 2=w, 3=h, 4..83=class scores
      final out = _outputTensor[0];
      final List<YoloDetection> detectedList = [];

      for (int i = 0; i < 8400; i += 4) { // Subsample anchor box untuk efisiensi eksekusi
        double maxScore = 0.0;
        int maxClassId = 0;

        for (int c = 0; c < 80; c++) {
          final score = out[4 + c][i];
          if (score > maxScore) {
            maxScore = score;
            maxClassId = c;
          }
        }

        // Ambang batas keyakinan (Confidence threshold: 35%)
        if (maxScore >= 0.35) {
          final cx = out[0][i] / inputSize;
          final cy = out[1][i] / inputSize;
          final h = out[3][i] / inputSize;

          // Saring hanya objek yang berada di JALUR JALAN DEPAN (Koridor tengah X: 20% - 80%)
          if (cx >= 0.20 && cx <= 0.80) {
            final isUpper = cy < 0.60;

            // Estimasi Jarak Geometris Nyata:
            // - Kritis (< 1.0m): Tinggi kotak objek >= 45% tinggi layar
            // - Waspada (1.0 - 2.0m): Tinggi kotak objek >= 24% tinggi layar
            // - Jauh (> 2.0m): Tinggi kotak objek >= 12% tinggi layar
            ProximityZone zone = ProximityZone.clear;
            if (h >= 0.45) {
              zone = ProximityZone.critical;
            } else if (h >= 0.24) {
              zone = ProximityZone.caution;
            } else if (h >= 0.12) {
              zone = ProximityZone.awareness;
            }

            if (zone != ProximityZone.clear) {
              final label = (maxClassId >= 0 && maxClassId < cocoLabels.length)
                  ? cocoLabels[maxClassId]
                  : 'Rintangan';

              detectedList.add(YoloDetection(
                label: label,
                confidence: maxScore,
                zone: zone,
                heightRatio: h,
                centerX: cx,
                isUpperHazard: isUpper,
              ));
            }
          }
        }
      }

      stopwatch.stop();

      // Urutkan rintangan dari tingkat bahaya tertinggi
      ProximityZone highestZone = ProximityZone.clear;
      String message = 'Jalur Bersih';

      if (detectedList.isNotEmpty) {
        detectedList.sort((a, b) => b.zone.index.compareTo(a.zone.index));
        final top = detectedList.first;
        highestZone = top.zone;

        if (highestZone == ProximityZone.critical) {
          message = 'Awas ${top.label} Dekat!';
        } else if (highestZone == ProximityZone.caution) {
          message = 'Ada ${top.label} (1-2M)';
        } else {
          message = '${top.label} Terdeteksi';
        }
      }

      return YoloResult(
        zone: highestZone,
        alertMessage: message,
        detections: detectedList,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (_) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
