/**
 * MAMPIR Web - Nearby Controller (Fitur Near Me ala Gojek)
 * Mengintegrasikan:
 * 1. Geolocation API browser untuk deteksi GPS real-time & marker khusus pengguna
 * 2. Filter jarak 5 level: 0–1 km, 1–3 km, 3–5 km, 5–10 km, >10 km
 * 3. Pencarian tempat makan & nongkrong via Google Places API (New) places:searchNearby
 * 4. Tampilan peta Leaflet interaktif (sinkron dengan radius & auto-fit bounds)
 * 5. Card tempat Gojek-style (jarak real m/km, foto, rating, jam buka, tombol detail & petunjuk arah)
 * 6. Pengurutan terdekat & rating tertinggi
 * 7. Fallback cerdas ke Supabase database jika Google API gagal / di luar jangkauan
 */

window.NearbyController = {
  isActive: false,
  userCoords: null, // { latitude, longitude, accuracy, isSimulated }
  selectedRadius: '3–5 km',
  selectedCategory: 'Semua',
  searchKeyword: '',
  sortBy: 'nearest', // 'nearest' | 'rating'
  places: [],
  isLoading: false,
  errorMessage: null,
  userMarker: null,
  radiusCircle: null,

  radiusOptions: [
    { label: '0–1 km', minKm: 0, maxKm: 1, queryMeters: 1000 },
    { label: '1–3 km', minKm: 1, maxKm: 3, queryMeters: 3000 },
    { label: '3–5 km', minKm: 3, maxKm: 5, queryMeters: 5000 },
    { label: '5–10 km', minKm: 5, maxKm: 10, queryMeters: 10000 },
    { label: '>10 km', minKm: 10, maxKm: 50, queryMeters: 50000 }
  ],

  categoryOptions: [
    { label: 'Semua', types: ['restaurant', 'cafe', 'coffee_shop', 'fast_food_restaurant', 'meal_takeaway', 'bakery'], icon: '🍽️' },
    { label: 'Resto', types: ['restaurant'], icon: '🍲' },
    { label: 'Warung Makan/Warkop', types: ['restaurant', 'meal_takeaway'], icon: '🍛' },
    { label: 'Cafe', types: ['cafe', 'coffee_shop'], icon: '☕' },
    { label: 'Bakery', types: ['bakery'], icon: '🥐' }
  ],

  categoryPlaceholders: {
    'Restoran': 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=800&q=80',
    'Warung Makan': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=800&q=80',
    'Cafe': 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=800&q=80',
    'Coffee Shop': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80',
    'Tempat Nongkrong': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=800&q=80',
    'Fast Food': 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?auto=format&fit=crop&w=800&q=80'
  },

  /**
   * Mengaktifkan Mode Near Me
   */
  async activate() {
    this.isActive = true;
    this.errorMessage = null;

    // Tandai sidebar jika ada tombol khusus
    document.querySelectorAll('.sidebar-nav .nav-item').forEach(el => {
      el.classList.toggle('active', el.getAttribute('data-view') === 'nearby');
    });

    // Sinkronkan tombol header "Lokasi Terdekat" jika ada
    const topBtn = document.getElementById('btn-top-nearby');
    if (topBtn) {
      topBtn.classList.add('active');
      topBtn.style.background = 'linear-gradient(135deg, var(--accent-orange), var(--accent-gold))';
      topBtn.style.color = '#fff';
    }

    // Scroll kolom katalog ke atas agar pengguna langsung melihat tampilan Nearby
    const catalogCol = document.getElementById('catalog-content-area') || document.getElementById('catalog-content-col');
    if (catalogCol) {
      catalogCol.scrollTop = 0;
    }

    // SELALU minta lokasi GPS jika belum pernah terdeteksi koordinat nyata
    if (!this.userCoords || this.userCoords.isSimulated) {
      await this.requestLocation(false);
    } else {
      await this.fetchPlaces();
    }
  },

  /**
   * Menonaktifkan Mode Near Me dan kembali ke katalog standar
   */
  deactivate() {
    this.isActive = false;
    this.clearMapDecorations();
    const topBtn = document.getElementById('btn-top-nearby');
    if (topBtn) {
      topBtn.classList.remove('active');
      topBtn.style.background = '';
      topBtn.style.color = '';
    }
    if (window.App) {
      window.App.switchView('beranda');
    }
  },

  /**
   * Meminta lokasi GPS pengguna secara real-time via Geolocation API browser
   * Menggunakan fallback cerdas: GPS Akurasi Tinggi -> Jaringan/WiFi Triangulation
   */
  async requestLocation(forceRefresh = false) {
    if (!navigator.geolocation) {
      this.errorMessage = 'Peramban Anda tidak mendukung Geolocation API. Silakan gunakan titik lokasi acuan di bawah.';
      this.render();
      return;
    }

    this.isLoading = true;
    this.errorMessage = null;
    this.render();

    const getPositionPromise = (options) => {
      return new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, options);
      });
    };

    let pos = null;
    try {
      // Step 1: Coba GPS akurasi tinggi (hardware GPS) dengan timeout 6 detik
      pos = await getPositionPromise({
        enableHighAccuracy: true,
        timeout: 6000,
        maximumAge: forceRefresh ? 0 : 30000
      });
    } catch (errHigh) {
      console.warn('GPS akurasi tinggi gagal atau timeout, mencoba mode jaringan WiFi/seluler...', errHigh);
      try {
        // Step 2: Coba mode standar (WiFi / Cell tower triangulation) yang sangat cepat dan kompatibel di Android/laptop/tablet
        pos = await getPositionPromise({
          enableHighAccuracy: false,
          timeout: 10000,
          maximumAge: forceRefresh ? 0 : 60000
        });
      } catch (errLow) {
        console.warn('Geolocation browser gagal:', errLow);
        if (errLow.code === 1) { // PERMISSION_DENIED
          this.errorMessage = 'Izin lokasi belum diberikan di peramban. Silakan klik ikon gembok/setelan di sebelah URL address bar untuk mengizinkan lokasi, lalu klik "Perbarui Lokasi".';
        } else if (errLow.code === 2) { // POSITION_UNAVAILABLE
          this.errorMessage = 'Sinyal lokasi / GPS perangkat tidak tersedia. Pastikan fitur Lokasi di perangkat Anda telah diaktifkan.';
        } else if (errLow.code === 3) { // TIMEOUT
          this.errorMessage = 'Waktu pencarian lokasi habis. Silakan klik "Perbarui Lokasi" untuk mencoba kembali.';
        } else {
          this.errorMessage = 'Gagal mendeteksi lokasi: ' + (errLow.message || 'Kesalahan koneksi.');
        }
      }
    }

    if (pos && pos.coords) {
      this.userCoords = {
        latitude: pos.coords.latitude,
        longitude: pos.coords.longitude,
        accuracy: pos.coords.accuracy || 15,
        isSimulated: false,
        label: 'Lokasi Anda (GPS Aktif)',
        timestamp: new Date()
      };
      this.errorMessage = null;

      // Ambil nama wilayah/daerah pengguna secara real-time via reverse geocode
      this.reverseGeocodeUserCoords(pos.coords.latitude, pos.coords.longitude);
    } else {
      // Jika belum punya koordinat sama sekali, beri titik acuan tapi tandai sebagai simulasi
      if (!this.userCoords) {
        this.userCoords = {
          latitude: -7.4243,
          longitude: 109.2303,
          accuracy: 50,
          isSimulated: true,
          label: 'Alun-Alun Purwokerto (Titik Acuan)',
          timestamp: new Date()
        };
      }
    }

    this.isLoading = false;
    await this.fetchPlaces();
  },

  /**
   * Reverse geocoding real-time untuk mendapatkan nama tempat pengguna
   */
  async reverseGeocodeUserCoords(lat, lng) {
    try {
      const resp = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lng}&zoom=14&addressdetails=1`, {
        headers: { 'Accept-Language': 'id' }
      });
      if (resp.ok) {
        const data = await resp.json();
        if (data && data.address) {
          const addr = data.address;
          const name = addr.suburb || addr.neighbourhood || addr.village || addr.city_district || addr.city || addr.town || addr.county || 'Lokasi Anda';
          const city = addr.city || addr.town || addr.county || '';
          this.userCoords.label = city ? `${name}, ${city}` : name;
          // Perbarui teks status di UI tanpa perlu refetch places
          const coordsLabelEl = document.querySelector('.gps-coords');
          if (coordsLabelEl) {
            coordsLabelEl.textContent = this.userCoords.label;
          }
          if (MapController) {
            MapController.updateUserMarker(lat, lng, this.userCoords.label);
          }
        }
      }
    } catch (e) {
      console.log('Reverse geocoding info:', e);
    }
  },

  /**
   * Simulasi lokasi GPS untuk pengujian di desktop tanpa sensor hardware GPS
   */
  async simulateLocation(presetName) {
    const presets = {
      'alun_alun': { latitude: -7.4243, longitude: 109.2303, label: 'Alun-Alun Purwokerto' },
      'gor_satria': { latitude: -7.4120, longitude: 109.2510, label: 'GOR Satria Purwokerto' },
      'unsoed': { latitude: -7.4085, longitude: 109.2450, label: 'Kampus Unsoed Purwokerto' },
      'baturraden': { latitude: -7.3150, longitude: 109.2240, label: 'Wana Wisata Baturraden' },
      'sokaraja': { latitude: -7.4612, longitude: 109.2789, label: 'Pusat Kuliner Sokaraja' },
      'alun_alun_sukabumi': { latitude: -6.9217, longitude: 106.9272, label: 'Alun-Alun Sukabumi' }
    };

    const target = presets[presetName] || presets['alun_alun'];
    this.userCoords = {
      latitude: target.latitude,
      longitude: target.longitude,
      accuracy: 15,
      isSimulated: true,
      label: target.label,
      timestamp: new Date()
    };
    this.errorMessage = null;
    await this.fetchPlaces();
  },

  onKeywordSearch(kw) {
    this.searchKeyword = (kw || '').trim();
    this.fetchPlaces();
  },

  clearKeyword() {
    this.searchKeyword = '';
    this.fetchPlaces();
  },

  onRadiusChange(radiusLabel) {
    if (this.selectedRadius === radiusLabel) return;
    this.selectedRadius = radiusLabel;
    this.fetchPlaces();
  },

  onCategoryChange(categoryLabel) {
    if (this.selectedCategory === categoryLabel) return;
    this.selectedCategory = categoryLabel;
    this.fetchPlaces();
  },

  onSortChange(sortBy) {
    if (this.sortBy === sortBy) return;
    this.sortBy = sortBy;
    this.sortPlaces();
    this.render();
  },

  /**
   * Menghitung jarak garis lurus (km) menggunakan formula Haversine
   */
  calculateDistanceKm(lat1, lon1, lat2, lon2) {
    if (!lat1 || !lon1 || !lat2 || !lon2) return 999;
    const R = 6371; // Radius bumi km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return parseFloat((R * c).toFixed(2));
  },

  /**
   * Mengambil tempat terdekat via Google Places API (New) resmi
   * Mendukung:
   * - places:searchText jika ada kata kunci pencarian toko/makanan
   * - places:searchNearby jika mencari berdasarkan radius & kategori
   * dengan kalkulasi jarak koordinat GPS real-time
   */
  async fetchPlaces() {
    if (!this.userCoords) return;

    this.isLoading = true;
    this.errorMessage = null;
    this.render();

    const uLat = this.userCoords.latitude;
    const uLng = this.userCoords.longitude;
    const currentRadiusObj = this.radiusOptions.find(r => r.label === this.selectedRadius) || this.radiusOptions[1];
    const radiusMeters = currentRadiusObj.queryMeters;

    let placesResults = [];
    let dataSource = 'google';

    try {
      const apiKey = AppConfig.googlePlacesApiKey;
      if (apiKey && apiKey.length > 5) {
        // Tentukan query pencarian Google Places secara cerdas (Khusus Cafe & Tempat Nongkrong)
        let queryText = (this.searchKeyword || '').trim();
        const baseCat = 'cafe coffee shop kedai kopi tempat nongkrong';
        let locContext = '';
        if (this.userCoords.label) {
          const parts = this.userCoords.label.split(',');
          locContext = parts[parts.length - 1].trim(); // contoh: "Sukabumi" atau "Purwokerto"
        }
        if (!queryText) {
          queryText = locContext ? `${baseCat} ${locContext}` : baseCat;
        } else {
          queryText = locContext ? `${queryText} cafe ${locContext}` : `${queryText} cafe`;
        }

        // Gunakan places:searchText (sangat stabil dan tidak terbatasi kuota harian ketat searchNearby)
        const body = {
          textQuery: queryText,
          locationBias: {
            circle: {
              center: { latitude: uLat, longitude: uLng },
              radius: radiusMeters
            }
          },
          languageCode: 'id',
          maxResultCount: 20
        };

        const response = await fetch('https://places.googleapis.com/v1/places:searchText', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.priceLevel,places.primaryType,places.types,places.regularOpeningHours.openNow,places.photos'
          },
          body: JSON.stringify(body)
        });

        if (response.ok) {
          const data = await response.json();
          if (data && Array.isArray(data.places) && data.places.length > 0) {
            placesResults = data.places.map(p => this.transformGooglePlace(p, uLat, uLng));
          }
        } else {
          console.warn('Google Places API response not ok:', response.status);
        }
      }
    } catch (e) {
      console.warn('Google Places API fetch error:', e);
    }

    // 2. Fallback jika Google API offline
    if (!placesResults || placesResults.length === 0) {
      dataSource = 'supabase_fallback';
      const allMaster = (window.App && window.App.getMergedPlacesList) ? window.App.getMergedPlacesList() : [];
      placesResults = allMaster.map(p => {
        const dist = this.calculateDistanceKm(uLat, uLng, p.latitude, p.longitude);
        return {
          ...p,
          distance: dist,
          data_source: 'database'
        };
      });
    }

    // 3. Saring: Tempat sesuai rentang jarak
    let filtered = placesResults.filter(p => {
      if (!this.searchKeyword && !this.matchesDistance(p.distance)) return false;
      return true;
    });

    // 4. Jika rentang jarak terlalu sempit menghasilkan 0, tampilkan hasil yang ada
    if (filtered.length === 0 && placesResults.length > 0) {
      filtered = placesResults;
    }

    this.places = filtered;
    this.dataSource = dataSource;
    this.sortPlaces();
    this.isLoading = false;

    // Render katalog & update peta
    this.render();
    this.updateMap();
  },

  matchesDistance(distance) {
    if (typeof distance !== 'number' || !isFinite(distance)) return false;
    if (this.selectedRadius === '0–1 km') return distance <= 1.0;
    if (this.selectedRadius === '1–3 km') return distance <= 3.0;
    if (this.selectedRadius === '3–5 km') return distance <= 5.0;
    if (this.selectedRadius === '5–10 km') return distance <= 10.0;
    if (this.selectedRadius === '>10 km') return distance <= 50.0;
    return true;
  },

  matchesCategory(place, selectedCategory) {
    if (!selectedCategory || selectedCategory === 'Semua') return true;
    const sel = selectedCategory.trim().toLowerCase();
    const cat = (place.category || '').trim().toLowerCase();
    const name = (place.name || '').trim().toLowerCase();

    if (sel.includes('resto')) {
      return cat.includes('resto') || name.includes('resto') || name.includes('rumah makan') || name.includes('kitchen') || name.includes('dapur') || name.includes('rm ') || cat.includes('indonesian');
    }
    if (sel.includes('warung') || sel.includes('warkop')) {
      return cat.includes('warung') || cat.includes('warkop') || name.includes('warung') || name.includes('warkop') || name.includes('warkost') || name.includes('angkringan') || name.includes('warmindo') || name.includes('warteg') || name.includes('soto') || name.includes('bakso') || name.includes('mie') || name.includes('nasi') || name.includes('bubur') || name.includes('dapoer') || name.includes('ayam') || name.includes('sari rasa') || name.includes('sate') || name.includes('bebek') || name.includes('pecel') || cat.includes('meal_takeaway') || cat.includes('food');
    }
    if (sel.includes('cafe')) {
      return cat.includes('cafe') || cat.includes('coffee') || name.includes('cafe') || name.includes('kafe') || name.includes('coffee') || name.includes('kopi') || name.includes('kedai');
    }
    if (sel.includes('bakery')) {
      return cat.includes('bakery') || cat.includes('roti') || name.includes('roti') || name.includes('bakery') || name.includes('kue') || name.includes('cake') || name.includes('pastry');
    }
    return true;
  },

  /**
   * Dekompresi Google Encoded Polyline menjadi array koordinat [latitude, longitude]
   */
  decodePolyline(str, precision) {
    let index = 0,
      lat = 0,
      lng = 0,
      coordinates = [],
      shift = 0,
      result = 0,
      byte = null,
      latitude_change,
      longitude_change,
      factor = Math.pow(10, Number.isInteger(precision) ? precision : 5);

    while (index < str.length) {
      byte = null;
      shift = 0;
      result = 0;

      do {
        byte = str.charCodeAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      latitude_change = ((result & 1) ? ~(result >> 1) : (result >> 1));
      shift = result = 0;

      do {
        byte = str.charCodeAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);

      longitude_change = ((result & 1) ? ~(result >> 1) : (result >> 1));

      lat += latitude_change;
      lng += longitude_change;

      coordinates.push([lat / factor, lng / factor]);
    }

    return coordinates;
  },

  /**
   * Mengambil rute jalan raya resmi (mengikuti kelokan dan jalur jalan, bukan garis lurus)
   * menggunakan Google Routes API dengan fallback cerdas ke OSRM Road Network.
   */
  async fetchRoadRoute(originLat, originLng, destLat, destLng) {
    // 1. Coba Google Routes API resmi
    const routesKey = AppConfig.googleRoutesApiKey || AppConfig.googlePlacesApiKey;
    if (routesKey) {
      try {
        const body = {
          origin: { location: { latLng: { latitude: originLat, longitude: originLng } } },
          destination: { location: { latLng: { latitude: destLat, longitude: destLng } } },
          travelMode: 'DRIVE'
        };
        const resp = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': routesKey,
            'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'
          },
          body: JSON.stringify(body)
        });
        if (resp.ok) {
          const data = await resp.json();
          const route = data.routes && data.routes[0];
          if (route && route.polyline && route.polyline.encodedPolyline) {
            const points = this.decodePolyline(route.polyline.encodedPolyline);
            if (points && points.length > 1) {
              const distMeters = route.distanceMeters || 0;
              const durationSec = parseInt(String(route.duration || '').replace('s', '')) || Math.round((distMeters / 1000) * 180);
              return {
                points,
                distanceMeters: distMeters,
                durationSeconds: durationSec,
                source: 'google'
              };
            }
          }
        }
      } catch (err) {
        console.warn('Google Routes API fetch error, switching to OSRM road routing:', err);
      }
    }

    // 2. Fallback OSRM (Open Source Routing Machine) — Rute jalan turn-by-turn resmi
    try {
      const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${originLng},${originLat};${destLng},${destLat}?overview=full&geometries=geojson`;
      const resp = await fetch(osrmUrl);
      if (resp.ok) {
        const data = await resp.json();
        if (data.routes && data.routes.length > 0) {
          const route = data.routes[0];
          // OSRM GeoJSON mengembalikan [lng, lat], balik menjadi [lat, lng] untuk Leaflet
          const points = route.geometry.coordinates.map(coord => [coord[1], coord[0]]);
          return {
            points,
            distanceMeters: Math.round(route.distance),
            durationSeconds: Math.round(route.duration),
            source: 'osrm'
          };
        }
      }
    } catch (osrmErr) {
      console.warn('OSRM routing fetch error:', osrmErr);
    }

    // 3. Fallback garis langsung jika kedua layanan routing sedang offline
    return {
      points: [[originLat, originLng], [destLat, destLng]],
      distanceMeters: Math.round(this.calculateDistanceKm(originLat, originLng, destLat, destLng) * 1000),
      durationSeconds: Math.round(this.calculateDistanceKm(originLat, originLng, destLat, destLng) * 210),
      source: 'direct'
    };
  },

  /**
   * Menampilkan rute navigasi jalan raya di dalam peta aplikasi (In-App Navigation)
   */
  async showInAppRoute(placeId) {
    const place = this.places.find(p => String(p.id) === String(placeId));
    if (!place || !this.userCoords) return;

    this.activeRoutePlace = place;
    this.isLoadingRoute = true;
    this.render();

    const uLat = this.userCoords.latitude;
    const uLng = this.userCoords.longitude;

    const routeData = await this.fetchRoadRoute(uLat, uLng, place.latitude, place.longitude);
    this.isLoadingRoute = false;
    this.activeRouteData = routeData;

    if (MapController && MapController.map) {
      const map = MapController.map;

      // Hapus rute lama jika ada
      if (this.activeRoutePolyline) {
        map.removeLayer(this.activeRoutePolyline);
        this.activeRoutePolyline = null;
      }

      // Gambar rute jalan raya resmi (mengikuti kelokan jalan turn-by-turn)
      this.activeRoutePolyline = L.polyline(
        routeData.points,
        {
          color: '#FF7A00',
          weight: 6,
          opacity: 0.95,
          lineJoin: 'round',
          lineCap: 'round'
        }
      ).addTo(map);

      map.fitBounds(this.activeRoutePolyline.getBounds(), { padding: [60, 60], maxZoom: 16 });

      const mapElem = document.getElementById('map') || document.querySelector('.map-wrapper') || document.querySelector('.map-section');
      if (mapElem) {
        mapElem.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    } else if (window.App && typeof window.App.openPlaceDetail === 'function') {
      window.App.openPlaceDetail(place.id, { autoScrollToMap: true });
    }

    this.render();
  },

  clearInAppRoute() {
    if (this.activeRoutePolyline && MapController && MapController.map) {
      MapController.map.removeLayer(this.activeRoutePolyline);
      this.activeRoutePolyline = null;
    }
    this.activeRoutePlace = null;
    this.activeRouteData = null;
    this.isLoadingRoute = false;
    this.render();
  },

  /**
   * Mengubah respon Google Place ke format MAMPIR model
   */
  transformGooglePlace(place, userLat, userLng) {
    const lat = place.location?.latitude || userLat;
    const lng = place.location?.longitude || userLng;
    const distance = this.calculateDistanceKm(userLat, userLng, lat, lng);

    // Kategori mapping (Khusus Cafe & Coffee Shop)
    const typesStr = (place.types || []).join(' ').toLowerCase();
    const nameLower = (place.displayName?.text || '').toLowerCase();
    let cat = 'Cafe';
    if (typesStr.includes('coffee') || nameLower.includes('kopi') || typesStr.includes('coffee_shop')) {
      cat = 'Coffee Shop';
    } else {
      cat = 'Cafe';
    }

    // Foto
    let img = this.categoryPlaceholders[cat] || this.categoryPlaceholders['Cafe'] || 'assets/images/beranda_mockup.jpeg';
    if (place.photos && place.photos.length > 0 && AppConfig.googlePlacesApiKey) {
      img = `https://places.googleapis.com/v1/${place.photos[0].name}/media?maxHeightPx=600&maxWidthPx=800&key=${AppConfig.googlePlacesApiKey}`;
    }

    // Estimasi harga default
    let minPrice = 15000;
    let maxPrice = 35000;
    if (place.priceLevel === 'PRICE_LEVEL_INEXPENSIVE') { minPrice = 8000; maxPrice = 20000; }
    else if (place.priceLevel === 'PRICE_LEVEL_MODERATE') { minPrice = 25000; maxPrice = 60000; }
    else if (place.priceLevel === 'PRICE_LEVEL_EXPENSIVE') { minPrice = 60000; maxPrice = 120000; }

    let city = 'Purwokerto';
    if (place.formattedAddress) {
      if (place.formattedAddress.includes('Sukabumi')) city = 'Sukabumi';
      else if (place.formattedAddress.includes('Banyumas')) city = 'Banyumas';
      else if (place.formattedAddress.includes('Purwokerto')) city = 'Purwokerto';
    }

    return {
      id: place.id || 'gplace_' + Math.random().toString(36).substring(2, 9),
      name: place.displayName?.text || 'Cafe Purwokerto',
      city: city,
      category: cat,
      address: place.formattedAddress || `${city}, Jawa Barat`,
      latitude: lat,
      longitude: lng,
      rating: place.rating || 4.5,
      review_count: place.userRatingCount || 100,
      min_price: minPrice,
      max_price: maxPrice,
      image_url: img,
      open_now: place.regularOpeningHours?.openNow ?? true,
      distance: distance,
      data_source: 'google_places_api'
    };
  },

  sortPlaces() {
    if (this.sortBy === 'rating') {
      this.places.sort((a, b) => {
        const diff = (b.rating || 0) - (a.rating || 0);
        return diff !== 0 ? diff : (a.distance || 0) - (b.distance || 0);
      });
    } else {
      // Default: nearest
      this.places.sort((a, b) => (a.distance || 0) - (b.distance || 0));
    }
  },

  /**
   * Sinkronkan peta Leaflet dengan posisi pengguna & marker tempat
   */
  updateMap() {
    if (!MapController || !MapController.map) return;
    const map = MapController.map;

    // Bersihkan marker lama
    this.clearMapDecorations();

    if (!this.userCoords) return;

    const uLat = this.userCoords.latitude;
    const uLng = this.userCoords.longitude;
    const locLabel = this.userCoords.label || (this.userCoords.isSimulated ? 'Simulasi Lokasi' : 'Lokasi Anda');

    // 1. Tambah Marker Pengguna (Denyut Biru Berkedip Khas GPS dengan Badge Permanen & zIndex Tertinggi)
    const userIcon = L.divIcon({
      className: 'mampir-user-gps-pin',
      html: `
        <div class="user-gps-pulse-ring"></div>
        <div class="user-gps-core-dot">
          <span>📍</span>
        </div>
      `,
      iconSize: [50, 50],
      iconAnchor: [25, 25]
    });

    this.userMarker = L.marker([uLat, uLng], { icon: userIcon, zIndexOffset: 10000 }).addTo(map);

    this.userMarker.bindTooltip('📍 ' + (locLabel.length > 20 ? locLabel.substring(0, 20) + '...' : locLabel), {
      permanent: true,
      direction: 'top',
      className: 'user-gps-permanent-badge',
      offset: [0, -18]
    });

    this.userMarker.bindPopup(`
      <div style="font-family: var(--font-family); padding: 4px; font-size: 13px;">
        <strong style="color: #2563EB;">📍 ${locLabel}</strong><br>
        <span style="font-size: 11px; color: var(--text-secondary);">${this.userCoords.isSimulated ? '(Titik Acuan)' : '(GPS Akurat)'}</span><br>
        <small style="color: var(--text-muted); font-size: 10px;">${uLat.toFixed(5)}, ${uLng.toFixed(5)}</small>
      </div>
    `);

    // 2. Tambah Lingkaran Radius Transparan
    const currentRadiusObj = this.radiusOptions.find(r => r.label === this.selectedRadius) || this.radiusOptions[2];
    const circleRadiusMeters = Math.min(currentRadiusObj.queryMeters, 15000);
    this.radiusCircle = L.circle([uLat, uLng], {
      color: '#2563EB',
      fillColor: '#3B82F6',
      fillOpacity: 0.10,
      weight: 2,
      dashArray: '5, 6'
    }).addTo(map);

    // 3. Render Marker Tempat-Tempat Terdekat
    MapController.renderMarkers(this.places, (selected) => {
      this.highlightCard(selected.id);
    });

    // 4. Langsung fokus ke titik lokasi pengguna dengan animasi flyTo
    map.flyTo([uLat, uLng], 15.5, { duration: 1.0 });
  },

  clearMapDecorations() {
    if (!MapController || !MapController.map) return;
    const map = MapController.map;
    if (this.userMarker) {
      map.removeLayer(this.userMarker);
      this.userMarker = null;
    }
    if (this.radiusCircle) {
      map.removeLayer(this.radiusCircle);
      this.radiusCircle = null;
    }
  },

  highlightCard(placeId) {
    const cardEl = document.getElementById(`nearby-card-${placeId}`);
    if (cardEl) {
      cardEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
      cardEl.classList.add('nearby-card-highlight');
      setTimeout(() => cardEl.classList.remove('nearby-card-highlight'), 2000);
    }
  },

  /**
   * Format jarak ramah pengguna (meter jika < 1 km, km jika >= 1 km)
   */
  formatDistance(distanceKm) {
    if (typeof distanceKm !== 'number') return '';
    if (distanceKm < 1.0) {
      const meters = Math.round(distanceKm * 1000);
      return `${meters} m`;
    }
    return `${distanceKm.toFixed(1)} km`;
  },

  /**
   * Render Tampilan Fitur Nearby di Kolom Katalog Web
   */
  render() {
    const catalogCol = document.getElementById('catalog-content-area') || document.getElementById('catalog-content-col');
    if (!catalogCol) return;

    // Pastikan tombol sidebar Nearby aktif
    document.querySelectorAll('.sidebar-nav .nav-item').forEach(el => {
      el.classList.toggle('active', el.getAttribute('data-view') === 'nearby');
    });

    let html = `
      <!-- NEARBY HERO BAR -->
      <div class="nearby-hero-panel">
        <div class="nearby-hero-top">
          <div class="nearby-badge-pill">
            <span class="live-dot-pulse"></span>
            <span>FITUR NEARBY GOJEK-STYLE (LIVE GPS)</span>
          </div>
          <button class="btn-pill-exit" onclick="window.NearbyController.deactivate()">
            ✕ Kembali ke Beranda
          </button>
        </div>

        <div class="nearby-hero-title-row">
          <div>
            <h2 class="nearby-hero-title">Cafe & Tempat Nongkrong Terdekat</h2>
            <p class="nearby-hero-sub">Pencarian real-time cafe terdekat dari lokasi Anda via Google Places API</p>
          </div>
          <div class="nearby-gps-status-box">
            ${this.userCoords ? `
              <div class="gps-status-info">
                <span class="gps-icon">${this.userCoords.isSimulated ? '📍' : '🟢'}</span>
                <div>
                  <div class="gps-label">${this.userCoords.isSimulated ? 'Titik Lokasi Acuan:' : 'Lokasi Anda (GPS Aktif):'}</div>
                  <strong class="gps-coords">
                    ${this.userCoords.label || `${this.userCoords.latitude.toFixed(4)}, ${this.userCoords.longitude.toFixed(4)}`}
                  </strong>
                </div>
              </div>
              <button class="btn-refresh-gps" onclick="window.NearbyController.requestLocation(true)" title="Perbarui Lokasi GPS">
                🔄 Perbarui Lokasi
              </button>
            ` : `
              <button class="btn-enable-gps" onclick="window.NearbyController.requestLocation(true)">
                🎯 Deteksi Lokasi Saya (GPS)
              </button>
            `}
          </div>
        </div>

        ${this.errorMessage ? `
          <div class="nearby-error-banner" style="background: rgba(239, 68, 68, 0.12); border: 1px solid rgba(239, 68, 68, 0.35); border-radius: 8px; padding: 10px 14px; margin-top: 12px; display: flex; align-items: center; justify-content: space-between; gap: 12px; font-size: 13px; color: #EF4444;">
            <div style="display: flex; align-items: center; gap: 8px;">
              <span>⚠️</span>
              <span>${this.errorMessage}</span>
            </div>
            <button class="btn-refresh-gps" style="background: #EF4444; color: #fff; border: none; padding: 6px 12px; border-radius: 6px; font-size: 12px; cursor: pointer; white-space: nowrap;" onclick="window.NearbyController.requestLocation(true)">
              🔄 Coba Deteksi Lagi
            </button>
          </div>
        ` : ''}

        <!-- PENCARIAN NAMA TOKO SPESIFIK LANGSUNG DI GOOGLE MAPS -->
        <div class="nearby-search-keyword-row">
          <div class="keyword-input-wrap">
            <span class="kw-icon">🔍</span>
            <input type="text"
                   id="nearby-keyword-input"
                   class="keyword-input"
                   placeholder="Cari cafe & coffee shop langsung di Google Maps (misal: Fore, Titik Temu, Janji Jiwa, Kopi...)"
                   value="${this.searchKeyword || ''}"
                   onkeydown="if(event.key==='Enter') window.NearbyController.onKeywordSearch(this.value)" />
            ${this.searchKeyword ? `
              <button class="btn-kw-clear" onclick="window.NearbyController.clearKeyword()" title="Hapus pencarian">✕</button>
            ` : ''}
          </div>
          <button class="btn-kw-submit" onclick="window.NearbyController.onKeywordSearch(document.getElementById('nearby-keyword-input').value)">
            <span>Cari di Google Maps</span>
          </button>
        </div>

        <!-- SIMULASI PILIHAN LOKASI (UNTUK LAPTOP/DESKTOP TANPA GPS HARDWARE) -->
        <div class="nearby-sim-bar">
          <span class="sim-label">⚡ Uji Cepat Titik Lokasi:</span>
          <button class="btn-sim-chip ${this.userCoords?.label === 'Alun-Alun Sukabumi' ? 'active' : ''}" onclick="window.NearbyController.simulateLocation('alun_alun_sukabumi')">📍 Sukabumi</button>
          <button class="btn-sim-chip ${this.userCoords?.label === 'Alun-Alun Purwokerto' ? 'active' : ''}" onclick="window.NearbyController.simulateLocation('alun_alun')">🏛️ Alun-Alun Pwt</button>
          <button class="btn-sim-chip ${this.userCoords?.label === 'GOR Satria Purwokerto' ? 'active' : ''}" onclick="window.NearbyController.simulateLocation('gor_satria')">🏟️ GOR Satria</button>
          <button class="btn-sim-chip ${this.userCoords?.label === 'Kampus Unsoed Purwokerto' ? 'active' : ''}" onclick="window.NearbyController.simulateLocation('unsoed')">🎓 Unsoed</button>
          <button class="btn-sim-chip ${this.userCoords?.label === 'Wana Wisata Baturraden' ? 'active' : ''}" onclick="window.NearbyController.simulateLocation('baturraden')">🌲 Baturraden</button>
          <button class="btn-sim-chip ${this.userCoords?.label === 'Pusat Kuliner Sokaraja' ? 'active' : ''}" onclick="window.NearbyController.simulateLocation('sokaraja')">🥣 Sokaraja</button>
        </div>

        <!-- FILTER RADIUS 5 TINGKAT (REQ 2 CLIENT) -->
        <div class="nearby-filter-group">
          <div class="filter-group-header">
            <span class="filter-group-title">🎯 Radius Jarak:</span>
            <span class="filter-group-hint">Dihitung dari koordinat GPS Anda ke koordinat tempat</span>
          </div>
          <div class="radius-pills-row">
            ${this.radiusOptions.map(r => `
              <button class="radius-pill-btn ${this.selectedRadius === r.label ? 'active' : ''}"
                      onclick="window.NearbyController.onRadiusChange('${r.label}')">
                ${r.label}
              </button>
            `).join('')}
          </div>
        </div>
      </div>

      <!-- STATUS BAR & SORTING (REQ 6 CLIENT) -->
      <div class="nearby-results-header">
        <div class="results-count-badge">
          <span>Ditemukan <strong>${this.places.length}</strong> cafe & coffee shop ${this.searchKeyword ? `untuk kata kunci "<strong>${this.searchKeyword}</strong>"` : `dalam radius <strong>${this.selectedRadius}</strong>`}</span>
          <span class="badge-source-google">🌐 100% Google Maps API Live</span>
        </div>

        <div class="nearby-sort-box">
          <label for="nearby-sort-select">Urutkan:</label>
          <select id="nearby-sort-select" onchange="window.NearbyController.onSortChange(this.value)">
            <option value="nearest" ${this.sortBy === 'nearest' ? 'selected' : ''}>🛵 Terdekat dari Lokasi</option>
            <option value="rating" ${this.sortBy === 'rating' ? 'selected' : ''}>⭐ Rating Tertinggi</option>
          </select>
        </div>
      </div>
    `;

    // IN-APP NAVIGATION ACTIVE BANNER
    if (this.activeRoutePlace) {
      const rp = this.activeRoutePlace;
      const rd = this.activeRouteData;
      let distText = `${rp.distance.toFixed(1)} km`;
      let estMin = Math.round((rp.distance || 1) * 3.5 + 2);
      if (rd && rd.distanceMeters) {
        distText = rd.distanceMeters < 1000 ? `${rd.distanceMeters} m` : `${(rd.distanceMeters / 1000).toFixed(1)} km`;
      }
      if (rd && rd.durationSeconds) {
        estMin = Math.max(1, Math.ceil(rd.durationSeconds / 60));
      }
      const isRoad = rd && rd.source !== 'direct';

      html += `
        <div class="nearby-inapp-nav-banner">
          <div class="nav-banner-left">
            <span class="nav-banner-icon">🧭</span>
            <div>
              <div class="nav-banner-title">Rute Navigasi: ${rp.name}</div>
              <div class="nav-banner-sub">
                ${this.isLoadingRoute ? '⏳ Sedang menghitung jalur jalan raya resmi...' : `Jarak Tempuh: <strong>${distText}</strong> • Estimasi <strong>${estMin} menit</strong> ${isRoad ? '🛣️ (Mengikuti Jaringan Jalan)' : ''}`}
              </div>
            </div>
          </div>
          <button class="btn-close-route" onclick="window.NearbyController.clearInAppRoute()">✕ Tutup Rute</button>
        </div>
      `;
    }

    // ERROR STATE
    if (this.errorMessage) {
      html += `
        <div class="nearby-error-banner">
          <div class="error-icon">⚠️</div>
          <div class="error-content">
            <h4>Deteksi Lokasi Terkendala</h4>
            <p>${this.errorMessage}</p>
          </div>
          <button class="btn-error-retry" onclick="window.NearbyController.simulateLocation('alun_alun')">
            Gunakan Titik Alun-Alun Purwokerto
          </button>
        </div>
      `;
    }

    // LOADING STATE
    if (this.isLoading) {
      html += `
        <div class="nearby-loading-box">
          <div class="nearby-spinner"></div>
          <h4>Mencari cafe terdekat...</h4>
          <p>Menghitung jarak radius koordinat via Google Places API</p>
        </div>
      `;
    } else if (this.places.length === 0) {
      // EMPTY STATE
      html += `
        <div class="nearby-empty-state">
          <div class="empty-icon">☕</div>
          <h3>Tidak Ada Cafe di Radius ${this.selectedRadius}</h3>
          <p>Coba pilih radius pencarian yang lebih luas (misal: <strong>3–5 km</strong> atau <strong>5–10 km</strong>).</p>
          <div style="display: flex; gap: 10px; justify-content: center; margin-top: 14px;">
            <button class="btn-primary" onclick="window.NearbyController.onRadiusChange('5–10 km')">
              Perluas ke Radius 5–10 km
            </button>
          </div>
        </div>
      `;
    } else {
      // DAFTAR KARTU TEMPAT ALA GOJEK (REQ 5 CLIENT)
      html += `<div class="nearby-cards-container">`;
      this.places.forEach((place, index) => {
        html += this.renderNearbyCard(place, index);
      });
      html += `</div>`;
    }

    catalogCol.innerHTML = html;
  },

  /**
   * Render kartu tempat ala Gojek
   */
  renderNearbyCard(place, index) {
    const formattedDist = this.formatDistance(place.distance);
    const isOpen = place.open_now !== false;
    const isFav = window.StorageService ? window.StorageService.isFavorite(place.id) : false;

    return `
      <div class="nearby-gojek-card" id="nearby-card-${place.id}"
           onmouseenter="window.MapController && window.MapController.highlightMarker('${place.id}')"
           onclick="window.NearbyController.focusPlace('${place.id}', ${place.latitude}, ${place.longitude})">
        
        <div class="nearby-card-media">
          <img src="${place.image_url}" alt="${place.name}" class="nearby-img" loading="lazy" />
          <div class="nearby-category-badge">${place.category || 'Kuliner'}</div>
          ${place.distance <= 1.0 ? `<div class="nearby-badge-walking">🚶 Sangat Dekat</div>` : ''}
          <button class="nearby-fav-btn ${isFav ? 'active' : ''}"
                  onclick="event.stopPropagation(); window.App && window.App.toggleFav('${place.id}')"
                  title="Simpan ke Favorit">
            ${isFav ? '❤️' : '🤍'}
          </button>
        </div>

        <div class="nearby-card-details">
          <div class="nearby-card-top-row">
            <div class="nearby-title-wrap">
              <span class="nearby-rank-num">#${index + 1}</span>
              <h3 class="nearby-card-title">${place.name}</h3>
            </div>
            <div class="nearby-dist-chip">
              <span class="dist-icon">🛵</span>
              <strong>${formattedDist}</strong>
            </div>
          </div>

          <div class="nearby-card-subinfo">
            <span class="nearby-rating-box">
              ⭐ <strong>${place.rating || 4.5}</strong>
              <small class="review-count">(${place.review_count || 120}+ ulasan)</small>
            </span>
            <span class="info-dot">•</span>
            <span class="nearby-price-range">💰 ${RecommendationService.formatPrice ? RecommendationService.formatPrice(place) : 'Mulai Rp 15.000'}</span>
            <span class="info-dot">•</span>
            <span class="nearby-status-badge ${isOpen ? 'status-open' : 'status-closed'}">
              ${isOpen ? '🟢 Buka Sekarang' : '🔴 Tutup'}
            </span>
          </div>

          <p class="nearby-address-text">
            <span>📍</span>
            <span>${place.address || 'Purwokerto, Jawa Tengah'}</span>
          </p>

          <!-- AKSI: LIHAT DETAIL & PETUNJUK ARAH (IN-APP NAVIGATION) -->
          <div class="nearby-card-actions">
            <button class="btn-nearby-detail" onclick="event.stopPropagation(); window.App.openPlaceDetail('${place.id}')">
              <span>📄 Lihat Detail</span>
            </button>
            <button class="btn-nearby-directions" onclick="event.stopPropagation(); window.NearbyController.showInAppRoute('${place.id}')">
              <span>🗺️ Petunjuk Arah</span>
            </button>
          </div>
        </div>

      </div>
    `;
  },

  focusPlace(placeId, lat, lng) {
    if (MapController && MapController.map) {
      MapController.highlightMarker(placeId);
      MapController.panTo(lat, lng, 16);
    } else if (window.App && typeof window.App.openPlaceDetail === 'function') {
      window.App.openPlaceDetail(placeId);
    }
  }
};
