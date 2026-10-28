enum ProximityZone {
  clear,
  awareness,
  caution,
  critical,
}

class HapticPatterns {
  // Clear / Aman: total hening (0 ms)
  static const List<int> clearTimings = [0];
  static const List<int> clearAmplitudes = [0];

  // Distant Awareness (> 2.0 m): Denyut lembut, amplitudo 60/255, hening 800 ms
  static const List<int> awarenessTimings = [0, 60, 800];
  static const List<int> awarenessAmplitudes = [0, 60, 0];

  // Cautionary Proximity (1.0 - 2.0 m): Denyut ganda ritmis, amplitudo 150/255
  static const List<int> cautionTimings = [0, 80, 150, 80, 500];
  static const List<int> cautionAmplitudes = [0, 150, 0, 150, 0];

  // Critical Hazard (< 1.0 m): Getaran kejut maksimal 255/255 (Stop Reflex!)
  static const List<int> criticalTimings = [0, 150, 50, 150, 50, 200];
  static const List<int> criticalAmplitudes = [0, 255, 0, 255, 0, 255];
}
