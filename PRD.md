# PRODUCT REQUIREMENTS DOCUMENT (PRD)
# MERATRIP
## Aplikasi Perencanaan Perjalanan Wisata Merapi Berbasis Mobile

**Platform:** Android dan iOS  
**Teknologi utama:** Flutter  
**Target pengguna:** Semua wisatawan  
**Fokus utama:** Informasi destinasi dan perencanaan perjalanan wisata di kawasan Merapi  
**Status dokumen:** Draft PRD untuk pengembangan proyek akhir

---

## 1. Problem Statement

### 1.1 Latar Belakang

Kawasan Merapi memiliki berbagai destinasi wisata alam, sejarah, edukasi, dan petualangan. Wisatawan dapat mengunjungi beberapa tempat dalam satu perjalanan, tetapi perlu mencari informasi destinasi, lokasi, biaya, dan waktu kunjungan dari berbagai sumber.

Wisatawan juga perlu menentukan urutan kunjungan, memperkirakan anggaran, serta mengetahui rute menuju setiap destinasi. Informasi yang tersebar dapat membuat proses perencanaan perjalanan menjadi kurang praktis.

MeraTrip dikembangkan sebagai aplikasi mobile yang membantu wisatawan merencanakan perjalanan di kawasan Merapi melalui satu aplikasi. Pengguna dapat mencari destinasi, menyusun itinerary, menghitung estimasi biaya, melihat lokasi pada peta, dan memperoleh rekomendasi perjalanan menggunakan AI.

Aplikasi juga menyediakan penyimpanan data wisata secara lokal agar informasi yang telah diunduh tetap dapat dibuka tanpa koneksi internet. Fitur tambahan meliputi paket Jeep, konversi mata uang dan waktu, notifikasi, mini game, sensor smartphone, serta pencatatan blockchain sederhana.

### 1.2 Problem yang Diselesaikan

1. Informasi destinasi wisata Merapi belum terkumpul dalam satu aplikasi yang digunakan untuk perencanaan perjalanan.
2. Wisatawan perlu menyusun urutan kunjungan dan menghitung perkiraan biaya secara manual.
3. Wisatawan membutuhkan informasi lokasi dan rute menuju destinasi.
4. Informasi wisata yang sudah disimpan perlu tetap dapat diakses ketika koneksi internet tidak tersedia.
5. Wisatawan membutuhkan rekomendasi perjalanan berdasarkan durasi, anggaran, dan destinasi yang diminati.

### 1.3 Solusi Produk

MeraTrip menyediakan informasi destinasi terpusat, pencarian dan filter wisata, trip planner, estimasi anggaran, peta, penyimpanan offline, serta AI travel assistant.

Paket Jeep menjadi fitur tambahan yang dapat dimasukkan ke dalam rencana perjalanan. Booking Jeep bukan fokus utama produk.

---

## 2. Target User dan Persona

### 2.1 Target Pengguna

MeraTrip ditujukan kepada wisatawan lokal maupun mancanegara yang ingin mengunjungi kawasan Merapi.

Target pengguna meliputi:
- Wisatawan individu.
- Pasangan dan keluarga.
- Kelompok teman atau mahasiswa.
- Wisatawan yang baru pertama kali mengunjungi Merapi.
- Wisatawan yang ingin menyusun perjalanan sesuai waktu dan anggaran.

### 2.2 Persona 1: Wisatawan Mandiri

**Nama:** Dimas  
**Usia:** 21 tahun  
**Profil:** Mahasiswa yang berwisata bersama teman.

**Kebutuhan:**
- Mencari destinasi wisata yang menarik.
- Menyusun itinerary untuk perjalanan satu hari.
- Menghitung estimasi biaya.
- Mengetahui lokasi dan jarak antardestinasi.
- Menyimpan informasi wisata sebelum berangkat.

**Kendala:**
- Belum mengetahui urutan destinasi yang sesuai.
- Harus mencari informasi dari beberapa sumber.
- Ingin menghemat waktu dan biaya perjalanan.

**Tujuan menggunakan MeraTrip:**

Dimas ingin merencanakan perjalanan wisata Merapi secara mandiri tanpa harus menyusun semua informasi secara manual.

### 2.3 Persona 2: Wisatawan Keluarga

**Nama:** Rina  
**Usia:** 34 tahun  
**Profil:** Wisatawan yang berlibur bersama keluarga.

**Kebutuhan:**
- Menemukan destinasi yang sesuai untuk keluarga.
- Mengetahui informasi lokasi, harga tiket, dan fasilitas.
- Menyusun jadwal perjalanan yang tidak terlalu padat.
- Memperkirakan total biaya wisata.
- Mengakses informasi destinasi yang sudah disimpan.

**Kendala:**
- Harus menyesuaikan waktu kunjungan dengan kebutuhan keluarga.
- Membutuhkan informasi yang mudah diakses selama perjalanan.
- Ingin menghindari perjalanan yang tidak terencana.

**Tujuan menggunakan MeraTrip:**

Rina ingin membuat rencana wisata yang sesuai dengan kebutuhan keluarga dan mengetahui perkiraan biaya sebelum berangkat.

---

## 3. Goals dan Non-Goals

### 3.1 Goals

MeraTrip memiliki tujuan berikut.

1. Memudahkan pengguna mencari dan memilih destinasi wisata Merapi.
2. Membantu pengguna menyusun itinerary berdasarkan destinasi dan durasi perjalanan.
3. Menyediakan estimasi biaya perjalanan berdasarkan data harga yang tersedia.
4. Menampilkan lokasi pengguna dan lokasi destinasi melalui fasilitas LBS.
5. Menyediakan akses offline terhadap data wisata yang telah disimpan.
6. Memberikan rekomendasi perjalanan melalui AI.
7. Memenuhi seluruh kriteria wajib proyek akhir Pemrograman Aplikasi Mobile.

### 3.2 Non-Goals

Fitur berikut tidak menjadi fokus utama versi awal.

1. Sistem pembayaran online dan payment gateway.
2. Marketplace untuk seluruh operator wisata.
3. Sistem pemesanan hotel dan tiket transportasi umum.
4. Navigasi outdoor khusus pendakian gunung.
5. Sistem navigasi yang menjamin kondisi jalur atau keamanan perjalanan secara real-time.
6. Blockchain publik dan transaksi cryptocurrency.
7. Sistem administrasi pemerintah atau pengelolaan resmi destinasi.

Fitur tersebut dapat dipertimbangkan untuk pengembangan berikutnya jika kebutuhan dan waktu memungkinkan.

---

## 4. User Stories

| ID | User Story | Prioritas |
|---|---|---|
| US-01 | Sebagai pengguna, saya ingin mendaftar dan login agar dapat menyimpan rencana perjalanan. | Wajib |
| US-02 | Sebagai pengguna, saya ingin login dengan biometrik agar lebih mudah masuk kembali. | Wajib |
| US-03 | Sebagai wisatawan, saya ingin mencari dan memfilter destinasi agar mudah menemukan tempat yang sesuai. | Wajib |
| US-04 | Sebagai wisatawan, saya ingin melihat detail destinasi agar dapat mempertimbangkan tempat yang akan dikunjungi. | Wajib |
| US-05 | Sebagai wisatawan, saya ingin menyusun itinerary agar perjalanan lebih terencana. | Wajib |
| US-06 | Sebagai wisatawan, saya ingin menghitung estimasi biaya agar dapat menyesuaikan perjalanan dengan anggaran. | Wajib |
| US-07 | Sebagai wisatawan, saya ingin melihat lokasi dan rute agar dapat menemukan destinasi. | Wajib |
| US-08 | Sebagai pengguna, saya ingin menyimpan data wisata secara offline agar tetap dapat membukanya tanpa internet. | Wajib |
| US-09 | Sebagai pengguna, saya ingin meminta rekomendasi AI agar mendapatkan itinerary sesuai kebutuhan. | Wajib |
| US-10 | Sebagai pengguna, saya ingin mengonversi mata uang dan waktu agar mudah membandingkan biaya serta jadwal. | Wajib |
| US-11 | Sebagai pengguna, saya ingin menggunakan sensor smartphone untuk berinteraksi dengan aplikasi. | Wajib |
| US-12 | Sebagai pengguna, saya ingin menerima pengingat perjalanan agar tidak melewatkan jadwal. | Wajib |
| US-13 | Sebagai pengguna, saya ingin bermain kuis wisata agar dapat menguji pengetahuan tentang Merapi. | Wajib |
| US-14 | Sebagai pengguna, saya ingin melihat paket Jeep sebagai pilihan tambahan perjalanan. | Pendukung |
| US-15 | Sebagai pengguna, saya ingin melihat profil dan riwayat perjalanan agar dapat mengelola aktivitas saya. | Wajib |
| US-16 | Sebagai pengguna, saya ingin mengirim saran dan kesan agar dapat memberikan masukan terhadap aplikasi dan mata kuliah. | Wajib |

---

## 5. Daftar Fitur MVP, V2, dan Nanti

### 5.1 MVP

MVP adalah versi pertama yang harus dapat digunakan dan didemonstrasikan. Seluruh kriteria wajib dosen tetap menjadi target penyelesaian MVP.

**A. Fitur inti wisata**
- Home dan rekomendasi destinasi.
- Pencarian dan filter destinasi.
- Detail destinasi, foto, lokasi, dan informasi biaya.
- Trip planner untuk memilih dan menyusun urutan kunjungan.
- Estimasi budget berdasarkan harga dan biaya yang tersedia.
- Peta dan LBS.
- Penyimpanan data wisata offline.
- AI travel assistant.
- Paket Jeep sebagai informasi dan pilihan tambahan.

**B. Akun dan penyimpanan**
- Registrasi dan login.
- Password tersimpan dalam bentuk hash di backend.
- Session atau token autentikasi.
- Login biometrik.
- Database online dan penyimpanan lokal.
- Profil, foto profil, favorit, dan riwayat perjalanan.
- Saran dan kesan mata kuliah.
- Logout.

**C. Fitur pendukung wajib**
- Konversi minimal tiga mata uang, yaitu IDR, USD, dan EUR. JPY dapat ditambahkan.
- Konversi waktu WIB, WITA, WIT, dan London.
- Minimal dua sensor, yaitu accelerometer dan gyroscope.
- Notifikasi perjalanan.
- Mini game bertema wisata Merapi.
- Blockchain sederhana untuk pencatatan riwayat itinerary atau booking.
- Pencarian dan pemilihan data.
- Web Service/API.

**D. Navigasi**
Bottom navigation berisi:
- Home.
- Explore.
- My Trip.
- Profile.

### 5.2 V2

Pengembangan berikutnya setelah seluruh kebutuhan MVP terpenuhi.

- Rekomendasi itinerary yang mempertimbangkan jarak dan jam operasional.
- Filter destinasi berdasarkan preferensi pengguna yang lebih lengkap.
- Sinkronisasi itinerary lintas perangkat.
- Mode eksplorasi peta dengan orientasi sensor yang lebih interaktif.
- Peningkatan kualitas rekomendasi AI.
- Fitur ulasan dan penilaian destinasi.
- Pengembangan booking Jeep yang lebih lengkap jika dibutuhkan.

### 5.3 Nanti

Fitur jangka panjang yang belum menjadi komitmen pengembangan.

- Integrasi sistem pembayaran online.
- Kerja sama langsung dengan operator wisata.
- Rekomendasi berdasarkan kondisi cuaca terkini.
- Pengelolaan perjalanan kelompok.
- Integrasi data pengunjung dan pengelola destinasi.
- Dukungan navigasi dan peta offline yang lebih lengkap.

---

## 6. Functional Requirements MVP

### FR-01. Registrasi dan Login

**Deskripsi:** Pengguna dapat membuat akun dan mengakses aplikasi.

**Kebutuhan fungsional:**
1. Sistem menyediakan formulir registrasi dan login.
2. Sistem memvalidasi input pengguna.
3. Backend menyimpan password dalam bentuk hash menggunakan algoritma yang sesuai, bukan teks biasa.
4. Sistem membuat session atau token autentikasi setelah login berhasil.
5. Sistem menolak login dengan kredensial yang tidak valid.
6. Sistem menyediakan logout dan menghapus kredensial sesi lokal.
7. Sistem tidak menggunakan Firebase sebagai pengganti mekanisme autentikasi yang diwajibkan.

**Kriteria penerimaan:** Pengguna dapat registrasi, login, mempertahankan sesi sesuai mekanisme autentikasi, dan logout dengan benar.

### FR-02. Login Biometrik

**Deskripsi:** Pengguna dapat menggunakan autentikasi biometrik perangkat.

**Kebutuhan fungsional:**
1. Pengguna mengaktifkan biometrik setelah autentikasi awal.
2. Aplikasi menggunakan mekanisme biometrik sistem operasi.
3. Aplikasi hanya mengizinkan akses setelah autentikasi berhasil.
4. Aplikasi menyediakan metode login alternatif.
5. Aplikasi menangani perangkat yang tidak mendukung biometrik.

**Kriteria penerimaan:** Login biometrik berfungsi pada perangkat yang mendukung dan gagal secara aman ketika autentikasi ditolak.

### FR-03. Explore Destinasi

**Deskripsi:** Pengguna dapat menemukan informasi wisata Merapi.

**Kebutuhan fungsional:**
1. Sistem menampilkan daftar destinasi.
2. Pengguna dapat mencari berdasarkan nama destinasi.
3. Pengguna dapat memfilter destinasi berdasarkan kategori.
4. Pengguna dapat melihat detail destinasi.
5. Detail mencakup nama, deskripsi, foto, koordinat, kategori, dan informasi biaya jika tersedia.
6. Pengguna dapat menyimpan destinasi ke favorit.
7. Pengguna dapat memilih destinasi untuk dimasukkan ke itinerary.

**Kriteria penerimaan:** Pengguna dapat mencari, memfilter, membuka detail, dan memilih destinasi.

### FR-04. Trip Planner

**Deskripsi:** Pengguna dapat menyusun perjalanan wisata.

**Kebutuhan fungsional:**
1. Pengguna membuat itinerary baru.
2. Pengguna menentukan nama trip dan tanggal perjalanan.
3. Pengguna memilih satu atau lebih destinasi.
4. Pengguna mengatur urutan kunjungan.
5. Sistem menyimpan urutan dan waktu kunjungan jika diisi.
6. Pengguna dapat mengubah atau menghapus destinasi dari itinerary.
7. Pengguna dapat menyimpan dan membuka kembali itinerary.
8. Sistem menampilkan ringkasan destinasi dan estimasi biaya.

**Kriteria penerimaan:** Itinerary dapat dibuat, diedit, disimpan, dan dibuka kembali.

### FR-05. Estimasi Budget

**Deskripsi:** Sistem membantu pengguna memperkirakan biaya perjalanan.

**Kebutuhan fungsional:**
1. Sistem mengambil informasi harga dari data destinasi atau input pengguna.
2. Pengguna dapat menambahkan estimasi biaya transportasi, tiket, dan biaya lain.
3. Sistem menghitung total berdasarkan biaya yang dimasukkan.
4. Sistem menampilkan rincian dan total estimasi.
5. Sistem membedakan harga yang diketahui dengan biaya yang belum tersedia.

**Kriteria penerimaan:** Total estimasi sesuai dengan penjumlahan seluruh komponen biaya. Sistem tidak menampilkan harga perkiraan sebagai harga resmi.

### FR-06. Peta dan LBS

**Deskripsi:** Pengguna dapat melihat lokasi dirinya dan destinasi wisata.

**Kebutuhan fungsional:**
1. Sistem meminta izin lokasi ketika fitur peta digunakan.
2. Sistem menampilkan posisi pengguna saat izin diberikan.
3. Sistem menampilkan marker destinasi.
4. Pengguna dapat memilih destinasi dari peta.
5. Sistem dapat menghitung jarak berdasarkan koordinat.
6. Sistem dapat membuka petunjuk rute melalui layanan peta yang tersedia.
7. Aplikasi tetap menampilkan informasi koordinat yang telah disimpan saat offline.

**Kriteria penerimaan:** Marker dan posisi pengguna tampil ketika lokasi tersedia. Sistem memberikan pesan yang sesuai ketika izin lokasi ditolak atau lokasi tidak dapat diperoleh.

### FR-07. Penyimpanan Offline dan Online

**Deskripsi:** Data wisata yang telah disimpan tetap dapat diakses tanpa internet.

**Kebutuhan fungsional:**
1. Data destinasi diambil dari backend melalui API ketika online.
2. Pengguna dapat menyimpan atau mengunduh data destinasi ke penyimpanan lokal.
3. Aplikasi menyimpan informasi inti destinasi, koordinat, dan data itinerary.
4. Aplikasi dapat membaca data lokal ketika offline.
5. Sistem menyimpan perubahan itinerary lokal ketika internet tidak tersedia.
6. Sistem melakukan sinkronisasi ketika koneksi tersedia kembali.
7. Sistem menangani konflik sinkronisasi tanpa menghapus data secara diam-diam.

**Kriteria penerimaan:** Destinasi yang sudah disimpan tetap dapat dibuka dalam mode pesawat. Fitur online yang tidak tersedia harus menunjukkan status offline.

**Batasan:** Akses offline terhadap informasi wisata tidak otomatis berarti peta online, routing, kurs terbaru, atau AI tetap tersedia.

### FR-08. AI Travel Assistant

**Deskripsi:** AI membantu pengguna menyusun rencana perjalanan.

**Kebutuhan fungsional:**
1. Pengguna memasukkan durasi, budget, dan preferensi perjalanan.
2. Sistem mengirim permintaan ke layanan LLM melalui backend.
3. AI memberikan rekomendasi destinasi berdasarkan data wisata yang tersedia.
4. AI dapat menyusun contoh itinerary.
5. Pengguna dapat menambahkan destinasi rekomendasi ke itinerary.
6. Sistem menangani kegagalan layanan AI.
7. Sistem tidak menyatakan data harga, jam buka, atau kondisi destinasi sebagai fakta jika datanya belum tersedia.

**Kriteria penerimaan:** AI menghasilkan rekomendasi yang dapat ditinjau pengguna. Pengguna tetap memegang keputusan akhir itinerary.

**Batasan:** Fitur AI memerlukan koneksi internet kecuali tersedia model lokal yang memang disiapkan.

### FR-09. Konversi Mata Uang

**Deskripsi:** Pengguna dapat mengonversi estimasi biaya wisata.

**Kebutuhan fungsional:**
1. Sistem menyediakan IDR, USD, dan EUR.
2. Pengguna memasukkan nilai yang akan dikonversi.
3. Sistem menampilkan nilai hasil konversi.
4. Sistem menggunakan nilai kurs dari sumber yang ditentukan.
5. Sistem menampilkan tanggal atau waktu pembaruan kurs.
6. Sistem membedakan kurs terbaru dengan kurs cache ketika offline.

**Kriteria penerimaan:** Hasil perhitungan sesuai dengan kurs yang digunakan. Sistem tidak mengklaim kurs offline sebagai kurs real-time.

### FR-10. Konversi Waktu

**Deskripsi:** Pengguna dapat melihat waktu di zona waktu yang diwajibkan.

**Kebutuhan fungsional:**
1. Sistem menyediakan WIB, WITA, WIT, dan London.
2. Pengguna dapat memilih waktu awal dan zona waktu.
3. Sistem menampilkan waktu yang setara pada zona waktu tujuan.
4. Sistem menggunakan aturan zona waktu yang sesuai, termasuk perubahan waktu London jika berlaku.

**Kriteria penerimaan:** Hasil konversi sesuai dengan aturan zona waktu pada tanggal yang dipilih.

### FR-11. Integrasi Sensor

**Deskripsi:** Sensor digunakan untuk interaksi wisata yang relevan.

**Kebutuhan fungsional:**

Accelerometer:
1. Sistem mendeteksi gerakan shake sesuai ambang yang ditentukan.
2. Shake dapat memunculkan rekomendasi destinasi acak.
3. Pengguna dapat menonaktifkan interaksi shake.

Gyroscope:
1. Sistem membaca perubahan orientasi perangkat.
2. Orientasi dapat digunakan pada mode eksplorasi peta atau kompas.
3. Sistem menangani perangkat yang tidak memiliki sensor yang diperlukan.

**Kriteria penerimaan:** Kedua sensor digunakan pada fungsi aplikasi yang dapat didemonstrasikan dan tidak menghalangi navigasi normal.

### FR-12. Notifikasi

**Deskripsi:** Aplikasi mengingatkan pengguna tentang rencana perjalanan.

**Kebutuhan fungsional:**
1. Pengguna dapat membuat pengingat itinerary.
2. Pengguna dapat menentukan waktu pengingat.
3. Sistem menjadwalkan notifikasi lokal.
4. Pengguna dapat mengubah atau membatalkan pengingat.
5. Sistem menangani izin notifikasi yang ditolak.

**Kriteria penerimaan:** Pengingat muncul sesuai jadwal ketika izin dan kondisi sistem operasi memungkinkan.

### FR-13. Mini Game

**Deskripsi:** Pengguna dapat bermain kuis bertema wisata Merapi.

**Kebutuhan fungsional:**
1. Sistem menampilkan pertanyaan pilihan ganda.
2. Pertanyaan berkaitan dengan destinasi atau pengetahuan wisata Merapi.
3. Sistem memeriksa jawaban.
4. Sistem menghitung skor.
5. Sistem menyimpan skor pada profil atau penyimpanan lokal.

**Kriteria penerimaan:** Pengguna dapat menyelesaikan kuis dan melihat hasil skornya.

### FR-14. Blockchain Sederhana

**Deskripsi:** Sistem menunjukkan konsep integritas data melalui rantai hash.

**Kebutuhan fungsional:**
1. Sistem membuat block untuk catatan itinerary atau booking yang dipilih.
2. Block memuat indeks, waktu, data ringkas, hash block sebelumnya, dan hash saat ini.
3. Sistem menggunakan SHA-256 atau mekanisme hash yang ditentukan.
4. Sistem dapat memvalidasi hubungan antarblock.
5. Sistem menunjukkan hasil validasi ketika data block diubah.

**Kriteria penerimaan:** Rantai hash valid sebelum perubahan dan validasi mendeteksi perubahan data yang memengaruhi hash.

**Batasan:** Implementasi ini merupakan simulasi blockchain sederhana, bukan jaringan blockchain publik.

### FR-15. Paket Jeep

**Deskripsi:** Pengguna dapat melihat pilihan paket Jeep sebagai bagian dari rencana wisata.

**Kebutuhan fungsional:**
1. Sistem menampilkan daftar paket yang tersedia pada data aplikasi.
2. Pengguna dapat melihat informasi paket, harga, durasi, kapasitas, dan penyedia jika tersedia.
3. Pengguna dapat menambahkan paket ke itinerary.
4. Jika booking diimplementasikan, sistem menyimpan tanggal, jumlah orang, paket, dan status booking.
5. Sistem menampilkan informasi bahwa konfirmasi akhir bergantung pada penyedia jika ketersediaan belum terintegrasi.

**Kriteria penerimaan:** Paket dapat dilihat dan dipilih. Sistem tidak menyatakan booking terkonfirmasi sebelum proses konfirmasi benar-benar berhasil.

### FR-16. Profil, Saran, Kesan, dan Logout

**Deskripsi:** Pengguna dapat mengelola informasi akun dan menyampaikan masukan.

**Kebutuhan fungsional:**
1. Profil menampilkan foto dan informasi dasar pengguna.
2. Sistem menampilkan riwayat itinerary dan skor game.
3. Pengguna dapat mengirim saran dan kesan mata kuliah Pemrograman Aplikasi Mobile.
4. Sistem menyimpan masukan sesuai mekanisme yang ditentukan.
5. Pengguna dapat logout.
6. Sistem menyediakan menu profil dan logout yang mudah ditemukan.

**Kriteria penerimaan:** Profil dapat dibuka, masukan dapat dikirim, dan logout mengakhiri sesi aktif.

---

## 7. Sketsa Data Model

Data dibagi menjadi penyimpanan online dan lokal.

Penyimpanan online menggunakan MySQL melalui backend API. Penyimpanan lokal menggunakan SQLite atau Hive. Pilihan final penyimpanan lokal perlu ditetapkan sebelum implementasi.

### 7.1 Entitas Utama

**1. users**
- id, primary key.
- name.
- email, unique.
- password_hash.
- profile_photo.
- created_at.
- updated_at.

**2. destinations**
- id, primary key.
- name.
- description.
- category_id, foreign key.
- latitude.
- longitude.
- ticket_price, nullable.
- opening_hours, nullable.
- address.
- image_url.
- updated_at.

**3. categories**
- id, primary key.
- name.
- description.

**4. trips**
- id, primary key.
- user_id, foreign key.
- trip_name.
- start_date.
- end_date, nullable.
- budget.
- status.
- created_at.
- updated_at.

**5. trip_items**
- id, primary key.
- trip_id, foreign key.
- destination_id, foreign key, nullable jika item berupa aktivitas lain.
- visit_order.
- planned_arrival, nullable.
- estimated_duration, nullable.
- estimated_cost.

**6. favorites**
- id, primary key.
- user_id, foreign key.
- destination_id, foreign key.
- created_at.

**7. jeep_packages**
- id, primary key.
- provider_name.
- package_name.
- description.
- price.
- duration.
- capacity.
- contact_info, nullable.
- updated_at.

**8. bookings**
- id, primary key.
- user_id, foreign key.
- package_id, foreign key.
- trip_id, foreign key, nullable.
- booking_date.
- participant_count.
- total_price.
- status.
- created_at.

**9. reminders**
- id, primary key.
- user_id, foreign key.
- trip_id, foreign key.
- reminder_time.
- title.
- is_enabled.

**10. game_scores**
- id, primary key.
- user_id, foreign key.
- score.
- completed_at.

**11. feedback**
- id, primary key.
- user_id, foreign key.
- feedback_type.
- message.
- created_at.

**12. blockchain_records**
- id, primary key.
- block_index.
- record_type.
- record_reference.
- timestamp.
- previous_hash.
- current_hash.

### 7.2 Relasi Data

- Satu user dapat memiliki banyak trip.
- Satu trip dapat memiliki banyak trip_items.
- Satu destinasi dapat masuk ke banyak trip_items.
- Satu user dapat menyimpan banyak destinasi favorit.
- Satu paket Jeep dapat memiliki banyak booking.
- Satu user dapat memiliki banyak booking dan game_scores.
- Satu trip dapat memiliki beberapa reminder.
- Catatan blockchain merujuk pada catatan itinerary atau booking yang dipilih.

### 7.3 Data Lokal

Penyimpanan lokal mencakup:
- Cache destinasi.
- Cache kategori.
- Koordinat destinasi.
- Itinerary yang sudah disimpan.
- Favorit.
- Pengaturan pengguna.
- Skor game.
- Pengingat lokal.

Password tidak boleh disimpan dalam bentuk teks biasa. Token autentikasi perlu disimpan menggunakan penyimpanan aman perangkat.

### 7.4 Sketsa API

Contoh endpoint yang dapat digunakan:

- `POST /api/register`
- `POST /api/login`
- `POST /api/logout`
- `GET /api/destinations`
- `GET /api/destinations/{id}`
- `GET /api/categories`
- `GET /api/trips`
- `POST /api/trips`
- `PUT /api/trips/{id}`
- `DELETE /api/trips/{id}`
- `GET /api/jeep-packages`
- `POST /api/bookings`
- `POST /api/ai/itinerary`
- `POST /api/feedback`

Endpoint di atas merupakan rancangan awal. Implementasi final mengikuti kebutuhan backend dan kontrak API yang ditetapkan.

---

## 8. Edge Cases dan Failure States

| Kondisi | Perilaku yang Diharapkan |
|---|---|
| Login gagal | Tampilkan pesan kesalahan tanpa membocorkan detail sensitif. |
| Email sudah digunakan | Tolak registrasi dan minta pengguna menggunakan email lain. |
| Biometrik tidak tersedia | Sediakan login alternatif. |
| Internet terputus | Buka data destinasi dan itinerary yang sudah tersimpan. |
| Data wisata belum pernah diunduh | Tampilkan pesan bahwa data belum tersedia secara offline. |
| API gagal | Tampilkan data cache jika tersedia dan berikan opsi mencoba kembali. |
| Izin lokasi ditolak | Tampilkan peta tanpa posisi pengguna dan sediakan pengaturan izin. |
| GPS tidak memperoleh lokasi | Tampilkan pesan dan jangan mengarang posisi pengguna. |
| Peta online tidak tersedia | Tampilkan informasi lokal yang tersedia. Jangan mengklaim navigasi online tetap berfungsi. |
| Kurs mata uang gagal diperbarui | Gunakan kurs cache dengan tanggal pembaruan atau tampilkan bahwa kurs tidak tersedia. |
| Layanan AI gagal | Tampilkan pesan dan pertahankan data itinerary yang sudah disusun. |
| Input budget kosong atau negatif | Validasi input sebelum menghitung total. |
| Destinasi tidak memiliki harga | Tandai biaya sebagai belum diketahui. |
| Notifikasi tidak diizinkan | Tampilkan petunjuk mengaktifkan izin. |
| Sensor tidak didukung | Nonaktifkan fungsi terkait dan sediakan alternatif navigasi. |
| Data itinerary berubah saat offline | Simpan perubahan lokal dan sinkronkan ketika online. |
| Sinkronisasi mengalami konflik | Pertahankan data sampai aturan penyelesaian konflik diterapkan. |
| Booking gagal | Tampilkan status gagal dan hindari membuat konfirmasi palsu. |
| Block blockchain berubah | Tandai hasil validasi sebagai tidak valid. |
| Pengguna logout | Hapus sesi lokal dan minta autentikasi kembali untuk data terlindungi. |

---

## 9. Success Metrics

Target berikut merupakan usulan awal untuk pengujian prototype. Target dapat disesuaikan dengan jumlah penguji dan waktu pengembangan.

### 9.1 Functional Success

1. Seluruh kriteria wajib dosen memiliki bukti implementasi dan pengujian.
2. Minimal 95% test case fungsional yang direncanakan berhasil.
3. Pengguna dapat menyelesaikan alur pencarian destinasi hingga penyimpanan itinerary.
4. Pengguna dapat membuka kembali data destinasi yang sudah diunduh dalam mode pesawat.
5. Fitur login, biometrik, database, LBS, API, AI, sensor, notifikasi, mini game, dan blockchain berhasil diuji pada kondisi yang sesuai.

### 9.2 Usability

1. Minimal 8 dari 10 peserta uji dapat membuat itinerary sederhana tanpa bantuan.
2. Pengguna dapat menemukan destinasi menggunakan pencarian dan filter.
3. Pengguna dapat melihat rincian biaya perjalanan.
4. Pengguna dapat menemukan menu profil, saran dan kesan, serta logout.

Jumlah peserta dan metode pengujian harus disesuaikan dengan kondisi proyek.

### 9.3 Offline Reliability

1. Data destinasi yang sudah diunduh dapat dibuka tanpa internet.
2. Itinerary lokal tetap tersedia setelah aplikasi ditutup dan dibuka kembali.
3. Aplikasi memberikan status yang jelas ketika fitur memerlukan koneksi internet.
4. Perubahan lokal tidak hilang secara diam-diam ketika sinkronisasi gagal.

### 9.4 AI Quality

1. AI dapat menghasilkan itinerary berdasarkan input durasi, budget, dan preferensi.
2. Rekomendasi menggunakan destinasi yang tersedia pada data aplikasi.
3. Pengguna dapat meninjau rekomendasi sebelum memasukkannya ke itinerary.
4. Sistem tidak mengklaim harga atau informasi yang belum terverifikasi sebagai fakta.

### 9.5 Evidence dan Pengujian

Setiap fitur wajib memiliki:
- Skenario pengujian.
- Hasil pengujian.
- Screenshot implementasi.
- Penjelasan source code.
- Status berhasil atau gagal.
- Catatan perbaikan jika ditemukan masalah.

Bukti tersebut digunakan dalam laporan akhir dan presentasi mingguan setelah UTS.

---

## 10. Open Questions

Pertanyaan berikut harus diputuskan sebelum atau selama perancangan detail.

1. **Cakupan wilayah:** Apakah MeraTrip mencakup seluruh kawasan wisata Merapi atau dibatasi pada Kaliurang dan destinasi sekitarnya?

2. **Sumber data destinasi:** Sumber mana yang akan digunakan untuk koordinat, harga tiket, jam buka, foto, dan deskripsi destinasi? Siapa yang bertanggung jawab memperbarui data?

3. **Penyedia peta:** Apakah aplikasi menggunakan Google Maps atau OpenStreetMap? Apakah peta offline harus mencakup tile peta atau cukup data destinasi dan koordinat?

4. **Backend:** Apakah backend akan menggunakan Laravel dan MySQL, dengan SQLite atau Hive untuk penyimpanan lokal?

5. **AI/LLM:** Layanan LLM mana yang akan digunakan? Apakah penggunaan API berbayar diperbolehkan untuk proyek ini?

6. **Biometrik:** Apakah autentikasi biometrik cukup menggunakan fasilitas fingerprint atau face authentication bawaan perangkat?

7. **Konversi mata uang:** API kurs mana yang akan digunakan? Apakah aplikasi harus tetap menampilkan kurs terakhir saat offline?

8. **Booking Jeep:** Apakah booking cukup berupa simulasi dan pencatatan lokal/server, atau harus terhubung langsung dengan operator Jeep?

9. **Blockchain:** Apakah dosen mengharuskan transaksi booking dicatat sebagai block, atau pencatatan itinerary juga dapat diterima?

10. **Distribusi aplikasi:** Apakah pengujian cukup menggunakan perangkat Android dan iOS yang tersedia, atau harus menghasilkan build untuk kedua platform?

11. **Anggota dan waktu pengerjaan:** Berapa jumlah anggota kelompok, tenggat akhir, dan pembagian tanggung jawab pengembangan?

### Keputusan yang Disarankan untuk Versi Awal

Sambil menunggu jawaban atas pertanyaan terbuka, rancangan awal dapat menggunakan asumsi berikut:

- Wilayah awal mencakup Kaliurang dan beberapa destinasi wisata Merapi yang berdekatan.
- Fokus utama adalah pencarian destinasi, itinerary, estimasi budget, dan peta.
- Paket Jeep hanya menjadi fitur pendukung.
- Aplikasi menggunakan Flutter untuk Android dan iOS.
- Backend menggunakan Laravel API dan MySQL jika sesuai dengan kemampuan serta waktu kelompok.
- Data destinasi dan itinerary disimpan secara lokal agar dapat dibuka offline.
- Fitur AI, kurs terbaru, dan layanan rute online membutuhkan koneksi internet.
- Blockchain menggunakan rantai hash sederhana untuk demonstrasi.
- Seluruh kriteria wajib dosen tetap diselesaikan sebelum project dinyatakan selesai.

### Definisi Selesai

MeraTrip dinyatakan selesai apabila seluruh kriteria wajib dosen telah diimplementasikan, fitur inti dapat digunakan dari pencarian destinasi hingga penyimpanan itinerary, data wisata yang diunduh dapat dibuka offline, seluruh pengujian terdokumentasi, dan laporan akhir beserta penjelasan source code siap dikumpulkan.