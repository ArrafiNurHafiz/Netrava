import 'package:flutter/material.dart';
import '../../core/constants/haptic_patterns.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/vision_service.dart';
import '../../core/services/arbitration_engine.dart';
import '../../core/services/foreground_service.dart';
import '../../core/services/permission_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ZeroUiNavigatorScreen extends StatefulWidget {
  const ZeroUiNavigatorScreen({super.key});

  @override
  State<ZeroUiNavigatorScreen> createState() => _ZeroUiNavigatorScreenState();
}

class _ZeroUiNavigatorScreenState extends State<ZeroUiNavigatorScreen> {
  final ArbitrationEngine _arbitration = ArbitrationEngine();
  bool _isScanning = true;
  ProximityZone _currentZone = ProximityZone.clear;
  bool _hasAmplitude = false;
  bool _isCameraReady = false;
  String _detectedLabel = 'Jalur Bersih';

  @override
  void initState() {
    super.initState();
    _bootstrapServices();
  }

  Future<void> _bootstrapServices() async {
    // 0. Minta izin runtime Android (Kamera, Notifikasi, Baterai)
    final permissionsGranted = await PermissionService.requestAllPermissions();

    // 1. Inisialisasi Hardware Haptics
    final hasControl = await HapticService.hasAmplitudeControl();
    
    // 2. Inisialisasi Google TTS Luring
    await TtsService.initialize();

    // 3. Inisialisasi Model Vision Lokal
    await VisionService.initialize();

    // 4. Inisialisasi Kamera Belakang jika izin diberikan
    bool cameraOk = false;
    if (permissionsGranted) {
      cameraOk = await CameraService.initialize();
    }

    if (cameraOk) {
      _startLiveCameraPipeline();
      // Jalankan Android Foreground Service & Wakelock agar navigasi tetap aktif saat layar mati
      ForegroundService.startService();
      try {
        await WakelockPlus.enable();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _hasAmplitude = hasControl;
        _isCameraReady = cameraOk;
      });
      if (permissionsGranted && cameraOk) {
        TtsService.speakStatus('Netrava siap. Jalur aman.');
      } else {
        TtsService.speakAlert('Izin kamera diperlukan.');
      }
    }
  }

  /// Menghubungkan CameraX Stream ke VisionService & ArbitrationEngine
  void _startLiveCameraPipeline() {
    CameraService.startImageStream((image) async {
      if (!_isScanning) return;

      final camera = CameraService.cameraDescription;
      if (camera == null) return;

      final inputImage = VisionService.convertCameraImage(image, camera);
      if (inputImage == null) return;

      final size = Size(image.width.toDouble(), image.height.toDouble());
      final obstacles = await VisionService.processImage(inputImage, size);

      final zone = await _arbitration.evaluateObstacles(obstacles);

      if (mounted && zone != _currentZone) {
        setState(() {
          _currentZone = zone;
          if (obstacles.isNotEmpty) {
            _detectedLabel = obstacles.first.label;
          } else {
            _detectedLabel = 'Jalur Bersih';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
    ForegroundService.stopService();
    CameraService.dispose();
    VisionService.dispose();
    TtsService.stop();
    HapticService.cancel();
    super.dispose();
  }

  void _onSingleTap() {
    final statusMsg = '${_isScanning ? "Memindai aktif" : "Jeda"}. '
        '${_arbitration.isSilentMode ? "Mode haptik senyap" : "Mode suara aktif"}. '
        'Kamera ${_isCameraReady ? "aktif" : "siap simulasi"}. '
        'Objek: $_detectedLabel.';

    if (!_arbitration.isSilentMode) {
      TtsService.speakStatus(statusMsg);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status: ${_isScanning ? "Memindai" : "Jeda"}. '
          'Mode: ${_arbitration.isSilentMode ? "Senyap" : "Suara+Haptik"}. '
          'Kamera: ${_isCameraReady ? "Aktif" : "Simulasi"}. '
          'Motor: ${_hasAmplitude ? "PWM" : "DutyCycle"}.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onDoubleTap() {
    setState(() {
      _arbitration.setSilentMode(!_arbitration.isSilentMode);
    });

    HapticService.triggerZone(ProximityZone.caution);

    if (!_arbitration.isSilentMode) {
      TtsService.speakStatus('Mode suara aktif');
    } else {
      TtsService.stop();
    }
  }

  void _onLongPress() {
    setState(() {
      _isScanning = !_isScanning;
      _arbitration.setActive(_isScanning);
      if (!_isScanning) {
        _currentZone = ProximityZone.clear;
        _detectedLabel = 'Pemindaian Dijeda';
        ForegroundService.stopService();
      } else {
        ForegroundService.startService();
      }
    });

    HapticService.triggerZone(ProximityZone.awareness);
    if (!_arbitration.isSilentMode) {
      TtsService.speakStatus(_isScanning ? 'Pemindaian dimulai' : 'Pemindaian dijeda');
    }
  }

  void _simulateObstacleZone(ProximityZone zone) async {
    if (!_isScanning) return;
    
    // Buat objek simulasi sesuai tombol demo
    final simulatedObstacle = DetectedObstacle(
      label: zone == ProximityZone.critical
          ? 'Tiang / Dahan'
          : zone == ProximityZone.caution
              ? 'Pejalan Kaki'
              : 'Objek Jauh',
      confidence: 0.95,
      boundingBox: const Rect.fromLTWH(50, 50, 300, 300),
      zone: zone,
      isUpperBodyHazard: zone == ProximityZone.critical,
    );

    final evaluatedZone = await _arbitration.evaluateObstacles(
      zone == ProximityZone.clear ? [] : [simulatedObstacle],
    );

    setState(() {
      _currentZone = evaluatedZone;
      _detectedLabel = simulatedObstacle.label;
    });
  }

  Color _getZoneColor() {
    switch (_currentZone) {
      case ProximityZone.clear:
        return const Color(0xFF0F172A); // Slate gelap
      case ProximityZone.awareness:
        return const Color(0xFF1E3A8A); // Biru (Jauh)
      case ProximityZone.caution:
        return const Color(0xFFB45309); // Amber / Jingga (Waspada)
      case ProximityZone.critical:
        return const Color(0xFF991B1B); // Merah Tua (Bahaya Berhenti)
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getZoneColor(),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onSingleTap,
          onDoubleTap: _onDoubleTap,
          onLongPress: _onLongPress,
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'NETRAVA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Asisten Taktil Rintangan Kepala & Dada',
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),

                  // Center Guidance
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentZone == ProximityZone.clear
                              ? Icons.check_circle_outline
                              : _currentZone == ProximityZone.critical
                                  ? Icons.warning_amber_rounded
                                  : Icons.vibration,
                          color: Colors.white,
                          size: 72,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _currentZone == ProximityZone.clear
                              ? 'JALUR AMAN'
                              : _currentZone == ProximityZone.awareness
                                  ? 'RINTANGAN JAUH (> 2M)'
                                  : _currentZone == ProximityZone.caution
                                      ? 'WASPADA DEKAT (1-2M)'
                                      : 'BAHAYA KRITIS! BERHENTI (< 1M)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Deteksi: $_detectedLabel',
                          style: TextStyle(
                            color: Colors.white.withAlpha(204),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Interactive Simulation Controls for Demo
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(102),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PENGUJIAN SENSOR RINTANGAN (SIMULASI ALUR):',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _simulateObstacleZone(ProximityZone.clear),
                                child: const Text('Aman'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _simulateObstacleZone(ProximityZone.awareness),
                                child: const Text('> 2m'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _simulateObstacleZone(ProximityZone.caution),
                                child: const Text('1-2m'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _simulateObstacleZone(ProximityZone.critical),
                                child: const Text('< 1m'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Zero-UI Gesture Guide
                  Text(
                    'Instruksi Gestur: 1 Ketukan (Status) • 2 Ketukan (Mode Senyap) • Tekan Tahan (Jeda/Mulai)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withAlpha(153),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
