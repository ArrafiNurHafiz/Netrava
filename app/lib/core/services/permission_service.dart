import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Meminta seluruh izin runtime kritis yang dibutuhkan Netrava
  static Future<bool> requestAllPermissions() async {
    try {
      // 1. Izin Kamera (Wajib untuk pemindaian visi)
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        return false;
      }

      // 2. Izin Notifikasi (Wajib untuk Android 13+ Foreground Service persisten)
      await Permission.notification.request();

      // 3. Izin Mengabaikan Optimasi Baterai (Agar pemindaian tidak dibunuh OS saat layar mati)
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah izin kamera sudah diberikan
  static Future<bool> isCameraGranted() async {
    try {
      return await Permission.camera.isGranted;
    } catch (_) {
      return false;
    }
  }
}
