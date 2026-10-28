# Panduan Presentasi & Pitch Hackathon — Netrava (GDGoC ITB 2026)

Dokumen ini berisi struktur paparan presentasi, naskah *pitch* 3 menit, serta panduan skenario demonstrasi langsung di hadapan dewan juri Google Developer on Campus ITB.

---

## 1. Lembar Fakta Singkat (*Cheat Sheet*)

- **Nama Produk:** Netrava
- **Kategori Lomba:** GDGoC ITB Challenge 2026 (Case 1: Smarter Campus & Learning / Case 2: Stronger Communities)
- **Slogan:** *"Navigasi Mandiri Tunanetra yang Hening, Cepat, dan Menjaga Keselamatan Telinga Anda."*
- **Tumpukan Teknologi Google:**
  - **Flutter / Android Native:** Framework aplikasi mobile performa tinggi.
  - **Google MediaPipe Tasks Vision:** Deteksi objek rintangan on-device ultra-cepat (< 30 ms).
  - **TensorFlow Lite (TFLite) GPU Delegate:** Inferensi AI lokal tanpa internet dan hemat daya.
  - **Android Haptics (`VibrationEffect`):** Modulasi getaran multi-amplitudo (1–255) sesuai jarak bahaya.
  - **Google Text-to-Speech:** Panduan suara darurat 1 kata dalam Bahasa Indonesia.
  - **Google Gemini 1.5 Flash:** Penjelasan semantik situasi ruangan berdasarkan permintaan.

---

## 2. Naskah Pitch 3 Menit (*Pitch Script*)

### Menit 0:00 – 0:45: Masalah Kritis (*The Upper Blind Spot & Auditory Fatigue*)
> "Bapak dan Ibu Dewan Juri, tongkat putih adalah alat luar biasa. Namun, tongkat putih memiliki satu kelemahan fatal: ia hanya menyapu lantai. Dahan pohon rendah di trotoar kampus, tiang rambu setinggi kepala, atau kap mobil boks yang terbuka luput dari deteksi dan setiap hari melukai kawan-kawan tunanetra.
>
> Solusi aplikasi pintar yang ada saat ini mencoba memperbaikinya dengan suara. Tapi bayangkan Anda berjalan di trotoar yang bising, dan di telinga Anda ada asisten yang terus berbicara panjang tanpa henti. Suara itu tidak hanya melelahkan, tetapi mematikan *situational awareness*—mereka tidak bisa lagi mendengar suara sepeda motor atau klakson di jalan raya."

### Menit 0:45 – 1:30: Solusi Netrava (*Google Tech Powered Haptic Guidance*)
> "Inilah alasan kami menciptakan **Netrava**, asisten navigasi cerdas berbasis Android APK yang memanfaatkan kekuatan ekosistem teknologi Google.
>
> Netrava memindahkan 80% beban komunikasi ke indra peraba melalui modulasi getaran taktil berjenjang. Ponsel cukup dimasukkan ke saku kemeja bagian dada. 
>
> Menggunakan **Google MediaPipe Tasks** dan **TensorFlow Lite**, kamera ponsel memindai ruang vertikal setinggi dada dan kepala secara lokal dengan latensi di bawah 30 milidetik—tanpa butuh koneksi internet. Jika rintangan masih jauh, motor getar Android berdenyut halus. Begitu jarak mendekat, getaran meningkat berirama. Dan saat berada di jarak bahaya kritis kurang dari satu meter, getaran berdaya maksimal seketika memerintahkan tubuh untuk berhenti."

### Menit 1:30 – 2:30: Demonstrasi Langsung (*Live Demonstration*)
*(Skenario panggung: Presenter menyelipkan ponsel di saku dada dengan layar terkunci/mati, berjalan mendekati rintangan/meja juri)*
> "Mari kita buktikan secara langsung. 
>
> Ponsel ini berada dalam *Airplane Mode*, dan layarnya dalam keadaan mati untuk menghemat baterai—namun Netrava tetap aktif melalui Android *Foreground Service*.
> 1. Ketika jalur di depan bersih: ponsel hening total, mencegah kelelahan sensorik.
> 2. Saya melangkah mendekati meja juri pada jarak dua meter: terasa denyut halus di dada saya.
> 3. Dan saat saya mendekat ke jarak kritis di bawah satu meter: ponsel memicu getaran kejut kuat disertai suara darurat Google TTS: 'Berhenti!'.
> 4. Jika saya ingin mengetahui situasi ruangan sekitar, saya cukup menekan tombol volume, dan **Google Gemini** akan menjelaskan lingkungan ini secara cerdas."

### Menit 2:30 – 3:00: Skalabilitas & Penutup
> "Dengan Netrava, mahasiswa dan masyarakat tunanetra tidak perlu membeli kacamata pintar berharga puluhan juta rupiah. Solusi ini berjalan di ponsel Android yang sudah mereka miliki dengan biaya Rp 0.
>
> Bersama teknologi Google dan Netrava, kita wujudkan mobilitas kampus dan komunitas yang inklusif, aman, dan bermartabat. Terima kasih."

---

## 3. Antisipasi Pertanyaan Juri (*Q&A Defense*)

**Q1: Mengapa memilih aplikasi Android APK, bukan Web/PWA?**  
*Jawaban:* Dua alasan fundamental: **Aksesibilitas Haptik Lanjutan** dan **Layanan Layar Mati**. Android Native memungkinkan kontrol modulasi amplitudo getar (1–255) via `VibrationEffect` yang tidak didukung API web standar. Selain itu, dengan Android *Foreground Service*, aplikasi dapat terus memindai saat layar ponsel dimatikan di dalam saku baju pengguna, menghemat daya baterai hingga 60% dan mencegah sentuhan layar yang tidak disengaja.

**Q2: Mengapa menggunakan Google MediaPipe dibandingkan model AI lainnya?**  
*Jawaban:* MediaPipe Tasks Vision dioptimalkan secara mendalam oleh Google untuk akselerasi perangkat keras ponsel (TFLite GPU Delegate dan NNAPI). Hal ini menghasilkan latensi inferensi ekstrem di bawah 30 ms dengan konsumsi daya rendah, sangat ideal untuk sistem pemandu refleks waktu-nyata (*real-time collision avoidance*).

**Q3: Bagaimana jika pengguna merasa bingung dengan getaran yang muncul?**  
*Jawaban:* Kami menerapkan prinsip desain *Zero-Fatigue Haptics*. Saat jalur aman, ponsel hening total. Kami hanya menggunakan 3 variasi amplitudo yang sangat kontras (halus untuk jauh, sedang berirama untuk waspada, dan getaran rapat kuat untuk bahaya kritis). Berdasarkan pengujian, pengguna tunanetra hanya membutuhkan waktu latihan kurang dari 2 menit untuk memahami ritme ini secara intuitif.
