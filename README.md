# Netrava — Haptic & Audio AI Navigation Assistant for the Visually Impaired

Netrava adalah asisten navigasi cerdas berbasis **Android APK (Flutter / Android Native)** bertenaga tumpukan teknologi Google (*Google Technology Stack*) yang dirancang khusus untuk mobilitas penyandang disabilitas netra. Proyek ini dipersiapkan untuk kompetisi **Google Developer on Campus (GDGoC) ITB Challenge 2026**.

Netrava mengubah ponsel pintar menjadi sensor lingkungan proaktif yang memetakan jarak rintangan ke getaran taktil (*haptic feedback*) beramplitudo dinamis serta panduan suara ringkas.

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

## 📂 Struktur Dokumen Proyek

```
/home/arrafi/lomba/netrava/
├── PRD.md            # Product Requirements Document standar (fitur, metrik, persona, risiko)
├── ARCHITECTURE.md   # Arsitektur teknis detail, CameraX pipeline, MediaPipe, & Android Haptics
├── PITCH.md          # Naskah presentasi 3 menit & panduan demonstrasi panggung juri GDGoC ITB
├── AGENTS.md         # Instruksi rekayasa perangkat lunak standar
└── README.md         # Ringkasan proyek & tumpukan teknologi
```

---

## ⚠️ Penafian Keselamatan (*Safety Disclaimer*)

Netrava diposisikan sebagai **alat bantu pelengkap (*secondary sensory layer*)**, bukan pengganti tongkat putih fisik atau anjing pemandu. Pengguna tetap wajib menggunakan tongkat putih fisik untuk mendeteksi kontur tanah, anak tangga turun, dan lubang di permukaan jalan.
