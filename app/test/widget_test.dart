import 'package:flutter_test/flutter_test.dart';
import 'package:netrava_app/main.dart';
import 'package:netrava_app/core/constants/haptic_patterns.dart';

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
}
