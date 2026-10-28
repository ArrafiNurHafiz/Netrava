# Product Requirements Document (PRD)

> **Document Status:** Draft  
> **Last Updated:** 27 Oktober 2026  
> **Product Manager:** Arrafi Nur Hafiz  
> **Competition:** STACK 2026 by GDGoC ITB (“Agent of the Ocean: Vibing Beyond the Code”)  
> **Selected Track:** Case 2 — Stronger Communities and Everyday Services  
> **Theme Connection:** “How might we make everyday services easier to access and manage for communities and small organizations?”  
> **Target Platform:** Android APK (Built with Flutter & Android Haptics Engine)

---

## Executive Summary

**Product Name:** Netrava (Haptic & Audio AI Navigation Assistant for the Visually Impaired Community)

**Target Community / Users:**  
Komunitas penyandang disabilitas netra (tunanetra total dan *low vision*), relawan pendamping difabel (*caregivers*), serta pengelola fasilitas layanan publik komunitas (halte, trotoar, kantor pos, puskesmas, balai warga).

**Problem Statement:**  
Penyandang disabilitas netra menghadapi hambatan besar dan risiko bahaya fisik saat mengakses layanan publik harian (*everyday services*) secara mandiri. Tongkat putih fisik hanya mampu mendeteksi rintangan di permukaan tanah/lantai, membiarkan rintangan setinggi dada dan kepala (tiang plang petunjuk jalan, dahan pohon rendah, kap kendaraan terbuka) mencederai pengguna. Di sisi lain, aplikasi navigasi suara yang ada memicu kelelahan sensorik (*auditory fatigue*) dan membahayakan keselamatan karena menutupi kebisingan lingkungan sekitar (*ambient auditory cues* seperti klakson dan deru kendaraan).

**Proposed Solution:**  
Netrava adalah aplikasi seluler Android APK yang dibangun menggunakan **Flutter** dengan integrasi **Google MediaPipe Tasks Vision on-device** dan **Android Haptics Engine (`VibrationEffect`)**. Netrava mentransformasi kamera ponsel pintar menjadi sensor proksimitas mikro yang memetakan jarak rintangan secara berjenjang ke getaran taktil beramplitudo dinamis (80% beban peringatan dialihkan ke getaran) dan panduan suara darurat ringkas (20%). Netrava memberdayakan komunitas tunanetra agar mandiri mengakses layanan harian tanpa ketergantungan relawan secara terus-menerus dan tanpa biaya perangkat keras tambahan (Rp 0).

**Success Metrics:**
- Latensi pemrosesan visual lokal dari tangkapan kamera hingga pemicuan getaran haptik $\le 30\text{ ms}$ secara 100% luring (*offline*).
- Akurasi pembedaan 3 tingkat urgensi getaran oleh pengguna uji coba $\ge 95\%$.
- Stabilitas *frame rate* deteksi kamera stabil pada rentang 20–30 FPS tanpa menyebabkan panas berlebih (*thermal throttling*).
- Efisiensi daya baterai ponsel: konsumsi $\le 8\%$ per 30 menit pemindaian aktif dengan dukungan *background / screen-off guidance*.

**Launch Target:** GDGoC ITB Challenge 2026 Preliminary Submission & Final Live Demo (2026)

---

## Background & Context

### Why Now?
Perkembangan pesat ekosistem **Google MediaPipe Tasks for Android** dan akselerasi perangkat keras **TFLite GPU/NNAPI Delegate** memungkinkan ponsel pintar kelas menengah menjalankan model visi komputer mutakhir secara lokal tanpa ketergantungan jaringan internet. Pada saat yang sama, motor getar ponsel pintar Android modern (*linear resonant actuator*) melalui API `VibrationEffect` memungkinkan modulasi getaran presisi (pengaturan amplitudo 1–255 dan efek haptik terstandarisasi) yang jauh melampaui kemampuan getar peramban web sederhana.

### User Research & Insights
- **Metode Riset:** Tinjauan ergonomi mobilitas disabilitas netra dan wawancara kebutuhan aksesibilitas mobilitas mandiri.
- **Temuan Kunci:**
  1. *Auditory Preservation:* Telinga adalah indra navigasi primer pengganti mata. Membebani telinga dengan instruksi audio verbal yang cerewet meningkatkan risiko kecelakaan fatal di trotoar dan jalan raya.
  2. *Upper-Body Blind Spot:* Tongkat putih hanya efektif menyapu kontur lantai dan rintangan di bawah pinggang, meninggalkan dada, bahu, dan kepala tanpa perlindungan.
  3. *Smartphone Ergonomics:* Ponsel pintar dapat disematkan pada saku kemeja bagian dada, digantung dengan tali *lanyard* di leher, atau dipegang di satu tangan sementara tangan lainnya mengayunkan tongkat putih.
- **Kutipan Kebutuhan Pengguna:**
  > "Saya butuh telinga saya tetap awas mendengar suara motor di jalan. Kalau aplikasi terus-terusan bicara di telinga saya, saya justru merasa tidak aman."

### Market Analysis & Competitive Advantage
- **Lanskap Kompetitor Eksisting:**
  1. *Be My Eyes / Envision AI*: Mengandalkan pemrosesan peladen awan (*cloud*) yang lambat (latensi 2–5 detik) dan membacakan deskripsi kalimat panjang yang tidak cocok untuk refleks menghindar rintangan cepat.
  2. *Lazarillo / BlindSquare*: Berfokus pada navigasi GPS makro (nama jalan dan belokan), tidak memiliki sensor proksimitas mikro terhadap rintangan fisik tepat di depan langkah kaki.
  3. *WeWALK Smart Cane & Kacamata Pintar Khusus*: Berharga sangat mahal (Rp 9.000.000 hingga Rp 40.000.000), memerlukan pengisian daya perangkat tambahan terpisah, dan rawan rusak mekanis.

- **5 Keunggulan Utama Netrava (Competitive Moat):**
  1. **Zero-Auditory Interference (Telinga Tetap Bebas):** 80% peringatan dialihkan ke indra peraba melalui variasi amplitudo getaran haptik.
  2. **Ultra-Low Latency & 100% Offline (< 30 ms):** Eksekusi lokal dengan Google MediaPipe dan TFLite GPU Delegate tanpa membutuhkan kuota internet.
  3. **Zero Extra Hardware Cost (Rp 0):** Memaksimalkan ponsel pintar Android milik pengguna tanpa membeli alat bantu fisik tambahan.
  4. **Proteksi Khusus Rintangan Dada & Kepala:** Menutup titik buta vertikal yang luput dari tongkat putih tradisional.
  5. **Dukungan Layar Mati / Saku Kemeja (Foreground Service):** Beroperasi stabil saat layar ponsel dimatikan untuk mencegah sentuhan tidak sengaja dan menghemat daya.

---

## Integrasi Ekosistem Teknologi Google & Mobile Assistive Pattern

Netrava mengimplementasikan teknologi Google secara terintegrasi dengan menerapkan standar *assistive mobile engineering*:

| Lapisan Sistem | Komponen Teknologi Google | Implementasi Teknis & Peran |
|---|---|---|
| **Framework Aplikasi** | **Flutter (Dart)** | Membangun antarmuka mobile APK berkinerja tinggi (60 FPS) dengan kode tunggal dan arsitektur *Service-Controller*. |
| **Vision AI Engine** | **Google MediaPipe Tasks (Vision for Android)** | Deteksi objek rintangan (*Object Detector*) dengan fokus ROI area vertikal atas (dada & kepala). |
| **Akselerasi Model** | **TensorFlow Lite (TFLite) + NNAPI Delegate** | Eksekusi model terkuantisasi INT8 di perangkat lokal tanpa koneksi awan (< 30 ms latensi). |
| **Pengendali Getaran** | **Android Haptics API (`VibrationEffect`)** | Mengontrol amplitudo kekuatan getar (1–255) via Flutter `MethodChannel` dengan fallback otomatis `hasAmplitudeControl()`. |
| **Sintesis Suara** | **Google Text-to-Speech Engine** | Umpan balik audio darurat luring yang ringkas (< 2 kata) untuk menjaga *auditory awareness*. |
| **Multimodal GenAI** | **Google Gemini 1.5 Flash / Gemini Nano** | Menghasilkan deskripsi semantik lingkungan publik komunitas ketika diminta pengguna via tombol fisik volume. |
| **Layanan Latar Depan** | **Android Foreground Service (`type=camera`)** | Memungkinkan kamera & haptik tetap memandu saat layar ponsel dimatikan (*screen-off*) di saku kemeja dada. |
| **Layanan Cloud** | **Firebase (Cloud Firestore & Hosting)** | Sinkronisasi preferensi profil getaran dan pendaftaran uji coba komunitas difabel. |

---

## Goals & Success Criteria

### Business & Hackathon Goals
1. Meraih penghargaan utama kategori *Accessibility & Assistive Tech* pada GDGoC ITB Challenge 2026.
2. Membuktikan keunggulan implementasi teknologi Google (Flutter, MediaPipe, TFLite, Android Haptics, Gemini) dalam memecahkan masalah riil disabilitas.
3. Menghadirkan solusi inklusif yang dapat langsung didistribusikan kepada komunitas kampus dan publik secara cuma-cuma.

### User Goals
1. Terhindar dari benturan rintangan gantung setinggi dada dan kepala saat beraktivitas mandiri.
2. Memahami derajat bahaya rintangan melalui gradasi getaran taktil yang intuitif tanpa kebingungan.
3. Menjaga pendengaran tetap awas terhadap kondisi lingkungan sekitar.

### Success Metrics (Detailed)

| Metrik | Nilai Dasar (*Baseline*) | Target Netrava APK | Metode Pengukuran |
|---|---|---|---|
| Latensi Deteksi ke Haptik | > 1.500 ms (Cloud VLM) | $\le 30\text{ ms}$ (Edge AI) | Android Profiler & Timestamp Benchmark |
| Kecepatan Pemrosesan Video | 5–10 FPS (Web Browser) | 20–30 FPS stabil | CameraX ImageAnalysis FPS Counter |
| Akurasi Respon Pola Getar | 60% | $\ge 95\%$ | Uji coba *blind test* bersama 5 pengguna |
| Ketergantungan Internet | Wajib internet aktif | 100% Luring untuk navigasi rintangan | Pengujian dalam kondisi *Airplane Mode* |
| Waktu Belajar Pengguna | > 10 menit | $< 2\text{ menit}$ | Waktu adaptasi memahami 3 tingkatan getar |

### Non-Goals (Out of Scope MVP)
- Pengenalan biometrik wajah individu atau pembacaan teks buku tebal secara menyeluruh.
- Pendeteksian lubang selokan terbuka atau tangga turun curam (fungsi mutlak tongkat putih fisik).
- Sistem navigasi GPS luar ruangan antarkota.

---

## User Personas & Use Cases

### Primary Persona: Budi Santoso (24 Tahun)
- **Peran:** Mahasiswa tunanetra total (*totally blind*), pengguna aktif tongkat putih di lingkungan kampus.
- **Tujuan:** Berpindah antargedung fakultas, perpustakaan, dan laboratorium secara mandiri tanpa terbentur plang rambu atau dahan pohon.
- **Hambatan:** Aplikasi asisten suara yang berisik menutupi suara langkah kaki dan kendaraan di jalan kampus; kedua tangan sering kali sibuk (satu memegang tongkat, satu membawa tas).
- **Konteks:** Ponsel diselipkan di saku kemeja bagian dada dengan kamera belakang menghadap ke depan.

### Key Use Cases

#### Use Case 1: Peringatan Rintangan Berjenjang dengan Amplitudo Getaran
- **Aktor:** Budi Santoso
- **Prasyarat:** Netrava aktif dalam mode pemindaian rintangan, kamera mengarah ke arah langkah kaki.
- **Alur Kerja:**
  1. Pengguna melangkah menuju lorong kampus; terdeteksi tiang pada jarak 3 meter.
  2. Netrava memicu getaran denyut lembut (amplitudo rendah 60/255, interval 800 ms).
  3. Pengguna terus melangkah mendekat hingga jarak 1,5 meter.
  4. Netrava meningkatkan getaran menjadi denyut ganda berdaya sedang (amplitudo 150/255).
  5. Pengguna mencapai jarak kritis < 1 meter di depan tiang.
  6. Netrava memicu getaran maksimum (amplitudo 255/255) beruntun cepat disertai audio darurat satu kata dari Google TTS: *"Berhenti!"*.
  7. Pengguna menghentikan langkah dan memverifikasi rintangan dengan tongkat putihnya.
- **Hasil:** Benturan kepala/dada terhindarkan dalam waktu reaksi seketika.

#### Use Case 2: Penjelasan Semantik Situasional via Google Gemini
- **Aktor:** Budi Santoso
- **Prasyarat:** Pengguna tiba di lobi gedung baru dan ingin mengetahui kondisi ruangan.
- **Alur Kerja:**
  1. Pengguna menekan tombol volume atas dua kali (*hardware gesture*).
  2. Netrava mengambil satu *frame* gambar resolusi tinggi dan mengirimkannya ke Google Gemini 1.5 Flash.
  3. Google Gemini memproses dan menghasilkan ringkasan singkat dalam 2 kalimat bahasa Indonesia.
  4. Google TTS membacakan: *"Anda berada di lobi utama. Di depan terdapat meja resepsionis, dan tangga berada di sisi kanan Anda."*
- **Hasil:** Orientasi ruangan didapatkan secara komprehensif atas permintaan pengguna (*on-demand*).

---

## Product Requirements

### Functional Requirements

#### Must Have (P0) - MVP Hackathon
1. **Pendeteksi Rintangan Visual Real-Time (Google MediaPipe Tasks Vision)**
   - Menangkap aliran video kamera belakang melalui Android CameraX API.
   - Inferensi deteksi objek rintangan (orang, tiang, kendaraan, dahan, pintu, kursi) secara lokal.
   - Estimasi jarak diskret 3 zona: Jauh (> 2 m), Sedang (1–2 m), Kritis (< 1 m).
2. **Mesin Haptik Beramplitudo Dinamis (Android VibrationEffect Engine)**
   - Pemicuan pola getaran getar multi-amplitudo:
     - *Aman (Jalur Bersih):* Hening total (0 ms).
     - *Jarak Jauh (> 2 m):* Denyut lembut, amplitudo 60/255, pola `[60, 800]`.
     - *Jarak Sedang (1–2 m):* Denyut ganda, amplitudo 150/255, pola `[80, 200, 80, 500]`.
     - *Bahaya Kritis (< 1 m):* Getaran kejut maksimal, amplitudo 255/255, pola `[200, 50, 200, 50, 200]`.
3. **Antarmuka Gestur Non-Visual & Dukungan Layar Mati (Zero-UI & Foreground Service)**
   - Seluruh permukaan layar merespons gestur sentuh (ketukan tunggal untuk status, ketukan ganda untuk beralih mode senyap).
   - Layanan latar depan (*Foreground Service*) agar pemindaian tetap aktif saat layar dimatikan di saku baju.
4. **Panduan Suara Darurat Luring (Google TTS)**
   - Umpan balik suara satu kata (*"Awas!"*, *"Berhenti!"*, *"Jalur Bersih"*) tanpa membebani pendengaran.

#### Should Have (P1) - Semifinal & Final
1. **Deskripsi Ruangan Cerdas (Google Gemini 1.5 Flash Integration)**
   - Analisis semantik kontekstual ruangan berbasis foto *frame* kamera atas permintaan pengguna.
2. **Integrasi Profil Firebase Cloud**
   - Kalibrasi sensitivitas getaran yang tersimpan secara awan di Firebase Firestore.

---

## Technical Specifications

### System Architecture
```
[ Kamera Belakang Ponsel ] 
           │
           ▼ (Android CameraX ImageAnalysis Stream)
[ Google MediaPipe Tasks Vision (Object Detector) ]
           │ (Akselerasi TFLite GPU/NNAPI Delegate)
           ▼
[ Spatial & Proximity Calculation Engine ]
           │
           ├── Klasifikasi Objek Rintangan
           └── Estimasi Zona Jarak (Rasio Geometri & Kedalaman)
           │
           ▼
[ Sensory Arbitration Hub ]
           │
     ┌─────┴─────────────────────────────────────────┐
     ▼                                               ▼
[ Android Haptics Engine ]             [ Google Text-to-Speech Engine ]
  - VibrationEffect API                  - Audio Darurat Ringkas (< 2 kata)
  - Amplitudo Dinamis (0 - 255)          - Berjalan 100% Luring
  - Pola Ritme Milidetik
```

---

## Dependencies & Risks

| Risiko | Dampak | Probabilitas | Rencana Mitigasi |
|---|---|---|---|
| Suhu ponsel meningkat saat pemrosesan kamera kontinu | Sedang | Sedang | Terapkan pembatasan *frame rate* (15–20 FPS) dan manfaatkan kuantisasi INT8 pada model TFLite. |
| Ponsel tipe lama tidak mendukung pengaturan amplitudo getar | Rendah | Rendah | Buat logika *fallback* otomatis ke durasi on/off getaran standar jika `vibrator.hasAmplitudeControl()` bernilai `false`. |
| Pengguna salah mengartikan Netrava sebagai pengganti tongkat | Tinggi | Sedang | Berikan penafian (*safety warning*) eksplisit melalui suara saat aplikasi pertama kali dinyalakan. |

---

## Changelog
- **Versi 2.0 (27 Oktober 2026):** Transformasi arsitektur dari Web PWA ke Android Native / Flutter APK dengan tumpukan teknologi Google resmi (MediaPipe, TFLite, Android Haptics, Google TTS, Gemini) untuk kompetisi GDGoC ITB Challenge 2026.
- **Versi 1.0 (27 Oktober 2026):** Draf awal PRD Netrava berbasis arsitektur Web PWA.
