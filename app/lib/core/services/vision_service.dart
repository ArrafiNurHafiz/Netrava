import 'dart:ui';
import 'dart:typed_data';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:camera/camera.dart';
import '../constants/haptic_patterns.dart';

class DetectedObstacle {
  final String label;
  final double confidence;
  final Rect boundingBox;
  final ProximityZone zone;
  final bool isUpperBodyHazard; // Bahaya setinggi dada/kepala

  DetectedObstacle({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.zone,
    required this.isUpperBodyHazard,
  });
}

class VisionService {
  static ObjectDetector? _objectDetector;
  static bool _isProcessing = false;

  /// Inisialisasi detector lokal on-device
  static Future<void> initialize() async {
    if (_objectDetector != null) return;

    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );

    _objectDetector = ObjectDetector(options: options);
  }

  /// Evaluasi zona kedekatan berdasarkan rasio bounding box terhadap frame kamera
  /// Sesuai rumus arsitektur: Box Area/Height rasio merepresentasikan jarak relatif
  static ProximityZone calculateProximity(Rect boundingBox, Size imageSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return ProximityZone.clear;

    final imageArea = imageSize.width * imageSize.height;
    final boxArea = boundingBox.width * boundingBox.height;
    final areaRatio = boxArea / imageArea;

    // Rasio vertikal rintangan terhadap layar
    final heightRatio = boundingBox.height / imageSize.height;

    // Zona Kritis (< 1.0 meter): Objek mendominasi lebih dari 45% area atau 65% tinggi frame
    if (areaRatio > 0.40 || heightRatio > 0.60) {
      return ProximityZone.critical;
    }
    // Zona Waspada (1.0 - 2.0 meter): Objek berada di rentang 18% - 40% area
    else if (areaRatio > 0.15 || heightRatio > 0.35) {
      return ProximityZone.caution;
    }
    // Zona Kesadaran (> 2.0 meter): Objek kecil terdeteksi di kejauhan
    else if (areaRatio > 0.05 || heightRatio > 0.18) {
      return ProximityZone.awareness;
    }

    return ProximityZone.clear;
  }

  /// Cek apakah rintangan berada di paruh vertikal atas (dada & kepala)
  static bool isUpperHazard(Rect boundingBox, Size imageSize) {
    // Top box berada di setengah layar atas (0.0 sampai 0.6 dari atas frame)
    return boundingBox.top < (imageSize.height * 0.65);
  }

  /// Konversi CameraImage YUV420 ke InputImage ML Kit untuk pemrosesan frame langsung
  static InputImage? convertCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) {
    try {
      final sensorOrientation = camera.sensorOrientation;
      final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation90deg;

      final format = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      // Gabungkan bytes plane YUV
      final allBytes = <int>[];
      for (final plane in image.planes) {
        allBytes.addAll(plane.bytes);
      }

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: Uint8List.fromList(allBytes),
        metadata: metadata,
      );
    } catch (_) {
      return null;
    }
  }

  /// Proses frame citra kamera on-device
  static Future<List<DetectedObstacle>> processImage(
    InputImage inputImage,
    Size imageSize,
  ) async {
    if (_objectDetector == null) await initialize();
    if (_isProcessing) return [];

    _isProcessing = true;
    try {
      final objects = await _objectDetector!.processImage(inputImage);
      final List<DetectedObstacle> results = [];

      for (final detected in objects) {
        String label = 'Penghalang';
        double confidence = 0.8;

        if (detected.labels.isNotEmpty) {
          final topLabel = detected.labels.first;
          label = topLabel.text;
          confidence = topLabel.confidence;
        }

        final zone = calculateProximity(detected.boundingBox, imageSize);
        final upperHazard = isUpperHazard(detected.boundingBox, imageSize);

        results.add(DetectedObstacle(
          label: label,
          confidence: confidence,
          boundingBox: detected.boundingBox,
          zone: zone,
          isUpperBodyHazard: upperHazard,
        ));
      }

      return results;
    } catch (_) {
      return [];
    } finally {
      _isProcessing = false;
    }
  }

  /// Lepas memori model
  static Future<void> dispose() async {
    try {
      await _objectDetector?.close();
      _objectDetector = null;
    } catch (_) {}
  }
}
