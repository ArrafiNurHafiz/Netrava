import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'presentation/screens/zero_ui_navigator_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Kunci orientasi vertikal untuk ergonomi saku kemeja
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const NetravaApp());
}

class NetravaApp extends StatelessWidget {
  const NetravaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netrava',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'sans-serif',
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF0F172A),
        ),
      ),
      home: const ZeroUiNavigatorScreen(),
    );
  }
}
