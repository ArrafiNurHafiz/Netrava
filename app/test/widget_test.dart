import 'package:flutter_test/flutter_test.dart';
import 'dart:ui';
import 'package:netrava_app/main.dart';
import 'package:netrava_app/core/constants/haptic_patterns.dart';
import 'package:netrava_app/core/services/vision_service.dart';
import 'package:netrava_app/core/services/arbitration_engine.dart';
import 'package:netrava_app/core/services/foreground_service.dart';

void main() {
  testWidgets('Netrava smoke test renders app and zero-ui', (WidgetTester tester) async {
    await tester.pumpWidget(const NetravaApp());

    // Pastikan Judul Aplikasi tampil
    expect(find.text('NETRAVA'), findsOneWidget);
    expect(find.text('JALUR AMAN'), findsOneWidget);
  });

  test('HapticPatterns timing consistency test', () {
    // Assert array getaran tidak kosong dan durasi timing valid
    expect(HapticPatterns.awarenessTimings.length, 3);
    expect(HapticPatterns.awarenessAmplitudes.length, 3);
    expect(HapticPatterns.criticalAmplitudes.last, 255);
  });

  group('VisionService Proximity & Upper Hazard Tests', () {
    const frameSize = Size(480, 640);

    test('Critical proximity calculated for dominating bounding box', () {
      const bigBox = Rect.fromLTWH(50, 50, 400, 500);
      final zone = VisionService.calculateProximity(bigBox, frameSize);
      expect(zone, ProximityZone.critical);
    });

    test('Caution proximity for medium distance obstacle', () {
      const medBox = Rect.fromLTWH(100, 150, 200, 250);
      final zone = VisionService.calculateProximity(medBox, frameSize);
      expect(zone, ProximityZone.caution);
    });

    test('Awareness proximity for distant obstacle', () {
      const smallBox = Rect.fromLTWH(150, 150, 100, 130);
      final zone = VisionService.calculateProximity(smallBox, frameSize);
      expect(zone, ProximityZone.awareness);
    });

    test('Upper hazard detection recognizes head/chest level obstacles', () {
      const headLevelBox = Rect.fromLTWH(100, 50, 150, 150);
      expect(VisionService.isUpperHazard(headLevelBox, frameSize), isTrue);

      const floorBox = Rect.fromLTWH(100, 500, 150, 120);
      expect(VisionService.isUpperHazard(floorBox, frameSize), isFalse);
    });
  });

  group('ArbitrationEngine Tests', () {
    test('ForegroundService channel signature matches contract', () {
      expect(ForegroundService.isRunning, isFalse);
    });

    test('Arbitration prioritizes critical upper hazard over clear state', () async {
      final engine = ArbitrationEngine();

      final criticalObstacle = DetectedObstacle(
        label: 'Low Hanging Branch',
        confidence: 0.9,
        boundingBox: const Rect.fromLTWH(50, 20, 300, 300),
        zone: ProximityZone.critical,
        isUpperBodyHazard: true,
      );

      final evaluatedZone = await engine.evaluateObstacles([criticalObstacle]);
      expect(evaluatedZone, ProximityZone.critical);
      expect(engine.currentZone, ProximityZone.critical);
    });

    test('Arbitration returns clear when obstacle list is empty', () async {
      final engine = ArbitrationEngine();
      final evaluatedZone = await engine.evaluateObstacles([]);
      expect(evaluatedZone, ProximityZone.clear);
    });
  });
}
