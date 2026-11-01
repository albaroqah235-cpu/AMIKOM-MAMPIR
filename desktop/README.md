# MAMPIR Admin Desktop

Aplikasi Flutter Desktop untuk mengelola katalog MAMPIR di Supabase.

## Menjalankan

```bash
cd desktop
flutter pub get
flutter run -d linux \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Gunakan `-d windows` atau `-d macos` sesuai platform. Jalankan
`supabase_setup.sql` lebih dulu, buat user di Supabase Auth, lalu isi
`public.user_profiles` dengan `role = 'admin'`.

Dashboard membaca data tersinkron dan menyediakan editor field utama tempat.
Operasi sinkronisasi Google yang memakai secret harus dijalankan oleh backend
atau Edge Function, bukan dari aplikasi desktop.
