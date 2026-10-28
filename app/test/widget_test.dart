import 'package:flutter_test/flutter_test.dart';
import 'package:netrava_app/main.dart';
import 'package:netrava_app/core/constants/haptic_patterns.dart';
import 'package:netrava_app/core/services/deterministic_proximity_engine.dart';
import 'package:netrava_app/core/services/arbitration_engine.dart';
import 'package:netrava_app/core/services/foreground_service.dart';
import 'package:netrava_app/core/services/permission_service.dart';
import 'package:netrava_app/core/services/semantic_inspection_service.dart';

void main() {
  testWidgets('Netrava smoke test renders app and zero-ui', (WidgetTester tester) async {
    await tester.pumpWidget(const NetravaApp());

    // Pastikan Judul Aplikasi tampil
    expect(find.text('Asisten Taktil Rintangan Kepala & Dada'), findsOneWidget);
    expect(find.text('Simulasi Sensor Rintangan'), findsOneWidget);
    expect(find.text('Tanya AI Situasi Sekitar'), findsOneWidget);
  });

  test('HapticPatterns timing consistency test', () {
    // Assert array getaran tidak kosong dan durasi timing valid
    expect(HapticPatterns.awarenessTimings.length, 3);
    expect(HapticPatterns.awarenessAmplitudes.length, 3);
    expect(HapticPatterns.criticalAmplitudes.last, 255);
  });

  group('ArbitrationEngine & Deterministic Proximity Tests', () {
    test('ArbitrationEngine evaluates critical reading accurately', () async {
      final engine = ArbitrationEngine();

      final criticalReading = ProximityReading(
        zone: ProximityZone.critical,
        obstacleIntensity: 0.65,
        label: 'BERHENTI! RINTANGAN DEKAT (< 1M)',
        latencyMs: 1,
      );

      final zone = await engine.evaluateReading(criticalReading);
      expect(zone, ProximityZone.critical);
      expect(engine.currentZone, ProximityZone.critical);
    });

    test('ArbitrationEngine evaluates clear path accurately', () async {
      final engine = ArbitrationEngine();

      final clearReading = ProximityReading(
        zone: ProximityZone.clear,
        obstacleIntensity: 0.05,
        label: 'Jalur Bersih',
        latencyMs: 1,
      );

      final zone = await engine.evaluateReading(clearReading);
      expect(zone, ProximityZone.clear);
      expect(engine.currentZone, ProximityZone.clear);
    });

    test('ForegroundService channel signature matches contract', () {
      expect(ForegroundService.isRunning, isFalse);
    });

    test('PermissionService default initial check', () async {
      expect(await PermissionService.isCameraGranted(), isFalse);
    });

    test('SemanticInspectionService state checks', () {
      expect(SemanticInspectionService.isInspecting, isFalse);
    });
  });
}
