import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../core/constants/haptic_patterns.dart';
import '../../core/services/haptic_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/deterministic_proximity_engine.dart';
import '../../core/services/arbitration_engine.dart';
import '../../core/services/foreground_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/semantic_inspection_service.dart';
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
  bool _isAiInspecting = false;
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

    // 3. Inisialisasi Kamera Belakang jika izin diberikan
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

  /// Menghubungkan CameraX Stream ke Mesin Deterministik Super Ringan (< 2 ms)
  void _startLiveCameraPipeline() {
    CameraService.startImageStream((image) async {
      if (!_isScanning) return;

      // Pemrosesan instan 16x16 grid murni integer tanpa neural network
      final reading = DeterministicProximityEngine.processFrame(image);
      if (reading != null) {
        final zone = await _arbitration.evaluateReading(
          reading,
          onAutoAiTrigger: () {
            _triggerSemanticAiInspection();
          },
        );

        if (mounted && (zone != _currentZone || _detectedLabel != reading.label)) {
          setState(() {
            _currentZone = zone;
            _detectedLabel = '${reading.label} (${reading.latencyMs}ms)';
          });
        }
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
    TtsService.stop();
    HapticService.cancel();
    super.dispose();
  }

  /// On-Demand Semantic Scene Inspection via 9Router Combo Rap (Gemini Backend)
  Future<void> _triggerSemanticAiInspection() async {
    if (_isAiInspecting || !CameraService.isInitialized) return;

    setState(() {
      _isAiInspecting = true;
    });

    HapticService.triggerZone(ProximityZone.awareness);
    TtsService.speakStatus('Menganalisis situasi sekitar...');

    try {
      // Hentikan stream sesaat agar driver kamera Android dapat mengambil foto beresolusi penuh
      await CameraService.stopImageStream();
      await Future.delayed(const Duration(milliseconds: 150));

      final file = await CameraService.controller?.takePicture();

      // Nyalakan kembali stream navigasi real-time
      _startLiveCameraPipeline();

      if (file != null) {
        final bytes = await file.readAsBytes();
        final description = await SemanticInspectionService.inspectScene(
          imageJpgBytes: bytes,
        );

        if (description != null && description.isNotEmpty) {
          TtsService.speakStatus(description);
          setState(() {
            _detectedLabel = 'AI: $description';
          });
        } else {
          TtsService.speakAlert('Gagal terhubung ke asisten AI.');
        }
      }
    } catch (_) {
      _startLiveCameraPipeline();
      TtsService.speakAlert('Kamera sibuk.');
    } finally {
      if (mounted) {
        setState(() {
          _isAiInspecting = false;
        });
      }
    }
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
    // Zero-UI Non-Visual: Ketuk 2x di sembarang layar untuk tanya situasi sekitar ke AI
    HapticService.triggerZone(ProximityZone.caution);
    _triggerSemanticAiInspection();
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
    
    final simulatedReading = ProximityReading(
      zone: zone,
      obstacleIntensity: zone == ProximityZone.critical
          ? 0.8
          : zone == ProximityZone.caution
              ? 0.4
              : 0.15,
      label: zone == ProximityZone.critical
          ? 'Tiang / Dahan Dekat'
          : zone == ProximityZone.caution
              ? 'Pejalan Kaki (1-2M)'
              : 'Objek Jauh (> 2M)',
      latencyMs: 1,
    );

    final evaluatedZone = await _arbitration.evaluateReading(simulatedReading);

    setState(() {
      _currentZone = evaluatedZone;
      _detectedLabel = simulatedReading.label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isClear = _currentZone == ProximityZone.clear;
    final bool isAwareness = _currentZone == ProximityZone.awareness;
    final bool isCaution = _currentZone == ProximityZone.caution;
    final bool isCritical = _currentZone == ProximityZone.critical;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC), // Soft modern light grey-blue
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _onSingleTap,
          onDoubleTap: _onDoubleTap,
          onLongPress: _onLongPress,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TOP APP BAR / HEADER
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Color(0xFF1E293B)),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: 'NETR',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                TextSpan(
                                  text: 'AVA',
                                  style: TextStyle(
                                    color: Color(0xFF4F46E5),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            'Asisten Taktil Rintangan Kepala & Dada',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Battery indicator pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.battery_std, size: 14, color: Color(0xFF16A34A)),
                          SizedBox(width: 4),
                          Text(
                            '85%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569), size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 2. CAMERA PREVIEW CARD (Rounded Card with live active feed)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isCameraReady && CameraService.controller != null)
                        CameraPreview(CameraService.controller!)
                      else
                        Container(
                          color: const Color(0xFF0F172A),
                          child: const Center(
                            child: Icon(Icons.videocam_off, color: Colors.white38, size: 48),
                          ),
                        ),

                      // Overlay Top-Left: "Kamera Aktif" Pill
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0x99000000),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Kamera Aktif',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Overlay Top-Right: Crop/Expand Pill
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0x99000000),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.crop_free, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. MAIN STATUS CARD (JALUR AMAN / RINTANGAN)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isCritical
                          ? const Color(0xFFFCA5A5)
                          : isCaution
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFE0E7FF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isCritical
                            ? const Color(0x1ADB0000)
                            : isCaution
                                ? const Color(0x1AD97706)
                                : const Color(0x122563EB),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Concentric Circle Icon Badge
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isCritical
                              ? const Color(0xFFFEE2E2)
                              : isCaution
                                  ? const Color(0xFFFEF3C7)
                                  : const Color(0xFFEFF6FF)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isCritical
                                ? const Color(0xFFFECACA)
                                : isCaution
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFDBEAFE)),
                          ),
                          child: Icon(
                            _isAiInspecting
                                ? Icons.auto_awesome
                                : isCritical
                                    ? Icons.warning_amber_rounded
                                    : isCaution
                                        ? Icons.error_outline
                                        : Icons.shield_outlined,
                            size: 28,
                            color: isCritical
                                ? const Color(0xFFDC2626)
                                : isCaution
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: 'JALUR ',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            TextSpan(
                              text: _isAiInspecting
                                  ? 'ANALISIS AI...'
                                  : isCritical
                                      ? 'KRITIS (< 1M)'
                                      : isCaution
                                          ? 'WASPADA (1-2M)'
                                          : isAwareness
                                              ? 'AWAS (> 2M)'
                                              : 'AMAN',
                              style: TextStyle(
                                color: isCritical
                                    ? const Color(0xFFDC2626)
                                    : isCaution
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFF2563EB),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Deteksi: $_detectedLabel',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 4. SENSOR SECTION TITLE & QUICK ACTION
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Simulasi Sensor Rintangan',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Simulasi jarak...',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      'Uji Sensor >',
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 5. 4-COLUMN SENSOR DISTANCE CARDS
                Row(
                  children: [
                    // Card 1: Aman
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _simulateObstacleZone(ProximityZone.clear),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isClear ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                              width: isClear ? 2 : 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: isClear ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Aman',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Icon(Icons.directions_walk, size: 18, color: Color(0xFF64748B)),
                              const SizedBox(height: 4),
                              const Text(
                                'Tidak ada rintangan',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Card 2: > 2m
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _simulateObstacleZone(ProximityZone.awareness),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isAwareness ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                              width: isAwareness ? 2 : 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: isAwareness ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '> 2 m',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Icon(Icons.near_me_outlined, size: 18, color: Color(0xFF64748B)),
                              const SizedBox(height: 4),
                              const Text(
                                'Jarak jauh',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Card 3: 1 - 2m
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _simulateObstacleZone(ProximityZone.caution),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB), // Soft amber tint
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCaution ? const Color(0xFFD97706) : const Color(0xFFFDE68A),
                              width: isCaution ? 2 : 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0FCA8A04),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 20,
                                color: isCaution ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '1 - 2 m',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                              const SizedBox(height: 4),
                              const Text(
                                'Rintangan dekat',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 8.5, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Card 4: < 1m
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _simulateObstacleZone(ProximityZone.critical),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2), // Soft red tint
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCritical ? const Color(0xFFDC2626) : const Color(0xFFFECACA),
                              width: isCritical ? 2 : 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x10DC2626),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.dangerous_rounded,
                                size: 20,
                                color: isCritical ? const Color(0xFFDC2626) : const Color(0xFFEF4444),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '< 1 m',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Icon(Icons.front_hand_rounded, size: 18, color: Color(0xFFDC2626)),
                              const SizedBox(height: 4),
                              const Text(
                                'Rintangan sangat dekat',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 8, color: Color(0xFFB91C1C)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 6. ACTION BUTTON: "Tanya AI Situasi Sekitar" (Primary Action Pill)
                GestureDetector(
                  onTap: _triggerSemanticAiInspection,
                  child: Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x552563EB),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                            SizedBox(width: 12),
                            Text(
                              'Tanya AI Situasi Sekitar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0x33FFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 7. FOOTER CARD: "Instruksi Gestur"
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 6),
                          Text(
                            'Instruksi Gestur',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildGestureStep('1', 'Ketukan (Status)'),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.chevron_right, size: 14, color: Color(0xFFCBD5E1)),
                          ),
                          _buildGestureStep('2', 'Ketukan (Tanya AI)'),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.chevron_right, size: 14, color: Color(0xFFCBD5E1)),
                          ),
                          Expanded(
                            child: _buildGestureStep('3', 'Tahan (Jeda/Mulai)'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestureStep(String number, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
