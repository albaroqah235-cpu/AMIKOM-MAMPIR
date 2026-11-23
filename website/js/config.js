/**
 * MAMPIR Web - Runtime Configuration
 * Menyimpan URL API Supabase, Anon Key, Google Maps Key, dan endpoint.
 * PERINGATAN KEAMANAN:
 * File ini dieksekusi di sisi klien (browser). JANGAN PERNAH menambahkan
 * SUPABASE_SERVICE_ROLE_KEY, database secret, atau kredensial privat di file ini.
 * Seluruh akses data klien dikontrol oleh Supabase Row Level Security (RLS) menggunakan Anon Key.
 */
const AppConfig = {
  supabaseUrl: 'https://oztqhofaadjldjrowrgy.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im96dHFob2ZhYWRqbGRqcm93cmd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ5NzM4MzEsImV4cCI6MjExMDU0OTgzMX0.Do3ET862Lik6anMGmazYswh_8hBCX6Iz_80jqWuI4-U',
  googleMapsApiKey: 'AIzaSyDRpM6qUNluR7y-yP-k0UEhSrNQQ84A9nI',
  googlePlacesApiKey: 'AIzaSyDMJEEWy4XuVJSIzvzEVKS6zfwtVjGSYGk',
  googleRoutesApiKey: 'AIzaSyBucKKuasjZSWCt8DfCCTfw6omaV-qlqX8',

  get placesEndpoint() {
    return `${this.supabaseUrl}/rest/v1/places?select=*&order=name.asc`;
  },

  get authEndpoint() {
    return `${this.supabaseUrl}/auth/v1`;
  },

  get headers() {
    return {
      'apikey': this.supabaseAnonKey,
      'Authorization': `Bearer ${this.supabaseAnonKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation'
    };
  },

  // Titik koordinat pusat Alun-Alun Purwokerto
  centerCoordinates: {
    lat: -7.4243,
    lng: 109.2303,
    zoom: 13
  },

  regions: [
    'Semua Wilayah',
    'Purwokerto Kota',
    'Baturraden',
    'Purwokerto Utara (Unsoed)',
    'Sokaraja',
    'Purwokerto Timur & Sumbang',
    'Purwokerto Barat & Selatan'
  ],

  categories: ['Semua', 'Cafe', 'Warkop', 'Restoran']
};

