# Spesifikasi Arsitektur Teknis — Netrava (Android APK Stack)

Dokumen ini mendefinisikan desain teknis, komponen arsitektur, pipa data visual (*data pipeline*), serta spesifikasi implementasi mesin haptik Netrava berbasis ekosistem resmi Google untuk GDGoC ITB 2026.

---

## 1. Diagram Alur Sistem (*Dataflow Architecture*)

```
                        ┌────────────────────────┐
                        │ Kamera Belakang Ponsel │
                        └───────────┬────────────┘
                                    │ Android CameraX ImageAnalysis (YUV_420_888)
                                    ▼
                        ┌────────────────────────┐
                        │   Frame Preprocessor   │ (Konversi Bitmap & Normalisasi 320x320)
                        └───────────┬────────────┘
                                    │ MPImage Tensor
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│             Google MediaPipe Tasks Vision (Object Detector)            │
│                                                                        │
│   Akselerasi: TensorFlow Lite (TFLite) GPU / NNAPI Delegate            │
│   Model: EfficientDet-Lite / MobileNetV4 INT8 Quantized                │
│   Output: Deteksi Objek, Bounding Box [x, y, w, h], Skor Keyakinan     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Daftar Deteksi Real-Time (< 30 ms)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   Spatial & Proximity Analyzer                         │
│                                                                        │
│   1. Area Fokus Vertikal (Upper-Body & Head Zone ROI)                  │
│   2. Estimasi Jarak Proksimitas Geometri:                              │
│      - Area Bounding Box > 45%: Zona Kritis (< 1.0 m)                  │
│      - Area Bounding Box 20-45%: Zona Waspada (1.0 - 2.0 m)            │
│      - Area Bounding Box 10-20%: Zona Kesadaran (> 2.0 m)              │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Urgensi Bahaya & Arah
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                   Sensory Arbitration & Decision Hub                   │
│                                                                        │
│   State: Mode Senyap (Haptik Murni) vs Mode Normal (Haptik + Audio)    │
│   Prioritas: Kritis (Amplitudo 255) > Waspada (150) > Jauh (60)        │
└───────────────────┬────────────────────────────────┬───────────────────┘
                    │                                │
                    ▼                                ▼
       ┌────────────────────────┐       ┌─────────────────────────┐
       │ Android Haptics Engine │       │ Google Text-to-Speech   │
       │ (VibrationEffect API)  │       │ (Android Native Engine) │
       │ Amplitudo 1 - 255      │       │ Audio Darurat 1 Kata    │
       └────────────────────────┘       └─────────────────────────┘
```

---

## 2. Struktur Arsitektur Flutter Client

```
lib/
├── main.dart                          # Titik Masuk & Inisialisasi Service
├── core/
│   ├── constants/
│   │   └── haptic_patterns.dart       # Konstanta Ritme & Amplitudo Getaran
│   └── services/
│       ├── camera_service.dart        # Integrasi Camera Stream Flutter
│       ├── vision_service.dart        # Google MediaPipe Tasks Vision (ObjectDetector)
│       ├── haptic_service.dart        # Android MethodChannel -> VibrationEffect
│       └── tts_service.dart           # Flutter TTS Wrapper (Google TTS Engine)
└── presentation/
    ├── screens/
    │   └── zero_ui_navigator_screen.dart # Layar Penuh Sentuh Non-Visual (Gestur)
    └── controllers/
        └── navigation_controller.dart # Logika Pengambilan Keputusan (Arbitration Engine)
```

### 2.1 Jembatan Haptic Android (`MethodChannel` Flutter)
Mengontrol motor getar presisi Android API 26+ (`VibrationEffect`) langsung dari Flutter:

```dart
class HapticService {
  static const MethodChannel _channel = MethodChannel('netrava.app/haptics');

  static Future<void> triggerZone(ProximityZone zone) async {
    switch (zone) {
      case ProximityZone.clear:
        await _channel.invokeMethod('cancel');
        break;
      case ProximityZone.awareness:
        // Jauh (> 2 m): Denyut Lembut Amplitudo 60/255 (Interval Hening 800ms)
        await _channel.invokeMethod('vibrateWaveform', {
          'timings': [0, 60, 800],
          'amplitudes': [0, 60, 0],
        });
        break;
      case ProximityZone.caution:
        // Sedang (1 - 2 m): Denyut Ganda Amplitudo 150/255
        await _channel.invokeMethod('vibrateWaveform', {
          'timings': [0, 80, 150, 80, 500],
          'amplitudes': [0, 150, 0, 150, 0],
        });
        break;
      case ProximityZone.critical:
        // Kritis (< 1 m): Getaran Kejut Maksimal Amplitudo 255/255 (Stop Reflex!)
        await _channel.invokeMethod('vibrateWaveform', {
          'timings': [0, 150, 50, 150, 50, 200],
          'amplitudes': [0, 255, 0, 255, 0, 255],
        });
        break;
    }
  }
}
```

### 2.2 Implementasi Sisi Native Android (`MainActivity.kt`) & Fallback Hardware
Sesuai standar *assistive mobile engineering*, dilakukan pemeriksaan `vibrator.hasAmplitudeControl()` untuk memastikan kompatibilitas penuh pada ponsel terjangkau (*budget smartphones*):

```kotlin
package com.gdgoc.netrava

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "netrava.app/haptics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> {
                    vibrator.cancel()
                    result.success(null)
                }
                "vibrateWaveform" -> {
                    val timings = (call.argument<List<Number>>("timings") ?: listOf()).map { it.toLong() }.toLongArray()
                    val amplitudes = (call.argument<List<Number>>("amplitudes") ?: listOf()).map { it.toInt() }.toIntArray()

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (vibrator.hasAmplitudeControl()) {
                            // Kontrol amplitudo penuh (Linear Resonant Actuator)
                            val effect = VibrationEffect.createWaveform(timings, amplitudes, -1)
                            vibrator.vibrate(effect)
                        } else {
                            // Fallback perangkat terjangkau tanpa modulasi amplitudo (Duty Cycle ON/OFF)
                            val effect = VibrationEffect.createWaveform(timings, -1)
                            vibrator.vibrate(effect)
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(timings, -1)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
```

### 2.2 Google MediaPipe Tasks Vision & TFLite
- **Pustaka:** `com.google.mediapipe:tasks-vision`
- **Konfigurasi Akselerasi:** Mengaktifkan GPU Delegate untuk pemrosesan paralel:
  ```kotlin
  val baseOptions = BaseOptions.builder()
      .setModelAssetPath("object_detector.tflite")
      .useGpu()
      .build()
  val options = ObjectDetector.ObjectDetectorOptions.builder()
      .setBaseOptions(baseOptions)
      .setRunningMode(RunningMode.LIVE_STREAM)
      .setMaxResults(5)
      .setScoreThreshold(0.5f)
      .build()
  ```

### 2.3 Layanan Latar Belakang & Layar Mati (Foreground Service)
- Memanfaatkan Android `Foreground Service` dengan `FOREGROUND_SERVICE_TYPE_CAMERA`.
- Memungkinkan kamera dan haptik tetap aktif memandu saat layar dimatikan (*screen-off*), menghemat baterai hingga 60% dan mencegah salah sentuh saat dimasukkan ke saku baju.

---

## 3. Spesifikasi Mesin Haptik Android (`VibrationEffect`)

Menggunakan motor getar presisi Android (API 26+) dengan modulasi amplitudo nyata (0–255):

```kotlin
class NetravaHapticEngine(private val context: Context) {
    private val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

    fun triggerProximityWarning(zone: ProximityZone) {
        if (!vibrator.hasVibrator()) return

        when (zone) {
            ProximityZone.CLEAR -> {
                vibrator.cancel()
            }
            ProximityZone.AWARENESS -> {
                // Denyut Lembut (Amplitudo 60/255, Durasi 60ms)
                val timing = longArrayOf(0, 60, 800)
                val amplitudes = intArrayOf(0, 60, 0)
                vibrator.vibrate(VibrationEffect.createWaveform(timing, amplitudes, -1))
            }
            ProximityZone.CAUTION -> {
                // Denyut Ganda Sedang (Amplitudo 150/255)
                val timing = longArrayOf(0, 80, 150, 80, 500)
                val amplitudes = intArrayOf(0, 150, 0, 150, 0)
                vibrator.vibrate(VibrationEffect.createWaveform(timing, amplitudes, -1))
            }
            ProximityZone.CRITICAL -> {
                // Getaran Bahaya Maksimal (Amplitudo 255/255) - Hentikan Langkah
                val timing = longArrayOf(0, 150, 50, 150, 50, 200)
                val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255)
                vibrator.vibrate(VibrationEffect.createWaveform(timing, amplitudes, -1))
            }
        }
    }
}
```

---

## 4. Integrasi Google Gemini (Semantic Situational Awareness)

Ketika pengguna membutuhkan gambaran ruangan secara holistik:
1. Pengguna memicu aksi (*double press volume up* atau *hold screen*).
2. Kamera menangkap *high-res snapshot*.
3. Model **Google Gemini 1.5 Flash** dipanggil dengan *prompt system* yang dioptimasi untuk tunanetra:
   ```text
   Anda adalah pemandu tunanetra Netrava. Jelaskan foto ini dalam maksimal 2 kalimat pendek:
   1. Sebutkan objek terbesar dan posisinya (kiri/kanan/depan).
   2. Beri tahu jalan keluar atau jalur yang bebas rintangan. Gunakan bahasa Indonesia lugas.
   ```
4. Respons dikonversi menjadi audio oleh **Google Text-to-Speech**.

---

## 5. Antarmuka Non-Visual (*Zero-UI Interaction Layer*)

Aplikasi APK menggunakan layar penuh sebagai *touch surface*:

| Aksi Gestur | Mekanisme Input | Aksi Sistem | Umpan Balik |
|---|---|---|---|
| **Ketukan Tunggal** | Layar disentuh 1x | Membaca status rintangan & baterai | Suara Google TTS |
| **Ketukan Ganda** | Layar disentuh 2x cepat | *Toggle* Mode Senyap $\leftrightarrow$ Mode Normal | Efek Haptik `EFFECT_DOUBLE_CLICK` |
| **Tekan Tombol Volume** | *Hardware Key Listener* | Minta deskripsi lingkungan (Gemini 1.5) | Suara Google TTS Deskriptif |
| **Layar Dimatikan** | Tombol *Power* ditekan | Masuk mode *Background Guidance* | Getaran lembut 1x |
