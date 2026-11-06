/**
 * MAMPIR Web - Leaflet Interactive Map Controller
 * Mengelola peta live, pin marker tempat kuliner, popup kartu pratinjau,
 * dan sinkronisasi auto-pan saat pengguna mengklik kartu di katalog.
 */
const MapController = {
  map: null,
  markers: {},
  activePlaceId: null,

  init(containerId = 'live-map-container') {
    const el = document.getElementById(containerId);
    if (!el) return;

    if (this.map) {
      this.map.remove();
      this.map = null;
      this.markers = {};
    }

    // Default center Alun-Alun Purwokerto
    const center = [AppConfig.centerCoordinates.lat, AppConfig.centerCoordinates.lng];
    this.map = L.map(containerId, {
      center: center,
      zoom: AppConfig.centerCoordinates.zoom,
      zoomControl: true,
      scrollWheelZoom: true
    });

    // Gunakan OpenStreetMap Tile Layer dengan opsi Google Map tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors • MAMPIR Purwokerto',
      maxZoom: 19
    }).addTo(this.map);

    // Inisialisasi custom marker icon
    this.createCustomMarkerIcon();
  },

  createCustomMarkerIcon(isActive = false) {
    const bg = isActive ? '#FFB74D' : '#F57C00';
    const border = isActive ? '#FFFFFF' : '#1A233A';
    const size = isActive ? 38 : 32;

    return L.divIcon({
      className: 'mampir-map-pin',
      html: `
        <div style="
          width: ${size}px;
          height: ${size}px;
          background: ${bg};
          border: 2px solid ${border};
          border-radius: 50% 50% 50% 0;
          transform: rotate(-45deg);
          box-shadow: 0 4px 12px rgba(0,0,0,0.4);
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          transition: all 0.2s ease;
        ">
          <span style="
            transform: rotate(45deg);
            color: #FFFFFF;
            font-size: ${size > 34 ? '16px' : '13px'};
            font-weight: bold;
          ">📍</span>
        </div>
      `,
      iconSize: [size, size],
      iconAnchor: [size / 2, size]
    });
  },

  renderMarkers(places, onSelectPlace) {
    if (!this.map) return;

    // Bersihkan marker lama
    Object.values(this.markers).forEach(m => this.map.removeLayer(m));
    this.markers = {};

    places.forEach(place => {
      if (!place.latitude || !place.longitude) return;

      const marker = L.marker([place.latitude, place.longitude], {
        icon: this.createCustomMarkerIcon(false)
      }).addTo(this.map);

      // Popup Content
      const popupHtml = `
        <div class="map-popup-card">
          <img src="${place.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${place.name}" class="map-popup-img" />
          <div class="map-popup-body">
            <div class="map-popup-header">
              <span class="badge-cat">${place.category || 'Cafe'}</span>
              <span class="badge-rating">⭐ ${place.rating || 4.5}</span>
            </div>
            <h4 class="map-popup-title">${place.name}</h4>
            <p class="map-popup-city">📍 ${place.city || 'Purwokerto'}</p>
            <p class="map-popup-price">${RecommendationService.formatPrice(place)}</p>
            <div class="map-popup-actions">
              <button class="btn-popup-detail" onclick="window.App.openPlaceDetail('${place.id}')">Lihat Detail</button>
              <a href="https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}" target="_blank" class="btn-popup-route">Rute ↗</a>
            </div>
          </div>
        </div>
      `;

      marker.bindPopup(popupHtml, { maxWidth: 280, className: 'mampir-leaflet-popup' });

      marker.on('click', () => {
        this.highlightMarker(place.id);
        if (onSelectPlace) onSelectPlace(place);
      });

      this.markers[place.id] = marker;
    });
  },

  highlightMarker(placeId) {
    // Reset marker sebelumnya
    if (this.activePlaceId && this.markers[this.activePlaceId]) {
      this.markers[this.activePlaceId].setIcon(this.createCustomMarkerIcon(false));
    }

    this.activePlaceId = placeId;
    if (this.markers[placeId]) {
      const marker = this.markers[placeId];
      marker.setIcon(this.createCustomMarkerIcon(true));
      marker.openPopup();
      const pos = marker.getLatLng();
      this.map.panTo(pos, { animate: true, duration: 0.8 });
    }
  },

  panTo(lat, lng, zoom = 15) {
    if (this.map && lat && lng) {
      this.map.flyTo([lat, lng], zoom, { duration: 1.2 });
    }
  },

  invalidateSize() {
    if (this.map) {
      setTimeout(() => this.map.invalidateSize(), 200);
    }
  }
};

