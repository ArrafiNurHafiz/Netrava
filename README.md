# Netrava — Haptic & Audio AI Navigation Assistant for the Visually Impaired

[![Download APK](https://img.shields.io/badge/Download-Netrava%20APK%20(v1.0.9%20Bugfix)--blue?style=for-the-badge&logo=android)](https://github.com/ArrafiNurHafiz/Netrava/releases/latest/download/netrava-v1.0.9-release.apk)

Netrava adalah asisten navigasi cerdas berbasis **Android APK (Flutter / Android Native)** bertenaga tumpukan teknologi Google (*Google Technology Stack*) yang dirancang khusus untuk mobilitas penyandang disabilitas netra. Proyek ini dipersiapkan untuk kompetisi **Google Developer on Campus (GDGoC) ITB Challenge 2026**.

Netrava mengubah ponsel pintar menjadi sensor lingkungan proaktif yang memetakan jarak rintangan ke getaran taktil (*haptic feedback*) beramplitudo dinamis serta panduan suara ringkas.

---

## 📥 Unduh & Pasang Aplikasi

Aplikasi Android Netrava siap diunduh dan dipasang langsung pada ponsel pintar Android Anda:

- **Tautan Unduh Langsung (Versi v1.0.9 - Bugfix YOLOv8 Parsing):** [netrava-v1.0.9-release.apk](https://github.com/ArrafiNurHafiz/Netrava/releases/latest/download/netrava-v1.0.9-release.apk)
- **Halaman Rilis GitHub:** [GitHub Releases Netrava](https://github.com/ArrafiNurHafiz/Netrava/releases/tag/v1.0.9)

### Panduan Instalasi di Ponsel:
1. Klik tautan unduh di atas menggunakan peramban ponsel Android Anda.
2. Buka berkas `netrava-v1.0.9-release.apk` yang telah diunduh, lalu pilih **Install**.
3. Buka aplikasi Netrava, lalu klik **Izinkan** pada pop-up izin **Kamera** dan **Notifikasi**.
4. Selipkan ponsel di saku kemeja bagian dada dengan kamera menghadap ke depan. Anda dapat mematikan layar ponsel untuk menghemat daya; Netrava akan tetap memandu langkah Anda melalui getaran di dada.

---

## 📌 Masalah yang Diselesaikan

1. **Titik Buta Tongkat Putih (Rintangan Dada & Kepala):** Tongkat putih hanya menyapu lantai. Dahan pohon rendah, tiang rambu setinggi kepala, palang portal, atau kap mobil boks yang terbuka luput dari deteksi dan sering menyebabkan cedera benturan pada kepala pengguna.
2. **Kelelahan Sensorik Pendengaran (*Auditory Fatigue*):** Aplikasi navigasi yang cerewet berbicara menutupi suara klakson, deru motor, dan gema langkah kaki yang krusial bagi keselamatan tunanetra di jalan raya.
3. **Tingginya Biaya Perangkat Bantu Khusus:** Kacamata pintar atau tongkat ultrasonik impor dibanderol Rp 9.000.000 hingga Rp 40.000.000, menciptakan jurang aksesibilitas bagi masyarakat luas.

---

## 🚀 Fitur Utama

- **Peringatan Rintangan Haptik Berjenjang (Android `VibrationEffect`):** Mengatur kekuatan getaran (amplitudo 1–255) dan ritme secara langsung sesuai jarak objek:
  - *Jalur Bersih:* Hening total (tanpa getaran untuk mencegah kelelahan sensorik).
  - *Rintangan Jauh (> 2 m):* Denyut lembut santai (amplitudo 60/255).
  - *Rintangan Waspada (1–2 m):* Denyut ganda berirama sedang (amplitudo 150/255).
  - *Bahaya Kritis (< 1 m):* Getaran kejut maksimal (amplitudo 255/255) tanda perintah berhenti seketika.
- **100% On-Device Edge AI (< 30 ms Latensi):** Ditenagai **Google MediaPipe Tasks Vision** dan **TensorFlow Lite (TFLite)** yang berjalan luring tanpa butuh internet di perangkat.
- **Dukungan Layar Mati & Saku Kemeja (Foreground Service):** Aplikasi tetap aktif memindai rintangan dan memicu getaran di dada saat layar ponsel dimatikan. Menghemat daya baterai dan mencegah salah sentuh.
- **Penjelasan Situasi Semantik (Google Gemini 1.5 Flash):** Menjelaskan gambaran ruangan secara komprehensif saat pengguna menekan tombol fisik perangkat.
- **Antarmuka Gestur Non-Visual (*Zero-UI*):** Seluruh permukaan layar merespons ketukan sentuhan sederhana tanpa tombol-tombol kecil.
- **Privasi Mutlak:** Pemrosesan visual berlangsung lokal di ponsel pengguna tanpa mengirim aliran video ke server eksternal.

---

## 🛠️ Tumpukan Teknologi Google (*Google Technology Stack*)

- **Framework Klien:** Flutter (Dart) / Android Native (Kotlin)
- **Vision Engine:** Google MediaPipe Tasks Vision for Android (`ObjectDetector`)
- **Akselerasi AI:** TensorFlow Lite (TFLite) + GPU/NNAPI Delegate
- **Kamera:** Android Jetpack CameraX API
- **Haptic Engine:** Android Haptics API (`VibrationEffect` waveform & amplitude modulation)
- **Audio:** Google Text-to-Speech (TTS) Engine bawaan Android (luring Bahasa Indonesia)
- **Generative AI:** Google Gemini 1.5 Flash / Gemini Nano (deskripsi semantik ruangan)
- **Cloud Service:** Firebase Cloud Firestore & Firebase Hosting

---

## 📂 Struktur Proyek

```
.
├── docs/                      # Dokumentasi teknis & rekayasa produk
│   ├── PRD.md                 # Product Requirements Document
│   ├── ARCHITECTURE.md        # Arsitektur sistem, camera pipeline, & haptics
│   └── AGENTS.md              # Standar instruksi rekayasa & verifikasi
├── app/                       # Source code aplikasi mobile Flutter (Android)
│   ├── android/               # Native Android wrapper (CameraX, Haptics, Service)
│   ├── lib/
│   │   ├── core/              # Constants & background services
│   │   │   ├── constants/     # HapticPatterns (Waveform timings & amplitude)
│   │   │   └── services/      # CameraService, VisionService, HapticService, TTS
│   │   ├── presentation/      # UI Layer (ZeroUiNavigatorScreen tactile surface)
│   │   └── main.dart          # Entry point aplikasi
│   └── test/                  # Automated unit & widget tests
└── README.md                  # Ikhtisar proyek
```

---

## ⚠️ Penafian Keselamatan (*Safety Disclaimer*)

Netrava diposisikan sebagai **alat bantu pelengkap (*secondary sensory layer*)**, bukan pengganti tongkat putih fisik atau anjing pemandu. Pengguna tetap wajib menggunakan tongkat putih fisik untuk mendeteksi kontur tanah, anak tangga turun, dan lubang di permukaan jalan.
