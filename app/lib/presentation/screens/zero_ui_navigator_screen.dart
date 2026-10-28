import 'package:flutter/material.dart';
import '../../core/constants/haptic_patterns.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/camera_service.dart';

class ZeroUiNavigatorScreen extends StatefulWidget {
  const ZeroUiNavigatorScreen({super.key});

  @override
  State<ZeroUiNavigatorScreen> createState() => _ZeroUiNavigatorScreenState();
}

class _ZeroUiNavigatorScreenState extends State<ZeroUiNavigatorScreen> {
  bool _isSilentMode = false;
  bool _isScanning = true;
  ProximityZone _currentZone = ProximityZone.clear;
  bool _hasAmplitude = false;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrapServices();
  }

  Future<void> _bootstrapServices() async {
    // 1. Inisialisasi Hardware Haptics
    final hasControl = await HapticService.hasAmplitudeControl();
    
    // 2. Inisialisasi Google TTS Luring
    await TtsService.initialize();

    // 3. Inisialisasi Kamera Belakang
    final cameraOk = await CameraService.initialize();

    if (mounted) {
      setState(() {
        _hasAmplitude = hasControl;
        _isCameraReady = cameraOk;
      });
      // Beri pengumuman audio pembuka
      TtsService.speakStatus('Netrava siap. Jalur aman.');
    }
  }

  @override
  void dispose() {
    CameraService.dispose();
    TtsService.stop();
    HapticService.cancel();
    super.dispose();
  }

  void _onSingleTap() {
    // Zero-UI: Pengumuman status suara luring
    final statusMsg = '${_isScanning ? "Memindai aktif" : "Jeda"}. '
        '${_isSilentMode ? "Mode haptik senyap" : "Mode suara aktif"}. '
        'Kamera ${_isCameraReady ? "aktif" : "siap simulasi"}.';

    if (!_isSilentMode) {
      TtsService.speakStatus(statusMsg);
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status: ${_isScanning ? "Memindai" : "Jeda"}. '
          'Mode: ${_isSilentMode ? "Senyap" : "Suara+Haptik"}. '
          'Kamera: ${_isCameraReady ? "Aktif" : "Simulasi"}. '
          'Motor: ${_hasAmplitude ? "PWM" : "DutyCycle"}.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onDoubleTap() {
    // Zero-UI: Beralih mode senyap
    setState(() {
      _isSilentMode = !_isSilentMode;
    });

    HapticService.triggerZone(ProximityZone.caution);

    if (!_isSilentMode) {
      TtsService.speakStatus('Mode suara aktif');
    } else {
      TtsService.stop();
    }
  }

  void _onLongPress() {
    // Zero-UI: Jeda / Lanjutkan pemindaian
    setState(() {
      _isScanning = !_isScanning;
      if (!_isScanning) {
        _currentZone = ProximityZone.clear;
        HapticService.cancel();
        CameraService.stopImageStream();
      }
    });

    HapticService.triggerZone(ProximityZone.awareness);
    if (!_isSilentMode) {
      TtsService.speakStatus(_isScanning ? 'Pemindaian dimulai' : 'Pemindaian dijeda');
    }
  }

  void _simulateObstacleZone(ProximityZone zone) {
    if (!_isScanning) return;
    setState(() {
      _currentZone = zone;
    });
    HapticService.triggerZone(zone);

    // Peringatan darurat 1 kata via TTS jika kritis dan bukan mode senyap
    if (!_isSilentMode) {
      if (zone == ProximityZone.critical) {
        TtsService.speakAlert('Berhenti!');
      } else if (zone == ProximityZone.caution) {
        TtsService.speakAlert('Waspada!');
      }
    }
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
