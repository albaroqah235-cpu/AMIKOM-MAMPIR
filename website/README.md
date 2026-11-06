# MAMPIR Web — Portal Rekomendasi Kuliner Purwokerto & Sekitarnya

Aplikasi berbasis web (*responsive web application*) hasil pengembangan dari **MAMPIR Mobile App** untuk platform peramban desktop dan laptop.

---

## 🌟 Fitur Utama MAMPIR Web

1. **Tata Letak Layar Lebar Terpadu (*Split-Pane Widescreen*):**
   - **Kiri/Tengah:** Katalog rekomendasi tempat kuliner responsif (*Featured Hero Card*, 3 kategori *Cafe, Warkop, Restoran*, dan kartu tempat dengan badge alasan cerdas).
   - **Kanan:** Peta interaktif Leaflet/OpenStreetMap langsung aktif berdampingan dengan katalog. Mengklik kartu kuliner otomatis menggeser fokus peta (*auto-pan*) dan membuka popup pin tempat terkait.
2. **Algoritma Rekomendasi Cerdas (*Hybrid Scoring*):**
   - Kalkulasi skor efisiensi budget (0-35 poin), kemiripan fasilitas & preferensi (0-45 poin), dan popularitas rating (0-20 poin).
   - Menghitung jarak garis lurus (*Haversine Formula*) dari Alun-Alun Purwokerto (`-7.4243, 109.2303`).
3. **Pencarian & Riwayat Pencarian Lokal (*Search History Chips*):**
   - Pencarian instan kata kunci nama tempat, alamat, kategori, atau suasana.
   - Menyimpan riwayat pencarian terakhir di `localStorage` peramban lengkap dengan tombol hapus satuan dan hapus semua.
4. **Penyimpanan Bookmark Favorit (❤️):**
   - Menyimpan tempat favorit langsung ke memori peramban tanpa kewajiban login (*frictionless local storage*).
5. **Koneksi Supabase REST API & Offline Fallback:**
   - Terkoneksi secara *real-time* ke tabel Supabase `places` (`HTTP GET /rest/v1/places`).
   - Jika offline atau tanpa koneksi internet, sistem otomatis beralih ke 25 data tempat autentik Purwokerto & sekitarnya tanpa mengalami crash.
6. **Modal Dialog Detail & Integrasi Google Maps:**
   - Foto resolusi tinggi, fasilitas lengkap, jam buka, dan menu andalan (*signature dishes*) beserta harga Rupiah.
   - Tombol langsung navigasi rute ke Google Maps Web (`maps.google.com`).
7. **Dukungan Tema Dark & Light:**
   - Warna tema konsisten dengan versi mobile: Dark Navy `#0D1326`, Card Navy `#162035`, dan aksen Emas-Oranye `#FFB74D` / `#F57C00`.

---

## 🚀 Cara Menjalankan Versi Website

Aplikasi MAMPIR Web dibuat menggunakan standar modern **HTML5, CSS3, dan Vanilla JavaScript (ES6+)** yang **langsung dapat dijalankan di semua browser** tanpa memerlukan proses kompilasi atau instalasi Node.js.

### Cara 1: Buka Langsung di Browser (Paling Mudah)
1. Buka File Explorer di Windows.
2. Masuk ke folder:
   `c:\SEMESTER 5_CAHAYA\PML_014\PROJEK\UTS\mampir_app\website\`
3. Klik ganda berkas **`index.html`** untuk membukanya di Google Chrome atau Microsoft Edge.

### Cara 2: Menjalankan via Local Web Server (Direkomendasikan untuk Presentasi)
Buka PowerShell atau Command Prompt di folder `website/`, lalu jalankan:

```powershell
# Jalankan web server ringan menggunakan Python
python -m http.server 8080
```
Lalu buka peramban di alamat: **`http://localhost:8080`**

---

## 📂 Struktur Berkas Project Website

```
website/
├── index.html               # Halaman utama aplikasi web MAMPIR (SPA Responsif)
├── css/
│   └── style.css            # Desain tampilan Dark Navy & Gold-Orange, layout split-pane
├── js/
│   ├── config.js            # Konfigurasi endpoint Supabase & Google Maps
│   ├── data.js              # 25 data master tempat kuliner autentik Purwokerto (fallback)
│   ├── storage.js           # Pengelola LocalStorage (favorit, preferensi, riwayat cari)
│   ├── auth.js              # Modul autentikasi Supabase & Mode Tamu
│   ├── recommendation.js    # Algoritma Hybrid Recommendation & kalkulasi jarak Haversine
│   ├── map.js               # Kontroler peta Leaflet (pin oranye, popup, auto-centering)
│   └── app.js               # Kontroler antarmuka utama, render katalog, dan modal
├── assets/
│   └── images/              # Logo aplikasi, mockup, dan gambar pendukung
└── README.md                # Panduan teknis dan instruksi penggunaan
```

