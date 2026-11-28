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

  createCustomMarkerIcon(options = false) {
    const opts = typeof options === 'boolean' ? { isActive: options } : (options || {});
    const isActive = !!opts.isActive;
    const isBestMatch = !!opts.isBestMatch;
    const isOutBudget = !!opts.isOutBudget;

    let bg = '#F57C00';
    let border = '#1A233A';
    let size = 32;
    let iconChar = '📍';
    let extraStyle = '';

    if (isActive) {
      bg = '#FF9800';
      border = '#FFFFFF';
      size = 40;
      iconChar = '📍';
      extraStyle = 'box-shadow: 0 0 16px rgba(255, 152, 0, 0.9); z-index: 1000;';
    } else if (isBestMatch) {
      bg = '#EA580C';
      border = '#FFD700';
      size = 38;
      iconChar = '✨';
      extraStyle = 'box-shadow: 0 0 14px rgba(255, 215, 0, 0.85);';
    } else if (isOutBudget) {
      bg = '#94A3B8';
      border = '#64748B';
      size = 26;
      iconChar = '📍';
      extraStyle = 'opacity: 0.45; filter: grayscale(0.6);';
    }

    return L.divIcon({
      className: `mampir-map-pin ${isBestMatch ? 'marker-best-match' : ''} ${isOutBudget ? 'marker-out-budget' : ''}`,
      html: `
        <div style="
          width: ${size}px;
          height: ${size}px;
          background: ${bg};
          border: 2px solid ${border};
          border-radius: 50% 50% 50% 0;
          transform: rotate(-45deg);
          box-shadow: 0 4px 12px rgba(0,0,0,0.35);
          display: flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          transition: all 0.25s ease;
          ${extraStyle}
        ">
          <span style="
            transform: rotate(45deg);
            color: #FFFFFF;
            font-size: ${size > 34 ? '16px' : (size < 30 ? '11px' : '13px')};
            font-weight: bold;
          ">${iconChar}</span>
        </div>
      `,
      iconSize: [size, size],
      iconAnchor: [size / 2, size]
    });
  },

  renderMarkers(places, onSelectPlace, budgetFilterContext = null) {
    if (!this.map) return;

    // Bersihkan marker lama
    Object.values(this.markers).forEach(m => this.map.removeLayer(m));
    this.markers = {};

    const isBudgetActive = budgetFilterContext && budgetFilterContext.isBudgetActive;
    const maxBudget = budgetFilterContext ? budgetFilterContext.userBudget : null;

    places.forEach(place => {
      if (!place.latitude || !place.longitude) return;

      const isOutBudget = isBudgetActive && maxBudget && (place.min_price || 0) > maxBudget;
      const isBestMatch = isBudgetActive && !isOutBudget && !!place.isBestBudgetMatch;

      const marker = L.marker([place.latitude, place.longitude], {
        icon: this.createCustomMarkerIcon({
          isActive: false,
          isBestMatch,
          isOutBudget,
          isBudgetActive
        }),
        opacity: isOutBudget ? 0.35 : 1.0
      }).addTo(this.map);

      // Simpan metadata di marker untuk highlight
      marker.placeMeta = { isBestMatch, isOutBudget, isBudgetActive };

      const catLabel = typeof I18nService !== 'undefined'
        ? I18nService.translateCategory(place.category || 'Cafe')
        : (place.category || 'Cafe');
      const detailLabel = typeof window.t === 'function' ? window.t('view_detail', 'Lihat Detail') : 'Lihat Detail';
      const routeLabel = typeof window.t === 'function' ? window.t('route_label', 'Rute ↗') : 'Rute ↗';
      const bestMatchLabel = typeof window.t === 'function' ? window.t('budget_badge_best_match', 'Pas di Budget') : 'Pas di Budget';
      const canGetPrefix = typeof window.t === 'function' ? window.t('budget_can_get_prefix', 'Bisa dapet:') : 'Bisa dapet:';

      // Popup Content
      const popupHtml = `
        <div class="map-popup-card">
          <img src="${place.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${place.name}" class="map-popup-img" />
          <div class="map-popup-body">
            <div class="map-popup-header">
              <span class="badge-cat">${catLabel}</span>
              ${isBestMatch ? `<span class="badge-best-budget">✨ ${bestMatchLabel}</span>` : ''}
              <span class="badge-rating">⭐ ${place.rating || 4.5}</span>
            </div>
            <h4 class="map-popup-title">${place.name}</h4>
            <p class="map-popup-city">📍 ${place.city || 'Purwokerto'}</p>
            <p class="map-popup-price">${RecommendationService.formatPrice(place)}</p>
            ${place.affordableCombo ? `
              <div class="map-popup-combo">
                💡 ${canGetPrefix} <strong>${place.affordableCombo.text}</strong> <span style="color: var(--accent-orange); font-weight: 700;">(${place.affordableCombo.priceFormatted})</span>
              </div>
            ` : ''}
            <div class="map-popup-actions">
              <button class="btn-popup-detail" onclick="window.App.openPlaceDetail('${place.id}')">${detailLabel}</button>
              <button class="btn-popup-route" onclick="if(window.NearbyController && typeof window.NearbyController.showInAppRoute === 'function'){ window.NearbyController.showInAppRoute('${place.id}'); } else { window.open('https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}', '_blank'); }">${routeLabel}</button>
            </div>
          </div>
        </div>
      `;

      marker.bindPopup(popupHtml, { maxWidth: 290, className: 'mampir-leaflet-popup' });

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
      const prevMarker = this.markers[this.activePlaceId];
      const meta = prevMarker.placeMeta || {};
      prevMarker.setIcon(this.createCustomMarkerIcon({
        isActive: false,
        isBestMatch: meta.isBestMatch,
        isOutBudget: meta.isOutBudget,
        isBudgetActive: meta.isBudgetActive
      }));
      prevMarker.setOpacity(meta.isOutBudget ? 0.35 : 1.0);
    }

    this.activePlaceId = placeId;
    if (this.markers[placeId]) {
      const marker = this.markers[placeId];
      const meta = marker.placeMeta || {};
      marker.setIcon(this.createCustomMarkerIcon({
        isActive: true,
        isBestMatch: meta.isBestMatch,
        isOutBudget: false,
        isBudgetActive: meta.isBudgetActive
      }));
      marker.setOpacity(1.0);
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

  zoomIn() {
    if (this.map) {
      this.map.zoomIn();
    }
  },

  zoomOut() {
    if (this.map) {
      this.map.zoomOut();
    }
  },

  userMarker: null,

  updateUserMarker(lat, lng, label = 'Lokasi Anda') {
    if (!this.map || !lat || !lng) return;
    if (this.userMarker) {
      this.map.removeLayer(this.userMarker);
      this.userMarker = null;
    }
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

    this.userMarker = L.marker([lat, lng], {
      icon: userIcon,
      zIndexOffset: 10000
    }).addTo(this.map);

    this.userMarker.bindTooltip('📍 ' + (label.length > 22 ? label.substring(0, 22) + '...' : label), {
      permanent: true,
      direction: 'top',
      className: 'user-gps-permanent-badge',
      offset: [0, -18]
    });

    this.userMarker.bindPopup(`
      <div style="font-family: var(--font-family); padding: 4px; font-size: 13px;">
        <strong style="color: #2563EB;">📍 ${label}</strong><br>
        <small style="color: var(--text-muted); font-size: 10px;">${lat.toFixed(5)}, ${lng.toFixed(5)}</small>
      </div>
    `);
  },

  clearUserMarker() {
    if (this.map && this.userMarker) {
      this.map.removeLayer(this.userMarker);
      this.userMarker = null;
    }
  },

  async recenterUser() {
    if (window.NearbyController) {
      if (!window.NearbyController.isActive) {
        await window.NearbyController.activate();
      } else {
        await window.NearbyController.requestLocation(true);
      }
      if (window.NearbyController.userCoords) {
        const u = window.NearbyController.userCoords;
        this.updateUserMarker(u.latitude, u.longitude, u.label || 'Lokasi Anda');
        this.panTo(u.latitude, u.longitude, 16);
      }
    } else {
      this.panTo(AppConfig.centerCoordinates.lat, AppConfig.centerCoordinates.lng, 15);
    }
  },

  invalidateSize() {
    if (this.map) {
      setTimeout(() => this.map.invalidateSize(), 200);
    }
    if (this.detailMap) {
      setTimeout(() => this.detailMap.invalidateSize(), 200);
    }
  },

  detailMap: null,
  detailMarker: null,
  detailUserMarker: null,
  detailRoutePolyline: null,
  detailRouteGlow: null,
  detailUserCoords: null,
  detailPlaceCoords: null,
  detailRouteBounds: null,

  async renderPlaceDetailMap(containerId, place, userCoords = null) {
    const el = document.getElementById(containerId);
    if (!el || !place) return;

    const lat = parseFloat(place.latitude);
    const lng = parseFloat(place.longitude);
    if (isNaN(lat) || isNaN(lng)) return;

    this.detailPlaceCoords = { lat, lng, name: place.name };

    if (this.detailMap) {
      this.detailMap.remove();
      this.detailMap = null;
      this.detailMarker = null;
      this.detailUserMarker = null;
      this.detailRoutePolyline = null;
      this.detailRouteGlow = null;
    }

    this.detailMap = L.map(containerId, {
      center: [lat, lng],
      zoom: 16,
      zoomControl: true,
      scrollWheelZoom: false
    });

    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors • MAMPIR',
      maxZoom: 19
    }).addTo(this.detailMap);

    const restoIcon = this.createCustomMarkerIcon({ isActive: true });
    this.detailMarker = L.marker([lat, lng], { icon: restoIcon }).addTo(this.detailMap);

    const catLabel = typeof I18nService !== 'undefined'
      ? I18nService.translateCategory(place.category || 'Cafe')
      : (place.category || 'Cafe');

    this.detailMarker.bindPopup(`
      <div style="font-family: var(--font-family); padding: 4px; font-size: 13px; line-height: 1.4;">
        <span style="font-size: 10px; font-weight: 700; color: var(--accent-orange); text-transform: uppercase;">${catLabel}</span>
        <h4 style="margin: 2px 0 4px; font-size: 14px; font-weight: 800; color: var(--text-primary);">${place.name}</h4>
        <p style="margin: 0; font-size: 11px; color: var(--text-secondary);">📍 ${place.address || place.city}</p>
      </div>
    `).openPopup();

    // Pastikan koordinat user tersedia (live GPS atau default acuan)
    const u = userCoords || window.NearbyController?.userCoords || { latitude: -7.4243, longitude: 109.2303, label: 'Alun-Alun Purwokerto' };
    const uLat = parseFloat(u.latitude);
    const uLng = parseFloat(u.longitude);

    if (!isNaN(uLat) && !isNaN(uLng)) {
      this.detailUserCoords = { lat: uLat, lng: uLng, label: u.label || 'Posisi Anda' };

      const userIcon = L.divIcon({
        className: 'mampir-user-gps-pin',
        html: `
          <div class="user-gps-pulse-ring"></div>
          <div class="user-gps-core-dot"><span>📍</span></div>
        `,
        iconSize: [36, 36],
        iconAnchor: [18, 18]
      });

      this.detailUserMarker = L.marker([uLat, uLng], { icon: userIcon })
        .addTo(this.detailMap)
        .bindTooltip(u.label || 'Posisi Anda', { permanent: true, direction: 'top', offset: [0, -10] });

      // Ambil Rute Jalan Raya In-App (OSRM / Google Routes)
      const navInfoEl = document.getElementById('detail-nav-info-text');
      if (navInfoEl) {
        navInfoEl.innerHTML = '⏳ Menghitung rute navigasi jalan raya in-app...';
      }

      try {
        let routeData = null;
        if (window.NearbyController && typeof window.NearbyController.fetchRoadRoute === 'function') {
          routeData = await window.NearbyController.fetchRoadRoute(uLat, uLng, lat, lng);
        } else {
          routeData = {
            points: [[uLat, uLng], [lat, lng]],
            distanceMeters: Math.round(Math.hypot((lat - uLat) * 111000, (lng - uLng) * 111000)),
            durationSeconds: 300,
            source: 'direct'
          };
        }

        if (this.detailMap && routeData && routeData.points && routeData.points.length > 0) {
          // Glow outline
          this.detailRouteGlow = L.polyline(routeData.points, {
            color: '#FFFFFF',
            weight: 9,
            opacity: 0.7,
            lineJoin: 'round',
            lineCap: 'round'
          }).addTo(this.detailMap);

          // Vivid orange navigation polyline
          this.detailRoutePolyline = L.polyline(routeData.points, {
            color: '#FF7A00',
            weight: 5,
            opacity: 0.95,
            lineJoin: 'round',
            lineCap: 'round'
          }).addTo(this.detailMap);

          this.detailRouteBounds = this.detailRoutePolyline.getBounds();
          this.detailMap.fitBounds(this.detailRouteBounds, { padding: [40, 40], maxZoom: 16 });

          const distM = routeData.distanceMeters || Math.round(Math.hypot((lat - uLat) * 111000, (lng - uLng) * 111000));
          const distText = distM < 1000 ? `${distM} meter` : `${(distM / 1000).toFixed(1)} km`;
          const durationSec = routeData.durationSeconds || Math.round((distM / 1000) * 180);
          const motorMin = Math.max(1, Math.round(durationSec / 60));
          const walkMin = Math.max(1, Math.round((distM / 1000) * 12));

          if (navInfoEl) {
            navInfoEl.innerHTML = `
              Jarak: <strong>${distText}</strong> • Estimasi: <strong>🛵 ${motorMin} mnt</strong> / <strong>🚶 ${walkMin} mnt</strong> 🛣️ <em>(Turn-by-Turn Rute In-App)</em>
            `;
          }
        }
      } catch (routeErr) {
        console.warn('In-app route error, falling back:', routeErr);
        if (this.detailMap) {
          this.detailRoutePolyline = L.polyline([[uLat, uLng], [lat, lng]], {
            color: '#F57C00',
            weight: 4,
            dashArray: '6, 8',
            opacity: 0.85
          }).addTo(this.detailMap);
          this.detailMap.fitBounds(this.detailRoutePolyline.getBounds(), { padding: [40, 40] });
        }
      }
    }

    setTimeout(() => {
      if (this.detailMap) {
        this.detailMap.invalidateSize();
      }
    }, 250);
  },

  recenterDetailMap(lat, lng) {
    if (this.detailMap && lat && lng) {
      this.detailMap.flyTo([lat, lng], 17, { duration: 0.8 });
      if (this.detailMarker) {
        this.detailMarker.openPopup();
      }
    }
  },

  recenterDetailUser() {
    if (this.detailMap && this.detailUserCoords) {
      this.detailMap.flyTo([this.detailUserCoords.lat, this.detailUserCoords.lng], 17, { duration: 0.8 });
      if (this.detailUserMarker) {
        this.detailUserMarker.openTooltip();
      }
    }
  },

  toggleDetailRouteBounds() {
    if (this.detailMap && this.detailRouteBounds) {
      this.detailMap.fitBounds(this.detailRouteBounds, { padding: [40, 40], maxZoom: 16 });
    }
  },

  startInAppNavigation(placeName = 'tujuan') {
    if (this.detailMap && this.detailUserCoords) {
      this.detailMap.flyTo([this.detailUserCoords.lat, this.detailUserCoords.lng], 17, { duration: 0.9 });
      if (window.App && typeof window.App.showToast === 'function') {
        window.App.showToast(`🧭 Navigasi In-App aktif! Ikuti rute oranye menuju ${placeName}.`);
      }
    }
  },

  destroyDetailMap() {
    if (this.detailMap) {
      this.detailMap.remove();
      this.detailMap = null;
      this.detailMarker = null;
      this.detailUserMarker = null;
      this.detailRoutePolyline = null;
      this.detailRouteGlow = null;
      this.detailUserCoords = null;
      this.detailPlaceCoords = null;
      this.detailRouteBounds = null;
    }
  }
};

window.MapController = MapController;

