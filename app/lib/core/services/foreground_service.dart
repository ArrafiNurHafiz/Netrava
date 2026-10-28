import 'package:flutter/services.dart';

class ForegroundService {
  static const MethodChannel _channel = MethodChannel('netrava.app/foreground_service');
  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  /// Memulai Android Foreground Service dengan notifikasi persisten
  /// Memungkinkan pemindaian rintangan & getaran haptik tetap berjalan saat layar ponsel dimatikan di saku baju
  static Future<bool> startService() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('startService');
      _isRunning = success ?? false;
      return _isRunning;
    } catch (_) {
      return false;
    }
  }

  /// Menghentikan Android Foreground Service
  static Future<bool> stopService() async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('stopService');
      _isRunning = false;
      return success ?? false;
    } catch (_) {
      return false;
    }
  }
}
