/**
 * MAMPIR Web - Main Application Controller
 * Mengintegrasikan State Katalog, Supabase REST API, Algoritma Rekomendasi,
 * Peta Interaktif Leaflet, Modal Dialog, dan Web Admin Dashboard.
 */

window.App = {
  // State Utama
  places: typeof FALLBACK_PLACES !== 'undefined' ? [...FALLBACK_PLACES] : [],
  filteredPlaces: [],
  currentView: 'beranda', // 'beranda', 'cari', 'favorit', 'pengaturan'
  selectedRegion: 'Purwokerto Kota',
  selectedCategory: 'Semua',
  userBudget: 25000,
  userPreferences: ['WiFi', 'Colokan'],
  searchQuery: '',
  sortBy: 'rekomendasi', // 'rekomendasi', 'rating', 'jarak', 'harga_murah'
  isApiOnline: false,
  isBudgetFilterActive: false,
  isNearMeActive: false,
  lastUpsell: null,

  toggleNearMe() {
    if (window.NearbyController) {
      if (window.NearbyController.isActive) {
        window.NearbyController.deactivate();
      } else {
        window.NearbyController.activate();
      }
    }
  },

  async init() {
    console.log('Inisialisasi MAMPIR Web...');

    // Load initial user preferences from LocalStorage
    this.selectedRegion = StorageService.getSelectedRegion();
    this.userBudget = StorageService.getBudget();
    this.userPreferences = StorageService.getUserPreferences();
    this.isBudgetFilterActive = StorageService.isBudgetFilterActive();

    // Setup Theme & Localization
    this.initThemeListener();
    this.applyTheme(StorageService.getTheme());
    if (typeof I18nService !== 'undefined') {
      I18nService.init();
      I18nService.applyDOMTranslations();
      I18nService.onLanguageChange(() => {
        this.updateBudgetButtonUI();
        this.render();
      });
    }

    // Setup UI Controls & Listeners
    this.bindHeaderControls();
    this.bindSidebarNav();
    this.bindFilterModal();
    this.bindAuthModal();
    this.initNotificationCenter();
    this.updateBudgetButtonUI();

    // Inisialisasi Peta Leaflet
    MapController.init('live-map-container');

    // Fetch Master Data
    await this.fetchPlaces();

    // Check first launch for onboarding
    if (StorageService.isFirstLaunch()) {
      this.openOnboardingModal();
    }

    // Update User Profile button
    this.updateUserProfileUI();

    // Render current view
    this.render();

    // Cek Deep Link URL Parameter (?place=pwt-1)
    const urlParams = new URLSearchParams(window.location.search);
    const placeParam = urlParams.get('place');
    if (placeParam) {
      setTimeout(() => this.openPlaceDetail(placeParam), 500);
    }

    // Deteksi otomatis lokasi pengguna jika izin lokasi sudah pernah diberikan
    if (navigator.permissions && navigator.permissions.query) {
      navigator.permissions.query({ name: 'geolocation' }).then(status => {
        if (status.state === 'granted') {
          console.log('Izin lokasi browser aktif, mendeteksi posisi awal...');
          if (window.NearbyController) {
            window.NearbyController.requestLocation(false);
          }
        }
      }).catch(() => {});
    }
  },

  liveGooglePlaces: [],
  googleSearchDebounce: null,

  async searchGooglePlacesLive(query) {
    const q = (query || '').trim();
    if (!q || q.length < 2 || !AppConfig.googlePlacesApiKey) {
      this.liveGooglePlaces = [];
      this.render();
      return;
    }

    try {
      const uCoords = window.NearbyController?.userCoords || { latitude: -7.4243, longitude: 109.2303 };
      const body = {
        textQuery: `${q} Purwokerto`,
        locationBias: {
          circle: {
            center: { latitude: uCoords.latitude, longitude: uCoords.longitude },
            radius: 15000.0
          }
        },
        languageCode: 'id',
        maxResultCount: 15
      };

      const response = await fetch('https://places.googleapis.com/v1/places:searchText', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': AppConfig.googlePlacesApiKey,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.priceLevel,places.primaryType,places.types,places.regularOpeningHours.openNow,places.photos'
        },
        body: JSON.stringify(body)
      });

      if (response.ok) {
        const data = await response.json();
        if (data && Array.isArray(data.places)) {
          this.liveGooglePlaces = data.places.map(p => {
            const transformed = window.NearbyController ? window.NearbyController.transformGooglePlace(p, uCoords.latitude, uCoords.longitude) : null;
            if (transformed) {
              return {
                ...transformed,
                city: 'Purwokerto',
                description: `Tempat nyata terverifikasi Google Maps dengan rating ${p.rating || 4.5} (${p.userRatingCount || 50}+ ulasan).`,
                is_google_live: true
              };
            }
            return null;
          }).filter(Boolean);
        }
      }
    } catch (e) {
      console.warn('Google Places live search error:', e);
    }

    this.render();
  },

  getPlaceById(id) {
    const raw = this.getMergedPlacesList().find(p => p.id === id);
    if (!raw) return null;
    const overrides = StorageService.getCafeOverrides(id) || {};
    return { ...raw, ...overrides };
  },

  getMergedPlacesList() {
    const allOverrides = StorageService.getAllCafeOverrides();
    const base = this.places.map(p => {
      const o = allOverrides[p.id];
      return o ? { ...p, ...o } : p;
    });

    if (this.searchQuery && this.liveGooglePlaces && this.liveGooglePlaces.length > 0) {
      const baseNames = new Set(base.map(p => (p.name || '').toLowerCase().trim()));
      const uniqueGoogle = this.liveGooglePlaces.filter(g => !baseNames.has((g.name || '').toLowerCase().trim()));
      return [...uniqueGoogle, ...base];
    }

    return base;
  },

  /**
   * Mengambil data tempat kuliner dari Supabase REST API dengan offline fallback
   */
  async fetchPlaces() {
    const statusTextEl = document.getElementById('api-status-text');
    const statusDotEl = document.getElementById('api-status-dot');

    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 2500);

      const response = await fetch(AppConfig.placesEndpoint, {
        headers: AppConfig.headers,
        cache: 'no-store',
        signal: controller.signal
      });
      clearTimeout(timeoutId);

      if (response.ok) {
        const data = await response.json();
        if (Array.isArray(data) && data.length > 0) {
          this.places = data;
          this.isApiOnline = true;
          if (statusTextEl) {
            statusTextEl.textContent = window.t('api_places_count', `Supabase REST API (${this.places.length} Tempat)`, { n: this.places.length });
          }
          if (statusDotEl) {
            statusDotEl.classList.remove('offline');
            statusDotEl.title = 'Koneksi Live ke Supabase aktif';
          }
          console.log(`Berhasil memuat ${this.places.length} tempat dari Supabase.`);
          return;
        }
      }
      throw new Error('Response non-ok atau data kosong');
    } catch (e) {
      console.warn('Gagal memanggil Supabase REST API, menggunakan data cadangan lokal.', e);
      this.places = typeof FALLBACK_PLACES !== 'undefined' ? FALLBACK_PLACES : [];
      this.isApiOnline = false;
      if (statusTextEl) {
        statusTextEl.textContent = `Offline (${this.places.length})`;
      }
      if (statusDotEl) {
        statusDotEl.classList.add('offline');
        statusDotEl.title = 'Menggunakan data cadangan lokal';
      }
    }
  },

  /**
   * Menghitung & menyaring data tempat kuliner untuk ditampilkan
   */
  getProcessedPlaces() {
    let list = this.getMergedPlacesList();

    // Jika di tab favorit, ambil hanya tempat yang di-bookmark
    if (this.currentView === 'favorit') {
      const favIds = StorageService.getFavorites();
      list = list.filter(p => favIds.includes(p.id));
    }

    // 1. Saring pencarian kata kunci secara ketat (Feedback Client 1)
    if (this.searchQuery && this.searchQuery.trim().length > 0) {
      const q = this.searchQuery.trim().toLowerCase();
      const tokens = q.split(/\s+/).filter(Boolean);
      list = list.filter(p => {
        const name = (p.name || '').toLowerCase();
        const cat = (p.category || '').toLowerCase();
        const addr = (p.address || '').toLowerCase();
        const desc = (p.description || '').toLowerCase();
        const tags = Array.isArray(p.tags) ? p.tags.join(' ').toLowerCase() : '';
        const menus = Array.isArray(p.menu_highlights) ? p.menu_highlights.map(m => (m.name || '')).join(' ').toLowerCase() : '';
        const combined = `${name} ${cat} ${addr} ${desc} ${tags} ${menus}`;
        return combined.includes(q) || tokens.every(t => combined.includes(t));
      });
    }

    // 2. Saring budget secara ketat jika filter budget aktif (Sesuai instruksi: tempat di atas budget DILARANG muncul)
    if (this.isBudgetFilterActive && this.userBudget > 0) {
      list = list.filter(p => {
        const minP = p.min_price || 0;
        return minP > 0 && minP <= this.userBudget;
      });
    }

    // 3. Saring Wilayah secara ketat sesuai pilihan pengguna (Feedback Client 22.07)
    if (!this.isNearMeActive && this.selectedRegion && !this.selectedRegion.toLowerCase().includes('semua')) {
      const keywords = RecommendationService.getRegionKeywords(this.selectedRegion);
      list = list.filter(p => {
        const c = (p.city || '').toLowerCase();
        const a = (p.address || '').toLowerCase();
        const n = (p.name || '').toLowerCase();
        const combined = `${c} ${a} ${n}`;
        return keywords.some(kw => combined.includes(kw));
      });
    }

    // Rekomendasi scoring
    const recommendations = RecommendationService.getRecommendations({
      allPlaces: list,
      userBudget: this.userBudget,
      isBudgetActive: this.isBudgetFilterActive,
      selectedRegion: this.selectedRegion,
      selectedCategory: this.selectedCategory,
      userPreferences: this.userPreferences,
      searchQuery: this.searchQuery
    });

    this.lastUpsell = this.isBudgetFilterActive ? recommendations.upsell : null;

    let result = recommendations.map(r => ({
      ...r.place,
      recommendationScore: r.totalScore,
      reasonBadge: r.reasonBadge,
      affordableCombo: r.affordableCombo,
      isBestBudgetMatch: r.place.isBestBudgetMatch
    }));

    // Saring akhir: jika filter budget aktif, pastikan secara ketat tidak ada tempat di atas budget yang lolos
    if (this.isBudgetFilterActive && this.userBudget > 0) {
      result = result.filter(p => (p.min_price || 0) <= this.userBudget);
    }

    // Sorting
    if (this.sortBy === 'rating') {
      result.sort((a, b) => (b.rating || 0) - (a.rating || 0));
    } else if (this.sortBy === 'jarak') {
      result.sort((a, b) => (a.distance || 0) - (b.distance || 0));
    } else if (this.sortBy === 'harga_murah') {
      result.sort((a, b) => (a.avg_price || a.min_price) - (b.avg_price || b.min_price));
    }

    return result;
  },

  /**
   * Render utama tampilan berdasarkan currentView
   */
  render() {
    const catalogCol = document.getElementById('catalog-content-area');
    if (!catalogCol) return;

    if (this.currentView === 'pengaturan') {
      this.renderSettingsView(catalogCol);
      return;
    }

    const processed = this.getProcessedPlaces();

    // Render Markers on Map dengan highlight budget & translusensi
    MapController.renderMarkers(processed, (place) => {
      this.openPlaceDetail(place.id);
    }, {
      isBudgetActive: this.isBudgetFilterActive,
      userBudget: this.userBudget
    });

    // Render HTML Catalog
    let html = '';

    const hasSearch = (this.searchQuery || '').trim().length > 0;

    if (this.currentView === 'cari') {
      html += this.renderSearchTabHeader();
    } else if (this.currentView === 'favorit') {
      html += this.renderFavoritesHeader(processed.length);
    } else {
      // Default: Beranda view
      if (processed.length > 0 && !hasSearch) {
        html += this.renderFeaturedCard(processed[0]);
      }

      // Rekomendasi Berbasis Aktivitas Pengguna (Req 4)
      if (!hasSearch) {
        let recCandidatePlaces = this.getMergedPlacesList();
        if (this.isBudgetFilterActive && this.userBudget > 0) {
          recCandidatePlaces = recCandidatePlaces.filter(p => (p.min_price || 0) <= this.userBudget);
        }
        const activityRecs = RecommendationService.getActivityBasedRecommendations({
          allPlaces: recCandidatePlaces,
          maxItems: 6
        });
        html += this.renderActivityRecommendationCarousel(activityRecs);
      }

      // Banner Ajakan Fitur Nearby Gojek-Style
      if (!hasSearch) {
        html += `
          <div class="nearby-cta-banner" onclick="window.NearbyController.activate()">
            <div class="nearby-cta-left">
              <span class="nearby-cta-icon">📍</span>
              <div>
                <h4 class="nearby-cta-title">Cari Tempat Makan & Nongkrong Terdekat (Live GPS)</h4>
                <p class="nearby-cta-desc">Deteksi lokasi Anda, filter radius 0–1 km s/d >10 km via Google Places API & peta interaktif!</p>
              </div>
            </div>
            <button class="btn-nearby-cta-action">
              <span>Buka Near Me</span>
              <span>🛵 ➔</span>
            </button>
          </div>
        `;
      }

      html += this.renderCategoryFilterBar();
    }

    // Grid of cards
    if (processed.length === 0) {
      html += `
        <div class="empty-state">
          <div class="empty-state-icon">🍽️</div>
          <h3>${window.t('no_places_title', 'Tidak ada tempat yang cocok')}</h3>
          <p>${window.t('no_places_desc', 'Coba sesuaikan filter wilayah, kategori, atau naikkan batas anggaran Anda.')}</p>
          <button class="btn-primary" onclick="window.App.resetFilters()">${window.t('btn_reset_filters', 'Reset Filter')}</button>
        </div>
      `;
    } else {
      // Smart Fallback / Dynamic Upsell Banner jika opsi mepet / sedikit (Req 3)
      if (this.isBudgetFilterActive && this.lastUpsell) {
        const extraFormatted = RecommendationService.formatRupiah(this.lastUpsell.neededExtra);
        html += `
          <div class="budget-upsell-banner">
            <div class="upsell-left">
              <div class="upsell-icon">💡</div>
              <div>
                <div class="upsell-title">${window.t('budget_upsell_banner_title', 'Rekomendasi Cerdas Budget')}</div>
                <div class="upsell-desc">
                  ${window.t('budget_upsell_banner_desc', `Hanya butuh tambah sedikit lagi (+ ${extraFormatted}) untuk membuka ${this.lastUpsell.unlockedCount} kafe populer lainnya di sekitar sini!`, { amount: extraFormatted, count: this.lastUpsell.unlockedCount })}
                </div>
              </div>
            </div>
            <button class="btn-upsell-action" onclick="window.App.applyUpsellBudget(${this.lastUpsell.newBudget})">
              ${window.t('budget_upsell_btn', `+ Tambah ${extraFormatted} Sekarang`, { amount: extraFormatted })}
            </button>
          </div>
        `;
      }

      html += `<div class="section-header">
        <h3 class="section-title">
          <span>${this.getSectionTitle()}</span>
          <small style="font-size: 13px; color: var(--text-secondary); font-weight: normal;">(${processed.length} ${window.t('places_found', 'tempat ditemukan')})</small>
        </h3>
      </div>`;

      html += `<div class="places-grid">`;
      // Jika di beranda dan ada featured, skip index 0
      const itemsToRender = (this.currentView === 'beranda' && !hasSearch && processed.length > 1)
        ? processed.slice(1)
        : processed;

      itemsToRender.forEach(p => {
        html += this.renderPlaceCard(p);
      });
      html += `</div>`;
    }

    catalogCol.innerHTML = html;
  },

  getSectionTitle() {
    if (this.currentView === 'cari') {
      return window.t('nav_search', 'Hasil Pencarian');
    }
    if (this.currentView === 'favorit') {
      return window.t('nav_favorites', 'Daftar Tempat Favorit Anda');
    }
    if (this.isNearMeActive || (window.NearbyController && window.NearbyController.isActive)) {
      return 'Rekomendasi Cafe/Resto Terdekat';
    }
    return window.t('all_recommendations_title', 'Rekomendasi untuk lokasi cafe/resto terdekat');
  },

  renderFeaturedCard(place) {
    if (!place) return '';
    const isFav = StorageService.isFavorite(place.id);
    const catLabel = typeof I18nService !== 'undefined' ? I18nService.translateCategory(place.category) : place.category;
    const kmText = window.t('km_from_center', 'km dari Alun-Alun');
    return `
      <div class="featured-card" onclick="window.App.openPlaceDetail('${place.id}')">
        <div class="featured-image-container">
          <img src="${place.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${place.name}" class="featured-image" />
          <div class="featured-overlay"></div>
          <div class="featured-badges">
            <span class="badge-featured">${window.t('top_recommendation', 'Rekomendasi Utama')}</span>
            ${(this.isBudgetFilterActive && place.isBestBudgetMatch) ? `<span class="badge-featured" style="background: linear-gradient(135deg, #FFB74D, #F57C00);">✨ ${window.t('budget_badge_best_match', 'Pas di Budget')}</span>` : ''}
            <span class="badge-score">⭐ ${place.rating || 4.8}</span>
          </div>
          <button class="featured-bookmark-btn ${isFav ? 'active' : ''}" 
                  onclick="event.stopPropagation(); window.App.toggleFav('${place.id}')">
            ${isFav ? '❤️' : '🤍'}
          </button>
          <div class="featured-content">
            <div class="featured-reason">
              ${place.reasonBadge || window.t('best_budget_fit', 'Paling cocok dengan budget Anda')}
              ${place.affordableCombo ? ` • 💡 ${window.t('budget_can_get_prefix', 'Bisa dapet:')} ${place.affordableCombo.text} (${place.affordableCombo.priceFormatted})` : ''}
            </div>
            <h2 class="featured-title">${place.name}</h2>
            <div class="featured-meta">
              <span>📍 ${place.city} (${place.distance || 0} ${kmText})</span>
              <span>💰 ${RecommendationService.formatPrice(place)}</span>
              <span>🏷️ ${catLabel}</span>
            </div>
          </div>
        </div>
      </div>
    `;
  },

  renderActivityRecommendationCarousel(items) {
    if (!items || items.length === 0) return '';
    const hasActivity = StorageService.getActivityHistory().viewedPlaceIds.length > 0;
    const title = typeof I18nService !== 'undefined' ? I18nService.t('activity_recommendation_title') : '✨ Rekomendasi untuk Anda';
    const sub = hasActivity
      ? (typeof I18nService !== 'undefined' ? I18nService.t('activity_recommendation_sub') : 'Berdasarkan kafe dan wilayah yang sering Anda jelajahi')
      : (typeof I18nService !== 'undefined' ? I18nService.t('activity_fallback_sub') : 'Kafe paling populer dengan rating tertinggi di Purwokerto');

    return `
      <section class="activity-section">
        <div class="activity-header">
          <h3 class="activity-title">${title}</h3>
          <span class="activity-subtitle">${sub}</span>
        </div>
        <div class="activity-carousel-track">
          ${items.map(p => `
            <div class="activity-carousel-card" onclick="window.App.openPlaceDetail('${p.id}')">
              <div class="activity-card-img-box">
                <img src="${p.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${p.name}" class="activity-card-img" loading="lazy" />
                <span class="activity-reason-badge">${p.activityReason}</span>
              </div>
              <div class="activity-card-body">
                <h4 class="activity-card-name">${p.name}</h4>
                <div class="activity-card-meta">
                  <span>📍 ${p.city}</span>
                  <span style="color: #FBBF24; font-weight: bold;">⭐ ${p.rating || 4.6}</span>
                </div>
                <div class="activity-card-price">${RecommendationService.formatPrice(p)}</div>
              </div>
            </div>
          `).join('')}
        </div>
      </section>
    `;
  },

  renderCategoryFilterBar() {
    const cats = [
      { key: 'Semua', label: window.t('cat_all', '✨ Semua Tempat') },
      { key: 'Restoran', label: window.t('cat_resto', '🍽️ Restoran') },
      { key: 'Warung Makan', label: window.t('cat_warung', '🍲 Warung Makan') },
      { key: 'Cafe', label: window.t('cat_cafe', '☕ Cafe') },
      { key: 'Coffee Shop', label: window.t('cat_coffee_shop', '🧋 Coffee Shop') },
      { key: 'Warkop', label: window.t('cat_warkop', '🍵 Warkop') },
      { key: 'Fast Food', label: window.t('cat_fastfood', '🍔 Fast Food') },
      { key: 'Bakery', label: window.t('cat_bakery', '🥐 Bakery') }
    ];
    return `
      <div class="category-pills">
        ${cats.map(c => `
          <button class="category-pill ${this.selectedCategory === c.key ? 'active' : ''}"
                  onclick="window.App.selectCategory('${c.key}')">
            ${c.label}
          </button>
        `).join('')}
      </div>
    `;
  },

  renderPlaceCard(place) {
    const isFav = StorageService.isFavorite(place.id);
    const facilities = (place.facilities || []).slice(0, 3);
    const catLabel = typeof I18nService !== 'undefined' ? I18nService.translateCategory(place.category) : (place.category || 'Cafe');
    const isBestMatch = this.isBudgetFilterActive && place.isBestBudgetMatch;
    const bestMatchBadge = isBestMatch
      ? `<span class="badge-best-budget">✨ ${window.t('budget_badge_best_match', 'Pas di Budget')}</span>`
      : '';
    const canGetPrefix = typeof window.t === 'function' ? window.t('budget_can_get_prefix', 'Bisa dapet:') : 'Bisa dapet:';
    const comboHtml = place.affordableCombo
      ? `<div class="place-card-menu-combo">💡 ${canGetPrefix} <strong>${place.affordableCombo.text}</strong> <span class="combo-price">(${place.affordableCombo.priceFormatted})</span></div>`
      : '';

    return `
      <div class="place-card ${isBestMatch ? 'card-best-match' : ''}" onclick="window.App.openPlaceDetail('${place.id}')">
        <div class="place-card-image-wrapper">
          <img src="${place.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${place.name}" class="place-card-img" loading="lazy" />
          <button class="place-card-fav-btn ${isFav ? 'active' : ''}"
                  onclick="event.stopPropagation(); window.App.toggleFav('${place.id}')">
            ${isFav ? '❤️' : '🤍'}
          </button>
          <div style="position: absolute; bottom: 10px; left: 10px; display: flex; gap: 6px; align-items: center; z-index: 2; flex-wrap: wrap;">
            <span class="place-card-category-tag" style="position: static;">${catLabel}</span>
            ${bestMatchBadge}
          </div>
        </div>
        <div class="place-card-body">
          <div class="place-card-header">
            <h4 class="place-card-title">
              <span>${place.name}</span>
              ${place.is_google_live ? `<span class="badge-source-google-live" style="margin-left: 6px;">🌐 Google Maps Live</span>` : ''}
            </h4>
            <div class="place-card-rating">⭐ ${place.rating || 4.5}</div>
          </div>
          <div class="place-card-location">📍 ${place.city} • ${place.distance || 0} km</div>
          <div class="place-card-reason">${place.reasonBadge || window.t('budget_friendly', 'Pas di kantong')}</div>
          ${comboHtml}
          <div class="place-card-facilities">
            ${facilities.map(f => {
              const fLabel = typeof I18nService !== 'undefined' ? I18nService.translateFacility(f) : f;
              return `<span class="facility-chip-mini">${fLabel}</span>`;
            }).join('')}
          </div>
          <div class="place-card-footer">
            <div class="place-card-price">
              ${RecommendationService.formatPrice(place)}
            </div>
            <div class="place-card-actions">
              <button class="btn-card-locate" onclick="event.stopPropagation(); window.App.focusMap('${place.id}', ${place.latitude}, ${place.longitude})">
                ${window.t('pin_map', '🗺️ Pin Peta')}
              </button>
            </div>
          </div>
        </div>
      </div>
    `;
  },

  renderSearchTabHeader() {
    const history = StorageService.getSearchHistory();
    const queryDisplay = this.searchQuery || window.t('all_places_phrase', 'Semua Tempat');
    return `
      <div class="search-tab-view">
        <div class="history-section">
          <div class="history-header">
            <span>${window.t('recent_searches', 'Riwayat Pencarian Terakhir')}</span>
            ${history.length > 0 ? `<button class="btn-clear-history" onclick="window.App.clearSearchHistory()">${window.t('clear_all', 'Hapus Semua')}</button>` : ''}
          </div>
          <div class="history-chips">
            ${history.length === 0 ? `<span style="font-size: 12px; color: var(--text-muted);">${window.t('no_recent_searches', 'Belum ada riwayat pencarian.')}</span>` : ''}
            ${history.map(item => `
              <div class="history-chip" onclick="window.App.applySearchQuery('${item}')">
                <span>${item}</span>
                <span class="chip-remove" onclick="event.stopPropagation(); window.App.removeSearchHistoryItem('${item}')">×</span>
              </div>
            `).join('')}
          </div>
        </div>
        <div class="results-meta-bar">
          <span>${window.t('showing_results_for', 'Menampilkan hasil pencarian untuk:')} <strong>"${queryDisplay}"</strong></span>
          <select class="sort-select" onchange="window.App.setSort(this.value)">
            <option value="rekomendasi" ${this.sortBy === 'rekomendasi' ? 'selected' : ''}>${window.t('sort_recommended', '🎯 Paling Direkomendasikan')}</option>
            <option value="rating" ${this.sortBy === 'rating' ? 'selected' : ''}>${window.t('sort_rating', '⭐ Rating Tertinggi')}</option>
            <option value="jarak" ${this.sortBy === 'jarak' ? 'selected' : ''}>${window.t('sort_distance', '📍 Jarak Terdekat')}</option>
            <option value="harga_murah" ${this.sortBy === 'harga_murah' ? 'selected' : ''}>${window.t('sort_price_low', '💰 Harga Termurah')}</option>
          </select>
        </div>
      </div>
    `;
  },

  renderFavoritesHeader(count) {
    const cats = [
      { key: 'Semua', label: window.t('cat_all', '✨ Semua Tempat') },
      { key: 'Cafe', label: window.t('cat_cafe', '☕ Cafe') },
      { key: 'Warkop', label: window.t('cat_warkop', '🍵 Warkop') },
      { key: 'Restoran', label: window.t('cat_resto', '🍽️ Restoran') }
    ];
    return `
      <div style="margin-bottom: 20px;">
        <div class="category-pills" style="margin-bottom: 12px;">
          ${cats.map(c => `
            <button class="category-pill ${this.selectedCategory === c.key ? 'active' : ''}"
                    onclick="window.App.selectCategory('${c.key}')">
              ${c.label}
            </button>
          `).join('')}
        </div>
        <p style="font-size: 13px; color: var(--text-secondary);">
          ${window.t('fav_header_desc', `Tersimpan ${count} tempat di penyimpanan browser lokal Anda (❤️).`, { count })}
        </p>
      </div>
    `;
  },

  renderSettingsView(container) {
    const session = StorageService.getUserSession();
    const currentTheme = StorageService.getTheme();

    container.innerHTML = `
      <div style="max-width: 600px; display: flex; flex-direction: column; gap: 24px;">
        <h2 class="section-title">${window.t('settings_title', '⚙️ Pengaturan Aplikasi MAMPIR')}</h2>

        <div class="history-section">
          <h4 style="font-size: 14px; margin-bottom: 8px;">${window.t('account_info', 'Informasi Akun')}</h4>
          <p style="font-size: 13px; color: var(--text-secondary);">${window.t('logged_as', 'Masuk sebagai')}: <strong>${session.name}</strong> (${session.isGuest ? window.t('mode_guest', 'Mode Tamu') : session.email})</p>
          <div style="margin-top: 12px; display: flex; gap: 10px;">
            <button class="btn-secondary" onclick="window.App.openAuthModal()">${window.t('btn_switch_acc', 'Ganti Akun')}</button>
            <button class="btn-secondary" style="color: #EF4444;" onclick="window.App.logout()">${window.t('btn_logout', 'Keluar (Sign Out)')}</button>
          </div>
        </div>

        <div class="history-section">
          <h4 style="font-size: 14px; margin-bottom: 6px;">${window.t('theme_section_title', 'Tema Tampilan')}</h4>
          <p style="font-size: 12px; color: var(--text-secondary); margin-bottom: 12px;">
            Pilih preferensi tema. Pilihan <strong>Otomatis</strong> akan otomatis mengikuti tema laptop atau perangkat Anda (mode gelap / terang).
          </p>
          <div style="display: flex; gap: 8px; flex-wrap: wrap;">
            <button class="category-pill ${currentTheme === 'Otomatis' ? 'active' : ''}" onclick="window.App.setTheme('Otomatis')">💻 Otomatis (Ikuti Sistem)</button>
            <button class="category-pill ${currentTheme === 'Gelap' ? 'active' : ''}" onclick="window.App.setTheme('Gelap')">${window.t('theme_dark', '🌙 Mode Gelap')}</button>
            <button class="category-pill ${currentTheme === 'Terang' ? 'active' : ''}" onclick="window.App.setTheme('Terang')">${window.t('theme_light', '☀️ Mode Terang')}</button>
          </div>
        </div>

        <div class="history-section">
          <h4 style="font-size: 14px; margin-bottom: 8px;">${window.t('about_title', 'Tentang MAMPIR Web')}</h4>
          <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.6;">
            ${window.t('about_desc', '<strong>MAMPIR</strong>: Makan, Ampir, Pilih, dan Rekomendasi Tempat Makan & Nongkrong di Kota Purwokerto dan Sekitarnya.<br/>Edisi Multiplatform Web v2.0 • PML 2026.')}
          </p>
        </div>
      </div>
    `;
  },

  // ==================== INTERACTION HANDLERS ====================
  bindHeaderControls() {
    const regionSelect = document.getElementById('global-region-select');
    if (regionSelect) {
      regionSelect.value = this.selectedRegion;
      regionSelect.addEventListener('change', (e) => {
        this.selectedRegion = e.target.value;
        StorageService.setSelectedRegion(this.selectedRegion);
        this.render();
      });
    }

    const searchInput = document.getElementById('global-search-input');
    const searchClear = document.getElementById('global-search-clear');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        this.searchQuery = e.target.value;
        if (searchClear) searchClear.style.display = this.searchQuery ? 'block' : 'none';
        this.render();

        clearTimeout(this.googleSearchDebounce);
        if (this.searchQuery.trim().length >= 2) {
          this.googleSearchDebounce = setTimeout(() => {
            this.searchGooglePlacesLive(this.searchQuery);
          }, 350);
        } else {
          this.liveGooglePlaces = [];
        }
      });
      searchInput.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
          StorageService.addSearchHistory(this.searchQuery);
          this.switchView('cari');
        }
      });
    }

    if (searchClear) {
      searchClear.addEventListener('click', () => {
        if (searchInput) searchInput.value = '';
        this.searchQuery = '';
        this.liveGooglePlaces = [];
        searchClear.style.display = 'none';
        this.render();
      });
    }

    // Toggle theme button
    const themeBtn = document.getElementById('btn-toggle-theme');
    if (themeBtn) {
      themeBtn.addEventListener('click', () => {
        const currentTheme = StorageService.getTheme();
        let nextTheme = 'Gelap';
        if (currentTheme === 'Otomatis') {
          const isSystemDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
          nextTheme = isSystemDark ? 'Terang' : 'Gelap';
        } else if (currentTheme === 'Gelap') {
          nextTheme = 'Terang';
        } else {
          nextTheme = 'Gelap';
        }
        this.setTheme(nextTheme);
      });
    }
  },

  bindSidebarNav() {
    const navItems = document.querySelectorAll('.sidebar-nav .nav-item');
    navItems.forEach(item => {
      item.addEventListener('click', () => {
        const view = item.getAttribute('data-view');
        if (view) this.switchView(view);
      });
    });
  },

  switchView(viewName) {
    if (viewName === 'nearby') {
      window.NearbyController.activate();
      return;
    }
    if (window.NearbyController && window.NearbyController.isActive) {
      window.NearbyController.isActive = false;
      window.NearbyController.clearMapDecorations();
    }
    this.currentView = viewName;
    document.querySelectorAll('.sidebar-nav .nav-item').forEach(el => {
      el.classList.toggle('active', el.getAttribute('data-view') === viewName);
    });

    // Invalidate map size when switching back
    MapController.invalidateSize();
    this.render();
  },

  selectCategory(cat) {
    this.selectedCategory = cat;
    this.render();
  },

  toggleFav(placeId) {
    const isNowFav = StorageService.toggleFavorite(placeId);
    this.render();
    this.showToast(isNowFav ? '❤️ Ditambahkan ke Favorit' : 'Dihapus dari Favorit');
  },

  focusMap(placeId, lat, lng) {
    MapController.highlightMarker(placeId);
    MapController.panTo(lat, lng, 16);
  },

  applySearchQuery(query) {
    this.searchQuery = query;
    const input = document.getElementById('global-search-input');
    if (input) input.value = query;
    this.render();
  },

  removeSearchHistoryItem(item) {
    StorageService.removeSearchHistory(item);
    this.render();
  },

  clearSearchHistory() {
    StorageService.clearSearchHistory();
    this.render();
  },

  setSort(val) {
    this.sortBy = val;
    this.render();
  },

  resetFilters() {
    this.searchQuery = '';
    this.selectedCategory = 'Semua';
    this.selectedRegion = 'Purwokerto Kota';
    this.userBudget = 25000;
    this.isBudgetFilterActive = false;
    this.lastUpsell = null;
    StorageService.setBudgetFilterActive(false);
    this.updateBudgetButtonUI();
    const regSelect = document.getElementById('global-region-select');
    if (regSelect) regSelect.value = 'Purwokerto Kota';
    const sInput = document.getElementById('global-search-input');
    if (sInput) sInput.value = '';
    this.render();
  },

  // ==================== DETAIL MODAL ====================
  openPlaceDetail(placeId) {
    const place = this.getPlaceById(placeId);
    if (!place) return;

    // Rekam aktivitas pengguna untuk personalisasi rekomendasi (Req 4)
    StorageService.recordPlaceActivity(place);

    const modal = document.getElementById('modal-place-detail');
    const body = document.getElementById('modal-place-detail-body');
    if (!modal || !body) return;

    const isFav = StorageService.isFavorite(place.id);
    const facilities = place.facilities || [];
    const menuHighlights = place.menu_highlights || [];
    const distance = RecommendationService.calculateDistance(place.latitude, place.longitude);
    const catLabel = typeof I18nService !== 'undefined' ? I18nService.translateCategory(place.category) : place.category;

    // Agenda / Event Kafe Aktif (Req 2)
    const cafeEvents = StorageService.getCafeEvents(place.id);

    // Ulasan Pengunjung (Req 2)
    const reviews = StorageService.getPlaceReviews(place.id);

    body.innerHTML = `
      <img src="${place.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${place.name}" class="detail-modal-img" />
      
      <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 14px;">
        <div>
          <span class="badge-cat">${catLabel}</span>
          <h2 style="font-size: 22px; margin-top: 6px;">${place.name}</h2>
          <p style="color: var(--text-secondary); font-size: 13px;">📍 ${place.address || place.city}</p>
        </div>
        
        <div style="display: flex; gap: 8px; align-items: center;">
          <!-- Tombol Bagikan / Share Dialog (Req 5) -->
          <button class="btn-detail-action" title="${window.t('btn_share', 'Bagikan')}"
                  onclick="event.stopPropagation(); window.App.openShareModal('${place.id}')">
            ↗️
          </button>
          <!-- Tombol Favorit -->
          <button class="place-card-fav-btn ${isFav ? 'active' : ''}" style="position: static;"
                  onclick="window.App.toggleFav('${place.id}'); window.App.openPlaceDetail('${place.id}');">
            ${isFav ? '❤️' : '🤍'}
          </button>
        </div>
      </div>

      <div style="display: flex; gap: 16px; margin-bottom: 18px; padding: 12px; background: var(--bg-card); border-radius: var(--radius-sm); border: 1px solid var(--border-color); flex-wrap: wrap;">
        <div><small style="color: var(--text-muted);">${window.t('rating_label', 'Rating')}</small><div style="font-weight: bold; color: #FBBF24;">⭐ ${place.rating} (${place.review_count || 100}+)</div></div>
        <div><small style="color: var(--text-muted);">${window.t('price_range_label', 'Rentang Harga')}</small><div style="font-weight: bold; color: var(--accent-orange);">${RecommendationService.formatPrice(place)}</div></div>
        <div><small style="color: var(--text-muted);">${window.t('distance_label', 'Jarak')}</small><div style="font-weight: bold;">${distance} km</div></div>
        <div><small style="color: var(--text-muted);">${window.t('open_hours_label', 'Jam Operasional')}</small><div style="font-weight: bold;">${place.open_hours || '08.00 - 22.00'}</div></div>
      </div>

      <!-- Tombol Aksi: Google Maps -->
      <div style="margin-bottom: 20px;">
        <a href="https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}" target="_blank"
           class="btn-primary" style="display: flex; width: 100%; text-align: center; text-decoration: none; justify-content: center; padding: 12px 18px; font-weight: 700; font-size: 14px; box-sizing: border-box;">
          🗺️ ${window.t('route_btn', 'Buka Rute di Google Maps')}
        </a>
      </div>

      <!-- Agenda & Pengumuman Kafe (Req 2 & Req 7: Kalender & Pasang Pengingat) -->
      ${cafeEvents.length > 0 ? `
        <div class="cafe-events-wrapper">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
            <h4 style="font-size: 14px; font-weight: 700; color: var(--accent-gold); display: flex; align-items: center; gap: 6px; margin: 0;">
              ${window.t('events_upcoming_title', '📅 Agenda & Event Mendatang')}
            </h4>
            <span style="font-size: 11px; padding: 2px 8px; border-radius: 99px; background: rgba(255, 183, 77, 0.15); color: var(--accent-orange); font-weight: 700;">
              ${window.t('events_count', `${cafeEvents.length} Acara`, { count: cafeEvents.length })}
            </span>
          </div>
          ${cafeEvents.map(ev => {
            const isReminderSet = StorageService.isEventReminderSet(ev.id);
            return `
            <div class="cafe-event-card">
              <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px;">
                <span class="cafe-event-badge">${ev.badge || ev.category}</span>
                <span style="font-size: 11px; color: var(--text-muted);">MAMPIR Event</span>
              </div>
              <h5 style="font-size: 14px; font-weight: bold; margin: 4px 0;">${ev.title}</h5>
              <div style="font-size: 12px; color: var(--accent-orange); margin-bottom: 6px; font-weight: 600;">⏰ ${ev.date}</div>
              <p style="font-size: 12px; color: var(--text-secondary); line-height: 1.5; margin-bottom: 8px;">${ev.description}</p>

              <!-- Tombol CTA Pasang Pengingat & Tambah ke Kalender (Req 7) -->
              <div class="cafe-event-actions">
                <button class="btn-reminder ${isReminderSet ? 'active' : ''}" id="btn-remind-${ev.id}" onclick="window.App.toggleEventReminder('${ev.id}', '${place.id}')">
                  ${isReminderSet
                    ? window.t('btn_reminder_active', '✅ Pengingat Terpasang')
                    : window.t('btn_set_reminder', '⏰ Pasang Pengingat')
                  }
                </button>
                <button class="btn-secondary" style="font-size: 11px; padding: 6px 12px;" onclick="window.App.openCalendarExportModal('${ev.id}', '${place.id}')">
                  📅 ${window.t('btn_add_to_calendar', 'Tambah ke Kalender')}
                </button>
              </div>
            </div>
          `;}).join('')}
        </div>
      ` : ''}

      <div class="detail-section">
        <h4>${window.t('desc_title', 'Deskripsi')}</h4>
        <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.6;">${place.description || 'Tempat kuliner favorit yang nyaman di kawasan Purwokerto.'}</p>
      </div>

      <div class="detail-section">
        <h4>${window.t('facilities_title', 'Fasilitas Tersedia')}</h4>
        <div style="display: flex; gap: 6px; flex-wrap: wrap;">
          ${facilities.map(f => {
            const fLabel = typeof I18nService !== 'undefined' ? I18nService.translateFacility(f) : f;
            return `<span class="category-pill" style="padding: 4px 10px; font-size: 11px;">✓ ${fLabel}</span>`;
          }).join('')}
        </div>
      </div>

      <div class="detail-section">
        <h4>${window.t('menu_title', 'Menu Andalan')}</h4>
        <div class="menu-highlight-list">
          ${menuHighlights.map(m => `
            <div class="menu-item-row">
              <span class="menu-item-name">☕ ${m.name}</span>
              <strong>${RecommendationService.formatRupiah(m.price)}</strong>
            </div>
          `).join('')}
        </div>
      </div>

      <!-- Ulasan & Rating Pengunjung (Req 2) -->
      <div class="reviews-container">
        <h4 style="font-size: 15px; font-weight: 800; margin-bottom: 12px;">${window.t('reviews_title', '⭐ Ulasan & Penilaian Pengunjung')}</h4>
        
        <div class="review-form-box">
          <h5 style="font-size: 13px; font-weight: 700; margin-bottom: 4px;">${window.t('add_review_title', 'Tulis Ulasan Anda')}</h5>
          <div class="stars-selector" id="detail-star-selector">
            <span class="star-rate active" data-val="1" onclick="window.App.setReviewStar(1)">★</span>
            <span class="star-rate active" data-val="2" onclick="window.App.setReviewStar(2)">★</span>
            <span class="star-rate active" data-val="3" onclick="window.App.setReviewStar(3)">★</span>
            <span class="star-rate active" data-val="4" onclick="window.App.setReviewStar(4)">★</span>
            <span class="star-rate active" data-val="5" onclick="window.App.setReviewStar(5)">★</span>
          </div>
          <input type="text" id="review-input-name" class="form-control" style="margin-bottom: 8px;" placeholder="${window.t('review_name_ph', 'Nama Anda...')}" value="${StorageService.getUserSession().name}" />
          <textarea id="review-input-comment" class="form-control" rows="2" style="margin-bottom: 8px;" placeholder="${window.t('review_comment_ph', 'Bagaimana pengalaman Anda di kafe ini?')}"></textarea>
          <button class="btn-primary" style="padding: 7px 16px; font-size: 12px;" onclick="window.App.submitReview('${place.id}')">
            ${window.t('btn_submit_review', 'Kirim Ulasan')}
          </button>
        </div>

        <div class="reviews-list">
          ${reviews.map(r => `
            <div class="review-item-card">
              <div class="review-item-header">
                <strong>${r.author}</strong>
                <span style="color: #FBBF24;">${'★'.repeat(r.rating || 5)}</span>
              </div>
              <p style="font-size: 12px; color: var(--text-secondary); margin-bottom: 4px;">${r.comment}</p>
              <small style="font-size: 10px; color: var(--text-muted);">${r.date}</small>
            </div>
          `).join('')}
        </div>
      </div>
    `;

    modal.classList.add('active');
  },

  // ==================== SHARE MODAL DIALOG (Req 5) ====================
  openShareModal(placeId) {
    const place = this.getPlaceById(placeId);
    if (!place) return;

    const modal = document.getElementById('modal-share-cafe');
    const body = document.getElementById('modal-share-body');
    const heading = document.getElementById('modal-share-heading');
    if (!modal || !body) return;

    if (heading && typeof I18nService !== 'undefined') {
      heading.textContent = window.t('share_modal_title', 'Bagikan Kafe Ini');
    }

    const shareUrl = `${window.location.origin}${window.location.pathname}?place=${place.id}`;
    const shareText = window.t('share_text_prefix', `Yuk cek ${place.name} di MAMPIR Purwokerto:`, { name: place.name });

    const waShareUrl = `https://api.whatsapp.com/send?text=${encodeURIComponent(`${shareText} ${shareUrl}`)}`;
    const xShareUrl = `https://twitter.com/intent/tweet?text=${encodeURIComponent(shareText)}&url=${encodeURIComponent(shareUrl)}`;
    const fbShareUrl = `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`;

    body.innerHTML = `
      <div class="share-dialog-card">
        <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.5;">
          ${window.t('share_subtitle', 'Ajak teman dan keluarga mampir ke tempat nongkrong asyik ini!')}
        </p>

        <div class="share-cafe-preview">
          <img src="${place.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${place.name}" class="share-cafe-thumb" />
          <div style="flex: 1; overflow: hidden;">
            <div style="font-weight: 800; font-size: 14px; color: var(--text-primary); text-overflow: ellipsis; white-space: nowrap; overflow: hidden;">
              ${place.name}
            </div>
            <div style="font-size: 11px; color: var(--text-secondary);">📍 ${place.city} • ⭐ ${place.rating}</div>
            <div style="font-size: 12px; font-weight: 700; color: var(--accent-orange);">${RecommendationService.formatPrice(place)}</div>
          </div>
        </div>

        <div class="share-link-row">
          <input type="text" class="share-link-input" id="share-input-field" value="${shareUrl}" readonly />
          <button class="btn-primary" onclick="window.App.copyShareUrl('${shareUrl}')">
            📋 ${window.t('btn_copy_link', 'Salin Tautan')}
          </button>
        </div>

        <div class="share-social-grid">
          <a href="${waShareUrl}" target="_blank" class="btn-social-share btn-share-wa">
            <span>💬 ${window.t('share_wa', 'WhatsApp')}</span>
          </a>
          <a href="${xShareUrl}" target="_blank" class="btn-social-share btn-share-x">
            <span>𝕏 ${window.t('share_x', 'Twitter / X')}</span>
          </a>
          <a href="${fbShareUrl}" target="_blank" class="btn-social-share btn-share-fb">
            <span>📘 ${window.t('share_fb', 'Facebook')}</span>
          </a>
        </div>
      </div>
    `;

    modal.classList.add('active');
  },

  copyShareUrl(url) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(() => {
        this.showToast(window.t('toast_link_copied', 'Tautan berhasil disalin!'));
      }).catch(() => {
        this.fallbackCopy(url);
      });
    } else {
      this.fallbackCopy(url);
    }
  },

  fallbackCopy(text) {
    const el = document.getElementById('share-input-field');
    if (el) {
      el.select();
      document.execCommand('copy');
      this.showToast(window.t('toast_link_copied', 'Tautan berhasil disalin!'));
    }
  },

  setReviewStar(val) {
    this.currentReviewRating = val;
    document.querySelectorAll('#detail-star-selector .star-rate').forEach(el => {
      const v = parseInt(el.getAttribute('data-val'), 10);
      el.classList.toggle('active', v <= val);
    });
  },

  submitReview(placeId) {
    const author = document.getElementById('review-input-name')?.value || 'Pengunjung MAMPIR';
    const comment = document.getElementById('review-input-comment')?.value;
    const rating = this.currentReviewRating || 5;

    if (!comment || !comment.trim()) {
      alert(window.t('review_alert_empty', 'Silakan tuliskan pengalaman ulasan Anda.'));
      return;
    }

    StorageService.addPlaceReview(placeId, {
      author,
      rating,
      comment
    });

    this.showToast(window.t('review_submitted', 'Ulasan berhasil diterbitkan!'));
    this.openPlaceDetail(placeId);
  },

  closeModal(modalId) {
    const el = document.getElementById(modalId);
    if (el) el.classList.remove('active');
  },

  // ==================== BUDGET FILTER & SMART RECOMMENDATION ====================
  updateBudgetButtonUI() {
    const btn = document.getElementById('btn-open-budget-modal');
    const labelEl = document.getElementById('btn-filter-budget-label');
    const clearEl = document.getElementById('btn-clear-budget-filter');
    if (!btn) return;

    if (this.isBudgetFilterActive) {
      btn.classList.add('active-filtered');
      const formattedBudget = RecommendationService.formatRupiah(this.userBudget);
      if (labelEl) {
        labelEl.textContent = window.t('budget_active_label', `Budget: ≤ ${formattedBudget}`, { budget: formattedBudget });
      }
      if (clearEl) {
        clearEl.style.display = 'inline-flex';
        clearEl.title = window.t('budget_clear_title', 'Hapus Filter Budget');
      }
    } else {
      btn.classList.remove('active-filtered');
      if (labelEl) {
        labelEl.textContent = window.t('btn_filter_budget', 'Filter Budget');
      }
      if (clearEl) {
        clearEl.style.display = 'none';
      }
    }
  },

  clearBudgetFilter() {
    this.isBudgetFilterActive = false;
    this.lastUpsell = null;
    StorageService.setBudgetFilterActive(false);
    this.updateBudgetButtonUI();
    this.render();
    this.showToast(window.t('toast_budget_cleared', 'Filter budget dinonaktifkan.'));
  },

  updateModalBudgetPreview(budgetVal) {
    const previewEl = document.getElementById('budget-modal-live-preview');
    if (!previewEl) return;

    const list = this.getMergedPlacesList();
    const inBudget = list.filter(p => (p.min_price || 0) <= budgetVal);
    const count = inBudget.length;

    if (count <= 1) {
      previewEl.classList.add('tight');
      previewEl.textContent = window.t('budget_preview_tight', '⚠️ Pilihan sangat terbatas. Naikkan sedikit budget untuk melihat lebih banyak opsi.');
    } else {
      previewEl.classList.remove('tight');
      previewEl.textContent = window.t('budget_preview_match', `✨ Ditemukan ${count} kafe yang cocok dengan kantongmu!`, { count });
    }

    // Update active highlight on quick preset chips
    document.querySelectorAll('.budget-preset-chip').forEach(chip => {
      const pVal = parseInt(chip.getAttribute('data-preset'), 10);
      chip.classList.toggle('active', pVal === budgetVal);
    });
  },

  setModalBudgetPreset(val) {
    const slider = document.getElementById('filter-budget-slider');
    const display = document.getElementById('filter-budget-val-display');
    if (slider) slider.value = val;
    if (display) display.textContent = RecommendationService.formatRupiah(val);
    this.updateModalBudgetPreview(val);
  },

  applyUpsellBudget(newBudget) {
    this.userBudget = newBudget;
    this.isBudgetFilterActive = true;
    this.lastUpsell = null;
    StorageService.setBudget(newBudget);
    StorageService.setBudgetFilterActive(true);
    this.updateBudgetButtonUI();
    this.render();
    const budgetFormatted = RecommendationService.formatRupiah(newBudget);
    this.showToast(window.t('toast_budget_upsell_applied', `Budget dinaikkan menjadi ${budgetFormatted}.`, { budget: budgetFormatted }));
  },

  bindFilterModal() {
    const openBtn = document.getElementById('btn-open-budget-modal');
    const modal = document.getElementById('modal-budget-filter');
    const slider = document.getElementById('filter-budget-slider');
    const display = document.getElementById('filter-budget-val-display');

    if (openBtn && modal) {
      openBtn.addEventListener('click', () => {
        if (slider) slider.value = this.userBudget;
        if (display) display.textContent = RecommendationService.formatRupiah(this.userBudget);
        this.updateModalBudgetPreview(this.userBudget);
        modal.classList.add('active');
      });
    }

    if (slider && display) {
      slider.addEventListener('input', (e) => {
        const val = parseInt(e.target.value, 10);
        display.textContent = RecommendationService.formatRupiah(val);
        this.updateModalBudgetPreview(val);
      });
    }

    const applyBtn = document.getElementById('btn-apply-budget-filter');
    if (applyBtn) {
      applyBtn.addEventListener('click', () => {
        if (slider) {
          this.userBudget = parseInt(slider.value, 10);
          StorageService.setBudget(this.userBudget);
        }
        this.isBudgetFilterActive = true;
        StorageService.setBudgetFilterActive(true);
        this.updateBudgetButtonUI();
        this.closeModal('modal-budget-filter');
        this.render();
        const budgetStr = RecommendationService.formatRupiah(this.userBudget);
        this.showToast(window.t('toast_budget_applied', `Filter diterapkan: Budget ${budgetStr}`, { budget: budgetStr }));
      });
    }
  },

  // ==================== AUTH / ONBOARDING ====================
  openOnboardingModal() {
    const m = document.getElementById('modal-onboarding');
    if (m) m.classList.add('active');
  },

  completeOnboarding(selectedRegion) {
    this.selectedRegion = selectedRegion;
    StorageService.setSelectedRegion(selectedRegion);
    StorageService.setFirstLaunchComplete();
    this.closeModal('modal-onboarding');
    const regSelect = document.getElementById('global-region-select');
    if (regSelect) regSelect.value = selectedRegion;
    this.render();
  },

  bindAuthModal() {
    const profileBtn = document.getElementById('btn-user-profile');
    const modal = document.getElementById('modal-auth');
    if (profileBtn && modal) {
      profileBtn.addEventListener('click', () => {
        modal.classList.add('active');
      });
    }
  },

  openAuthModal() {
    const m = document.getElementById('modal-auth');
    if (m) m.classList.add('active');
  },

  switchAuthTab(tab) {
    const tabLogin = document.getElementById('auth-tab-login');
    const tabRegister = document.getElementById('auth-tab-register');
    const formLogin = document.getElementById('form-login');
    const formRegister = document.getElementById('form-register');
    const alertBox = document.getElementById('auth-alert-box');

    if (alertBox) alertBox.style.display = 'none';

    if (tab === 'register') {
      if (tabLogin) tabLogin.classList.remove('active');
      if (tabRegister) tabRegister.classList.add('active');
      if (formLogin) formLogin.style.display = 'none';
      if (formRegister) formRegister.style.display = 'block';
    } else {
      if (tabRegister) tabRegister.classList.remove('active');
      if (tabLogin) tabLogin.classList.add('active');
      if (formRegister) formRegister.style.display = 'none';
      if (formLogin) formLogin.style.display = 'block';
    }
  },

  showAuthAlert(message, type = 'error') {
    const box = document.getElementById('auth-alert-box');
    if (!box) return;
    box.style.display = 'block';
    if (type === 'success') {
      box.style.background = 'rgba(16, 185, 129, 0.15)';
      box.style.border = '1px solid #10B981';
      box.style.color = '#10B981';
    } else {
      box.style.background = 'rgba(239, 68, 68, 0.15)';
      box.style.border = '1px solid #EF4444';
      box.style.color = '#EF4444';
    }
    box.innerHTML = message;
  },

  async handleLogin(email, password) {
    const btn = document.getElementById('btn-submit-login');
    if (btn) {
      btn.disabled = true;
      btn.textContent = 'Memverifikasi...';
    }

    const res = await AuthService.signIn(email, password);

    if (btn) {
      btn.disabled = false;
      btn.textContent = 'Masuk ke Akun';
    }

    if (res.success) {
      if (email.toLowerCase().includes('mitra') || email.toLowerCase().includes('admin')) {
        StorageService.setUserRole('partner', 'pwt-1');
      }
      this.closeModal('modal-auth');
      this.updateUserProfileUI();
      this.showToast(`Selamat datang, ${res.name}! ✨`);
      this.render();
    } else {
      this.showAuthAlert(res.message, 'error');
    }
  },

  async handleRegister(name, email, password, confirmPassword) {
    if (password !== confirmPassword) {
      this.showAuthAlert('Konfirmasi kata sandi tidak cocok. Silakan ketik ulang kata sandi.', 'error');
      return;
    }
    if (password.length < 6) {
      this.showAuthAlert('Kata sandi harus terdiri dari minimal 6 karakter.', 'error');
      return;
    }

    const btn = document.getElementById('btn-submit-register');
    if (btn) {
      btn.disabled = true;
      btn.textContent = 'Mendaftarkan...';
    }

    const res = await AuthService.signUp(email, password, name);

    if (btn) {
      btn.disabled = false;
      btn.textContent = 'Daftar Akun Baru';
    }

    if (res.success) {
      this.showAuthAlert(
        `🎉 <strong>Pendaftaran Berhasil!</strong><br/>${res.message}<br/><br/><em>Catatan: Jika Supabase Anda mengaktifkan 'Confirm email', silakan klik tautan verifikasi di email Anda sebelum masuk.</em>`,
        'success'
      );
    } else {
      this.showAuthAlert(res.message, 'error');
    }
  },

  handleGuestLogin() {
    AuthService.signInAsGuest(this.selectedRegion);
    this.closeModal('modal-auth');
    this.updateUserProfileUI();
    this.showToast(window.t('toast_guest', 'Masuk sebagai Tamu.'));
    this.render();
  },

  logout() {
    AuthService.signOut();
    this.updateUserProfileUI();
    this.showToast(window.t('toast_logged_out', 'Berhasil keluar.'));
    this.switchView('beranda');
  },

  updateUserProfileUI() {
    const session = StorageService.getUserSession();
    const nameEl = document.getElementById('user-profile-name');
    if (nameEl) nameEl.textContent = session.name;
  },

  // ==================== THEME ====================
  initThemeListener() {
    if (window.matchMedia) {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
      const handleSystemThemeChange = () => {
        if (StorageService.getTheme() === 'Otomatis') {
          this.applyTheme('Otomatis');
        }
      };
      if (mediaQuery.addEventListener) {
        mediaQuery.addEventListener('change', handleSystemThemeChange);
      } else if (mediaQuery.addListener) {
        mediaQuery.addListener(handleSystemThemeChange);
      }
    }
  },

  setTheme(theme) {
    StorageService.setTheme(theme);
    this.applyTheme(theme);
    this.render();
  },

  applyTheme(theme = StorageService.getTheme()) {
    let isLight = false;
    if (theme === 'Otomatis') {
      const isSystemDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
      isLight = !isSystemDark;
    } else {
      isLight = theme === 'Terang';
    }
    document.documentElement.setAttribute('data-theme', isLight ? 'light' : 'dark');
    const iconEl = document.getElementById('theme-icon');
    if (iconEl) iconEl.textContent = isLight ? '☀️' : '🌙';
  },

  // ==================== NOTIFICATION CENTER & CALENDAR (Req 7) ====================
  initNotificationCenter() {
    this.updateNotificationBadge();
    const btn = document.getElementById('btn-notifications');
    if (btn) {
      btn.onclick = (e) => {
        this.toggleNotificationPopover(e);
      };
    }
    document.addEventListener('click', (e) => {
      const wrapper = document.getElementById('notification-wrapper');
      const popover = document.getElementById('notification-popover');
      if (popover && wrapper && !wrapper.contains(e.target)) {
        popover.classList.remove('active');
      }
    });
  },

  updateNotificationBadge() {
    const count = StorageService.getUnreadNotificationCount();
    const badge = document.getElementById('notification-unread-badge');
    if (badge) {
      badge.style.display = count > 0 ? 'flex' : 'none';
      badge.textContent = count > 9 ? '9+' : count.toString();
    }
  },

  toggleNotificationPopover(e) {
    if (e && e.stopPropagation) e.stopPropagation();
    const popover = document.getElementById('notification-popover');
    if (!popover) return;
    const isOpen = popover.classList.contains('active');
    if (isOpen) {
      popover.classList.remove('active');
    } else {
      this.renderNotificationsList();
      popover.classList.add('active');
    }
  },

  renderNotificationsList() {
    const container = document.getElementById('notif-items-list');
    if (!container) return;
    const notifs = StorageService.getNotifications();

    if (!notifs || !Array.isArray(notifs) || notifs.length === 0) {
      container.innerHTML = `
        <div class="notif-empty">
          <div style="font-size: 28px; margin-bottom: 6px;">🔔</div>
          <p>${typeof I18nService !== 'undefined' ? I18nService.t('notif_empty') : 'Belum ada notifikasi baru saat ini.'}</p>
        </div>
      `;
      return;
    }

    container.innerHTML = notifs.map(n => {
      const icon = n.category === 'Live Music' ? '🎵'
        : n.category === 'Workshop' ? '☕'
        : n.category === 'Pengingat' ? '⏰'
        : n.category === 'Nonton Bareng' ? '⚽'
        : '🏷️';

      return `
        <div class="notif-item ${!n.read ? 'unread' : ''}" onclick="window.App.handleClickNotification('${n.id}', '${n.placeId}')">
          <div class="notif-icon-badge">${icon}</div>
          <div style="flex: 1; padding-right: 12px;">
            <div style="font-size: 13px; font-weight: 700; color: var(--text-primary); margin-bottom: 2px;">
              ${n.title}
            </div>
            <p style="font-size: 11px; color: var(--text-secondary); line-height: 1.4; margin: 0 0 4px 0;">
              ${n.message}
            </p>
            <div style="font-size: 10px; color: var(--text-muted); display: flex; align-items: center; gap: 6px;">
              <span>📍 ${n.placeName || 'Kafe Purwokerto'}</span>
              <span>•</span>
              <span>${n.date || 'Baru saja'}</span>
            </div>
          </div>
          ${!n.read ? '<div class="notif-unread-dot"></div>' : ''}
        </div>
      `;
    }).join('');
  },

  handleClickNotification(notifId, placeId) {
    StorageService.markNotificationRead(notifId);
    this.updateNotificationBadge();
    const popover = document.getElementById('notification-popover');
    if (popover) popover.classList.remove('active');
    if (placeId) {
      this.openPlaceDetail(placeId);
      setTimeout(() => {
        const eventsEl = document.querySelector('.cafe-events-wrapper');
        if (eventsEl) {
          eventsEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
          eventsEl.style.boxShadow = '0 0 20px rgba(245, 158, 11, 0.6)';
          eventsEl.style.borderColor = 'var(--accent-orange)';
          setTimeout(() => {
            eventsEl.style.boxShadow = '';
          }, 2000);
        }
      }, 300);
    }
  },

  markAllNotificationsRead() {
    StorageService.markAllNotificationsRead();
    this.updateNotificationBadge();
    this.renderNotificationsList();
    this.showToast(window.t('notif_toast_all_read', 'Semua notifikasi telah ditandai dibaca.'));
  },

  toggleEventReminder(eventId, placeId) {
    const events = StorageService.getCafeEvents();
    const event = events.find(e => e.id === eventId);
    if (!event) return;

    const isSet = StorageService.toggleEventReminder(event);
    this.updateNotificationBadge();

    // Update UI tombol
    const btn = document.getElementById(`btn-remind-${eventId}`);
    if (btn) {
      btn.classList.toggle('active', isSet);
      btn.innerHTML = isSet
        ? window.t('btn_reminder_active', '✅ Pengingat Terpasang')
        : window.t('btn_set_reminder', '⏰ Pasang Pengingat');
    }

    if (isSet) {
      this.showToast(window.t('toast_reminder_set', 'Pengingat agenda berhasil dipasang!'));
      // Request Web Notification permission jika didukung
      if ('Notification' in window && Notification.permission === 'default') {
        Notification.requestPermission();
      }
    } else {
      this.showToast(window.t('toast_reminder_cancelled', 'Pengingat agenda dinonaktifkan.'));
    }
  },

  openCalendarExportModal(eventId, placeId) {
    const events = StorageService.getCafeEvents();
    const event = events.find(e => e.id === eventId);
    const place = this.getPlaceById(placeId || event?.placeId);
    if (!event) return;

    const modal = document.getElementById('modal-calendar-export');
    const body = document.getElementById('modal-calendar-body');
    if (!modal || !body) return;

    const gcalUrl = this.generateGoogleCalendarUrl(event, place);

    body.innerHTML = `
      <div style="display: flex; flex-direction: column; gap: 14px;">
        <div style="padding: 12px; background: rgba(255, 183, 77, 0.1); border-radius: var(--radius-sm); border: 1px solid rgba(255, 183, 77, 0.3);">
          <span class="cafe-event-badge">${event.badge || event.category}</span>
          <h4 style="font-size: 15px; font-weight: 800; margin: 4px 0;">${event.title}</h4>
          <div style="font-size: 12px; color: var(--accent-orange); margin-bottom: 4px; font-weight: 600;">⏰ ${event.date}</div>
          <p style="font-size: 12px; color: var(--text-secondary); margin: 0;">📍 ${place?.name || event.placeName}, Purwokerto</p>
        </div>

        <p style="font-size: 13px; color: var(--text-secondary); margin: 0;">
          ${window.t('cal_modal_sub', 'Pilih metode integrasi ke kalender Anda agar tidak ketinggalan acara:')}
        </p>

        <div class="calendar-options-grid">
          <!-- Google Calendar -->
          <a href="${gcalUrl}" target="_blank" class="calendar-option-card" onclick="window.App.closeModal('modal-calendar-export');">
            <div style="font-size: 24px;">📅</div>
            <div style="flex: 1;">
              <div style="font-weight: 700; font-size: 13px;">${window.t('cal_gcal_title', 'Google Calendar')}</div>
              <small style="font-size: 11px; color: var(--text-secondary);">${window.t('cal_gcal_desc', 'Buka langsung agenda acara di Google Calendar web/aplikasi')}</small>
            </div>
            <span style="font-size: 16px; color: var(--accent-orange);">↗</span>
          </a>

          <!-- Download iCal .ics -->
          <div class="calendar-option-card" onclick="window.App.downloadIcsFile('${event.id}'); window.App.closeModal('modal-calendar-export');">
            <div style="font-size: 24px;">📥</div>
            <div style="flex: 1;">
              <div style="font-weight: 700; font-size: 13px;">${window.t('cal_ics_title', 'Unduh File Kalender (.ics)')}</div>
              <small style="font-size: 11px; color: var(--text-secondary);">${window.t('cal_ics_desc', 'Kompatibel dengan Apple Calendar (iPhone/Mac), Outlook & Android')}</small>
            </div>
            <span style="font-size: 16px; color: var(--accent-orange);">⬇</span>
          </div>

          <!-- Pasang Web Reminder -->
          <div class="calendar-option-card" onclick="window.App.toggleEventReminder('${event.id}', '${place?.id}'); window.App.closeModal('modal-calendar-export');">
            <div style="font-size: 24px;">🔔</div>
            <div style="flex: 1;">
              <div style="font-weight: 700; font-size: 13px;">${window.t('cal_web_title', 'Pasang Pengingat Notifikasi MAMPIR')}</div>
              <small style="font-size: 11px; color: var(--text-secondary);">${window.t('cal_web_desc', 'Simpan jadwal di Pusat Notifikasi akun MAMPIR Anda')}</small>
            </div>
            <span style="font-size: 16px; color: var(--accent-orange);">⭐</span>
          </div>
        </div>
      </div>
    `;

    modal.classList.add('active');
  },

  generateGoogleCalendarUrl(event, place) {
    const title = encodeURIComponent(`${event.title} - ${place?.name || event.placeName}`);
    const details = encodeURIComponent(`${event.description}\n\nTempat: ${place?.name || event.placeName}\nAlamat: ${place?.address || 'Purwokerto'}\nInformasi via MAMPIR App`);
    const location = encodeURIComponent(`${place?.name || event.placeName}, ${place?.address || 'Purwokerto, Jawa Tengah'}`);

    const now = new Date();
    now.setDate(now.getDate() + 1);
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    const dates = `${y}${m}${d}T123000Z/${y}${m}${d}T150000Z`;

    return `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${title}&details=${details}&location=${location}&dates=${dates}`;
  },

  downloadIcsFile(eventId) {
    const events = StorageService.getCafeEvents();
    const event = events.find(e => e.id === eventId);
    if (!event) return;

    const now = new Date();
    now.setDate(now.getDate() + 1);
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    const dtStart = `${y}${m}${d}T123000Z`;
    const dtEnd = `${y}${m}${d}T150000Z`;

    const icsContent = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//MAMPIR Purwokerto//Event Calendar//ID',
      'CALSCALE:GREGORIAN',
      'BEGIN:VEVENT',
      `UID:${event.id}@mampir.app`,
      `DTSTAMP:${y}${m}${d}T000000Z`,
      `DTSTART:${dtStart}`,
      `DTEND:${dtEnd}`,
      `SUMMARY:${event.title} - ${event.placeName}`,
      `DESCRIPTION:${event.description.replace(/\n/g, '\\n')}`,
      `LOCATION:${event.placeName}, Purwokerto`,
      'STATUS:CONFIRMED',
      'BEGIN:VALARM',
      'TRIGGER:-PT1H',
      'ACTION:DISPLAY',
      `DESCRIPTION:Pengingat: ${event.title}`,
      'END:VALARM',
      'END:VEVENT',
      'END:VCALENDAR'
    ].join('\r\n');

    const blob = new Blob([icsContent], { type: 'text/calendar;charset=utf-8' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = `mampir-agenda-${event.id}.ics`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    this.showToast(window.t('toast_ics_downloaded', 'File kalender (.ics) berhasil diunduh!'));
  },

  // ==================== TOAST NOTIFICATION ====================
  showToast(msg) {
    let toast = document.getElementById('mampir-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'mampir-toast';
      toast.style.cssText = `
        position: fixed;
        bottom: 24px;
        right: 24px;
        background: rgba(13, 19, 38, 0.95);
        color: #FFFFFF;
        border: 1px solid var(--accent-gold);
        padding: 12px 20px;
        border-radius: var(--radius-md);
        box-shadow: var(--shadow-glow);
        font-size: 13px;
        font-weight: 600;
        z-index: 3000;
        transition: opacity 0.3s ease;
      `;
      document.body.appendChild(toast);
    }
    toast.textContent = msg;
    toast.style.opacity = '1';
    setTimeout(() => {
      toast.style.opacity = '0';
    }, 2500);
  }
};

// Auto start saat DOM loaded
document.addEventListener('DOMContentLoaded', () => {
  window.App.init();
});

