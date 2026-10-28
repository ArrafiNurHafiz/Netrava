import 'package:camera/camera.dart';

class CameraService {
  static CameraController? _controller;
  static bool _isStreaming = false;

  static CameraController? get controller => _controller;
  static bool get isInitialized => _controller != null && _controller!.value.isInitialized;
  static bool get isStreaming => _isStreaming;

  /// Inisialisasi kamera belakang dengan resolusi rendah hemat baterai (640x480)
  static Future<bool> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      // Cari kamera belakang (Back / Environment)
      final backCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium, // 480p / 720p optimal untuk on-device inference
        enableAudio: false,      // Hemat daya & tidak mengunci audio device
        imageFormatGroup: ImageFormatGroup.yuv420, // Format stream native CameraX
      );

      await _controller!.initialize();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mulai streaming frame kamera untuk analisis vision
  static Future<void> startImageStream(Function(CameraImage image) onFrame) async {
    if (!isInitialized || _isStreaming) return;
    try {
      _isStreaming = true;
      await _controller!.startImageStream((CameraImage image) {
        if (_isStreaming) {
          onFrame(image);
        }
      });
    } catch (_) {
      _isStreaming = false;
    }
  }

  /// Hentikan streaming frame
  static Future<void> stopImageStream() async {
    if (!isInitialized || !_isStreaming) return;
    try {
      _isStreaming = false;
      await _controller!.stopImageStream();
    } catch (_) {}
  }

  /// Lepas resource kamera
  static Future<void> dispose() async {
    try {
      await stopImageStream();
      await _controller?.dispose();
      _controller = null;
    } catch (_) {}
  }
}
