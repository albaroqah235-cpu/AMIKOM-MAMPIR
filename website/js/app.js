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
  lastUpsell: null,

  async init() {
    console.log('Inisialisasi MAMPIR Web...');

    // Load initial user preferences from LocalStorage
    this.selectedRegion = StorageService.getSelectedRegion();
    this.userBudget = StorageService.getBudget();
    this.userPreferences = StorageService.getUserPreferences();
    this.isBudgetFilterActive = StorageService.isBudgetFilterActive();

    // Setup Theme & Localization
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
  },

  getPlaceById(id) {
    const raw = this.places.find(p => p.id === id);
    if (!raw) return null;
    const overrides = StorageService.getCafeOverrides(id) || {};
    return { ...raw, ...overrides };
  },

  getMergedPlacesList() {
    const allOverrides = StorageService.getAllCafeOverrides();
    return this.places.map(p => {
      const o = allOverrides[p.id];
      return o ? { ...p, ...o } : p;
    });
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

    if (this.currentView === 'bantuan') {
      this.renderHelpCenterView(catalogCol);
      return;
    }

    if (this.currentView === 'admin') {
      this.renderAdminDashboardView(catalogCol);
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
        const activityRecs = RecommendationService.getActivityBasedRecommendations({
          allPlaces: this.getMergedPlacesList(),
          maxItems: 6
        });
        html += this.renderActivityRecommendationCarousel(activityRecs);
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

    // Sinkronisasi status tombol adu tongkrongan dan floating drawer
    if (window.Roulette) {
      window.Roulette.updateCardButtons();
      window.Roulette.updateFloatingDrawer();
    }
  },

  getSectionTitle() {
    if (this.currentView === 'cari') {
      return window.t('nav_search', 'Hasil Pencarian');
    }
    if (this.currentView === 'favorit') {
      return window.t('nav_favorites', 'Daftar Tempat Favorit Anda');
    }
    return window.t('all_recommendations_title', 'Rekomendasi Tempat Kuliner & Nongkrong');
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
      { key: 'Cafe', label: window.t('cat_cafe', '☕ Cafe') },
      { key: 'Warkop', label: window.t('cat_warkop', '🍵 Warkop') },
      { key: 'Restoran', label: window.t('cat_resto', '🍽️ Restoran') }
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

    const isVsSelected = window.Roulette && window.Roulette.isCandidateSelected(place.id);
    const vsLabel = isVsSelected
      ? window.t('wheel_card_btn_added', 'Terpilih')
      : window.t('wheel_card_btn_add', 'Adu');

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
            <h4 class="place-card-title">${place.name}</h4>
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
              <button class="btn-card-vs ${isVsSelected ? 'active' : ''}" data-place-id="${place.id}"
                      onclick="event.stopPropagation(); window.Roulette.toggleCandidate('${place.id}')"
                      title="${isVsSelected ? window.t('wheel_card_btn_added', 'Terpilih') : window.t('wheel_card_btn_add', '+ Adu Tongkrongan')}">
                <span>${isVsSelected ? '✓' : '⚔️'}</span>
                <span>${vsLabel}</span>
              </button>
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
          <h4 style="font-size: 14px; margin-bottom: 8px;">${window.t('theme_section_title', 'Tema Tampilan')}</h4>
          <div style="display: flex; gap: 12px;">
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
        searchClear.style.display = 'none';
        this.render();
      });
    }

    // Language switcher
    const langSelect = document.getElementById('global-lang-select');
    if (langSelect && typeof I18nService !== 'undefined') {
      langSelect.value = I18nService.getLanguage();
      langSelect.addEventListener('change', (e) => {
        this.changeLanguage(e.target.value);
      });
    }

    // Toggle theme button
    const themeBtn = document.getElementById('btn-toggle-theme');
    if (themeBtn) {
      themeBtn.addEventListener('click', () => {
        const nextTheme = StorageService.getTheme() === 'Gelap' ? 'Terang' : 'Gelap';
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

    // Format Link WhatsApp Resmi Pengelola Kafe (Req 1)
    const rawPhone = place.whatsapp || '6281234567890';
    const cleanPhone = rawPhone.replace(/\D/g, '');
    const isEn = typeof I18nService !== 'undefined' && I18nService.getLanguage() === 'en';
    const waGreeting = isEn
      ? `Hello Admin ${place.name}, I found your cafe through MAMPIR and would like to ask:`
      : `Halo Admin ${place.name}, saya menemukan kafe Anda melalui Mampir dan ingin bertanya:`;
    const waUrl = `https://wa.me/${cleanPhone}?text=${encodeURIComponent(waGreeting)}`;

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

      <!-- Tombol Aksi: WhatsApp Kontak Pengelola (Req 1) & Google Maps -->
      <div style="display: flex; gap: 10px; margin-bottom: 20px; flex-wrap: wrap;">
        <!-- Tombol CTA WhatsApp Pengelola (Tanpa Nomor Mentah di Layar) -->
        <a href="${waUrl}" target="_blank" class="btn-cta-whatsapp" style="flex: 1; min-width: 220px;" title="${window.t('btn_contact_wa', 'Hubungi Pengelola')}">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
            <path d="M12.031 6.172c-3.181 0-5.767 2.586-5.768 5.766-.001 1.298.38 2.27 1.019 3.287l-.582 2.128 2.182-.573c.978.58 1.911.928 3.145.929 3.178 0 5.767-2.587 5.768-5.766.001-3.187-2.575-5.77-5.764-5.771zm3.392 8.244c-.144.405-.837.774-1.17.824-.312.045-.694.04-1.077-.077-.738-.225-1.745-.732-2.839-1.826-1.094-1.094-1.601-2.101-1.826-2.839-.117-.383-.122-.765-.077-1.077.05-.333.419-1.026.824-1.17.203-.072.396-.062.54.021.162.093.522.86.567.971.045.111.072.24.009.366-.063.126-.135.216-.243.342-.108.126-.216.27-.306.378-.108.126-.225.261-.099.477.126.216.558.918 1.206 1.494.837.747 1.548.981 1.764 1.089.216.108.342.09.468-.054.126-.144.54-.63.684-.846.144-.216.288-.18.495-.108.207.072 1.323.624 1.548.738.225.114.378.171.432.27.054.099.054.576-.09 1.053z"/>
            <path d="M12 2C6.48 2 2 6.48 2 12c0 1.82.49 3.53 1.34 5L2 22l5.18-1.31C8.61 21.49 10.26 22 12 22c5.52 0 10-4.48 10-10S17.52 2 12 2zm0 18c-1.62 0-3.13-.48-4.4-1.31l-.31-.2-3.26.83.85-3.18-.22-.35C3.78 14.65 3.3 13.37 3.3 12c0-4.8 3.9-8.7 8.7-8.7s8.7 3.9 8.7 8.7-3.9 8.7-8.7 8.7z"/>
          </svg>
          <span>${window.t('btn_contact_wa', 'Hubungi Pengelola')}</span>
        </a>
        <a href="https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}" target="_blank"
           class="btn-primary" style="flex: 1; min-width: 200px; text-align: center; text-decoration: none; justify-content: center;">
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
              <span>☕ ${m.name}</span>
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

  changeLanguage(lang) {
    if (typeof I18nService !== 'undefined') {
      I18nService.setLanguage(lang);
    }
    this.updateBudgetButtonUI();
    if (window.Roulette) {
      window.Roulette.drawWheel();
      window.Roulette.updateModeToggleUI();
      window.Roulette.updateFloatingDrawer();
    }
    this.render();
    this.showToast(lang === 'en' ? 'Language switched to English!' : 'Bahasa dialihkan ke Bahasa Indonesia!');
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

  // ==================== HELP CENTER & EDUKASI (Req 6) ====================
  renderHelpCenterView(container) {
    const isEn = typeof I18nService !== 'undefined' && I18nService.getLanguage() === 'en';
    const faqs = [
      {
        cat: 'general',
        q: isEn ? 'How does MAMPIR calculate recommendations for me?' : 'Bagaimana MAMPIR menentukan rekomendasi kafe terbaik untuk saya?',
        a: isEn
          ? 'MAMPIR uses a hybrid content-based recommendation algorithm that analyzes budget alignment, facility preferences (WiFi, plugs, AC), distance from Purwokerto Square, customer ratings, and your browsing activity history.'
          : 'MAMPIR menggunakan algoritma hybrid content-based recommendation yang menggabungkan kesesuaian anggaran, ketersediaan fasilitas (WiFi, colokan, AC), jarak dari Alun-Alun Purwokerto, rating pengunjung, dan riwayat tempat yang sering Anda jelajahi.'
      },
      {
        cat: 'filter',
        q: isEn ? 'How does the budget filter work?' : 'Bagaimana cara kerja filter anggaran per orang?',
        a: isEn
          ? 'You can set your maximum budget per person from Rp 10.000 to Rp 100.000 via the "Filter Budget" button. Places with average prices within your budget receive higher priority and special savings badges.'
          : 'Anda dapat menentukan batas anggaran per orang dari Rp 10.000 hingga Rp 100.000 melalui tombol "Filter Budget". Tempat yang rata-rata harganya sesuai atau di bawah anggaran Anda akan diprioritaskan dengan skor rekomendasi lebih tinggi dan badge hemat.'
      },
      {
        cat: 'contact',
        q: isEn ? 'How do I contact cafe managers directly?' : 'Bagaimana cara menghubungi pengelola kafe secara langsung?',
        a: isEn
          ? 'Open any cafe detail modal, then click the green "Contact Manager" button. You will be directed straight to the manager’s official WhatsApp chat with an automated greeting without exposing private phone numbers.'
          : 'Buka modal detail kafe mana saja, lalu klik tombol hijau "Hubungi Pengelola". Anda akan langsung diarahkan ke chat WhatsApp resmi admin kafe tersebut dengan pesan pembuka otomatis tanpa menampilkan nomor pribadi secara terbuka.'
      },
      {
        cat: 'partner',
        q: isEn ? 'How can cafe owners register or manage their listings?' : 'Bagaimana cara mendaftarkan kafe sebagai Mitra di MAMPIR?',
        a: isEn
          ? 'Cafe owners can access the "Admin & Mitra" tab in the sidebar. Once logged in as a Cafe Partner, you can edit operating hours, WhatsApp links, update menu highlights, and post promotional events/agendas.'
          : 'Pengelola kafe dapat mengakses menu "Admin & Mitra" di sidebar. Setelah masuk sebagai Mitra Kafe, Anda dapat mengelola jam buka, tautan WhatsApp, memperbarui menu andalan, serta menerbitkan agenda promosi atau live music.'
      },
      {
        cat: 'general',
        q: isEn ? 'Which regions are covered by MAMPIR?' : 'Wilayah mana saja yang dicakup oleh MAMPIR?',
        a: isEn
          ? 'MAMPIR covers Purwokerto City, Baturraden mountain slope cafes, North Purwokerto (Unsoed student hub), Sokaraja culinary center, East Purwokerto & Sumbang, as well as West & South Purwokerto.'
          : 'MAMPIR mencakup Purwokerto Kota, Baturraden (lereng Gunung Slamet & kafe alam), Purwokerto Utara (kawasan mahasiswa Unsoed), Sokaraja (pusat kuliner & soto), Purwokerto Timur & Sumbang, serta Purwokerto Barat & Selatan.'
      }
    ];

    container.innerHTML = `
      <div class="help-center-wrapper">
        <div>
          <h2 class="section-title">❓ ${typeof I18nService !== 'undefined' ? I18nService.t('help_title') : 'Pusat Bantuan & Edukasi MAMPIR'}</h2>
          <p style="font-size: 13px; color: var(--text-secondary); margin-top: 4px;">${typeof I18nService !== 'undefined' ? I18nService.t('help_subtitle') : 'Panduan lengkap jelajah kuliner Purwokerto dan integrasi mitra pengelola kafe.'}</p>
        </div>

        <div class="faq-search-box">
          <span>🔍</span>
          <input type="text" id="faq-search-input" placeholder="${typeof I18nService !== 'undefined' ? I18nService.t('help_search_ph') : 'Cari pertanyaan bantuan atau panduan...'}" oninput="window.App.filterFaqs(this.value)" />
        </div>

        <div class="faq-accordion-list" id="faq-accordion-list">
          ${faqs.map((f, idx) => `
            <div class="faq-accordion-item" id="faq-item-${idx}">
              <div class="faq-accordion-header" onclick="document.getElementById('faq-item-${idx}').classList.toggle('open')">
                <span>💡 ${f.q}</span>
                <span class="faq-arrow" style="transition: transform 0.2s;">▼</span>
              </div>
              <div class="faq-accordion-body">
                ${f.a}
              </div>
            </div>
          `).join('')}
        </div>

        <!-- Callout Banner Mitra Pengelola Kafe -->
        <div class="mitra-callout-card">
          <h3 style="font-size: 16px; font-weight: 800; color: var(--text-primary); display: flex; align-items: center; gap: 8px;">
            🤝 ${typeof I18nService !== 'undefined' ? I18nService.t('mitra_guide_box_title') : 'Ingin Kafe Anda Terdaftar di MAMPIR?'}
          </h3>
          <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.5;">
            ${typeof I18nService !== 'undefined' ? I18nService.t('mitra_guide_box_desc') : 'Daftarkan kafe Anda untuk menjangkau ribuan mahasiswa dan penikmat kuliner di Purwokerto.'}
          </p>
          <div style="display: flex; gap: 10px; flex-wrap: wrap; margin-top: 6px;">
            <button class="btn-primary" onclick="window.App.switchView('admin')">
              🛡️ ${typeof I18nService !== 'undefined' ? I18nService.t('btn_register_mitra') : 'Masuk / Daftar Akun Pengelola Kafe'}
            </button>
            <a href="https://wa.me/6281234567890?text=${encodeURIComponent('Halo Helpdesk MAMPIR, saya tertarik bermitra untuk kafe saya:')}" target="_blank"
               class="btn-cta-whatsapp" style="text-decoration: none;">
              💬 ${typeof I18nService !== 'undefined' ? I18nService.t('btn_contact_support') : 'Hubungi Helpdesk MAMPIR (WhatsApp)'}
            </a>
          </div>
        </div>
      </div>
    `;
  },

  filterFaqs(query) {
    const clean = (query || '').toLowerCase().trim();
    document.querySelectorAll('.faq-accordion-item').forEach(item => {
      const text = item.textContent.toLowerCase();
      item.style.display = text.includes(clean) ? 'block' : 'none';
    });
  },

  // ==================== ADMIN & MITRA DASHBOARD (Req 2) ====================
  renderAdminDashboardView(container) {
    const isPartner = StorageService.isPartnerOrAdmin();
    const session = StorageService.getUserSession();

    // 1. GATED ACCESS (RBAC) JIKA BUKAN ADMINISTRATOR
    if (!isPartner) {
      container.innerHTML = `
        <div class="admin-dashboard-wrapper">
          <div class="admin-gate-card">
            <div style="font-size: 52px; margin-bottom: 8px;">🛡️</div>
            <h2 style="font-size: 22px; font-weight: 800; color: var(--text-primary); margin-bottom: 6px;">
              ${window.t('admin_gate_title', 'Area Khusus Administrator MAMPIR')}
            </h2>
            <p style="font-size: 13px; color: var(--text-secondary); max-width: 500px; line-height: 1.6; margin-bottom: 16px;">
              ${window.t('admin_gate_desc', 'Halaman ini dilindungi sistem <strong>Role-Based Access Control (RBAC)</strong>. Pengguna umum <strong>tidak memiliki izin</strong> untuk mengelola data, mengubah kontak WhatsApp, atau mempublikasikan agenda kafe.')}
            </p>

            <!-- Status Akun Aktif Pengunjung -->
            <div style="background: rgba(239, 68, 68, 0.08); border: 1px solid rgba(239, 68, 68, 0.25); border-radius: var(--radius-sm); padding: 12px 18px; margin-bottom: 20px; max-width: 440px; text-align: left; margin-left: auto; margin-right: auto;">
              <div style="font-size: 13px; color: var(--text-primary); font-weight: 700; display: flex; align-items: center; justify-content: space-between; gap: 6px;">
                <span>👤 ${window.t('admin_status_your', 'Status Anda:')} <strong>${session.name || 'Pengunjung'}</strong></span>
                <span style="font-size: 10px; padding: 2px 8px; border-radius: 99px; background: #EF4444; color: white; font-weight: 800;">${window.t('admin_role_user', 'ROLE: USER (HANYA BACA)')}</span>
              </div>
              <p style="font-size: 11px; color: var(--text-secondary); margin: 6px 0 0 0; line-height: 1.4;">
                ${window.t('admin_gate_warning', '⛔ Anda hanya memiliki hak akses jelajah direktori. Untuk mengelola direktori kafe, silakan lakukan otentikasi menggunakan kredensial Administrator resmi di bawah.')}
              </p>
            </div>

            <!-- Alert Box Error -->
            <div id="admin-gate-error" style="display: none; padding: 10px 14px; border-radius: var(--radius-sm); margin-bottom: 16px; font-size: 12px; background: rgba(239, 68, 68, 0.15); border: 1px solid #EF4444; color: #EF4444; max-width: 440px; margin-left: auto; margin-right: auto; text-align: left;"></div>

            <!-- FORM LOGIN KHUSUS ADMIN -->
            <form onsubmit="event.preventDefault(); window.App.handleAdminGateLogin();" style="max-width: 440px; width: 100%; margin: 0 auto; display: flex; flex-direction: column; gap: 12px; text-align: left;">
              <div class="form-group" style="margin: 0;">
                <label style="font-size: 12px; font-weight: 700;">${window.t('admin_gate_email_label', 'Email / ID Administrator:')}</label>
                <input type="text" id="admin-gate-email" class="form-control" placeholder="admin@mampir.com" required autocomplete="username" />
              </div>
              <div class="form-group" style="margin: 0;">
                <label style="font-size: 12px; font-weight: 700;">${window.t('admin_gate_pass_label', 'Kata Sandi / Kunci Akses Admin:')}</label>
                <input type="password" id="admin-gate-password" class="form-control" placeholder="••••••••" required autocomplete="current-password" />
              </div>

              <button type="submit" id="btn-admin-gate-submit" class="btn-primary" style="width: 100%; justify-content: center; padding: 11px; margin-top: 4px;">
                ${window.t('admin_gate_btn_submit', '🔐 Verifikasi & Buka Panel Admin')}
              </button>

              <div style="font-size: 11px; color: var(--text-muted); background: var(--bg-surface); border: 1px dashed var(--border-color); padding: 8px 12px; border-radius: var(--radius-sm); line-height: 1.5; margin-top: 4px;">
                🔒 <strong>${window.t('admin_gate_notice_title', 'Akses Terbatas Administrator:')}</strong><br/>
                ${window.t('admin_gate_notice_desc', 'Masuk menggunakan akun Supabase Auth yang terdaftar dengan hak akses Administrator (role: admin) pada sistem MAMPIR.')}
              </div>
            </form>
          </div>
        </div>
      `;
      return;
    }

    // 2. DASHBOARD TERBUKA UNTUK ADMINISTRATOR RESMI
    const managedCafeId = StorageService.getPartnerCafeId();
    const currentCafe = this.getPlaceById(managedCafeId) || this.places[0];
    const events = StorageService.getCafeEvents(currentCafe?.id);

    container.innerHTML = `
      <div class="admin-dashboard-wrapper">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
          <div>
            <div style="display: flex; align-items: center; gap: 10px;">
              <h2 class="section-title" style="margin: 0;">🛡️ ${window.t('admin_panel_title', 'Panel Administrator Direktori MAMPIR')}</h2>
              <span style="font-size: 11px; padding: 3px 10px; background: rgba(16, 185, 129, 0.15); border: 1px solid #10B981; color: #10B981; border-radius: 99px; font-weight: 700;">
                Admin: ${session.name || 'Administrator'}
              </span>
            </div>
            <p style="font-size: 13px; color: var(--text-secondary); margin-top: 4px;">${window.t('admin_panel_subtitle', 'Kelola profil kafe, jam operasional, tautan WhatsApp pengelola, dan publikasikan agenda acara.')}</p>
          </div>
          <button class="btn-secondary" style="color: #EF4444;" onclick="window.App.logoutAdmin()">
            ${window.t('admin_btn_exit', '🔒 Keluar dari Panel Admin')}
          </button>
        </div>

        <!-- 3 Kartu Metrik -->
        <div class="admin-stat-grid">
          <div class="admin-stat-card">
            <small style="color: var(--text-muted);">${window.t('admin_stats_cafes', 'Kafe Dikelola')}</small>
            <div class="admin-stat-val">1</div>
            <span style="font-size: 11px; color: var(--text-secondary);">${currentCafe?.name}</span>
          </div>
          <div class="admin-stat-card">
            <small style="color: var(--text-muted);">${window.t('admin_stats_events', 'Agenda Aktif')}</small>
            <div class="admin-stat-val">${events.length}</div>
            <span style="font-size: 11px; color: var(--accent-gold);">${window.t('admin_stats_active_badge', 'Aktif di MAMPIR')}</span>
          </div>
          <div class="admin-stat-card">
            <small style="color: var(--text-muted);">${window.t('admin_stats_views', 'Total Interaksi')}</small>
            <div class="admin-stat-val">1.2k+</div>
            <span style="font-size: 11px; color: var(--accent-orange);">${window.t('admin_stats_visitors_badge', 'Pengunjung Bulan Ini')}</span>
          </div>
        </div>

        <!-- Pilih Kafe yang Dikelola -->
        <div style="display: flex; align-items: center; gap: 12px; padding: 12px 16px; background: var(--bg-card); border-radius: var(--radius-sm); border: 1px solid var(--border-color);">
          <label style="font-size: 13px; font-weight: bold; white-space: nowrap;">${window.t('admin_select_cafe_label', 'Pilih Kafe Anda:')}</label>
          <select id="admin-select-cafe" class="form-control" style="flex: 1;" onchange="window.App.switchManagedCafe(this.value)">
            ${this.places.map(p => `
              <option value="${p.id}" ${p.id === currentCafe?.id ? 'selected' : ''}>
                ${p.name} (${p.city})
              </option>
            `).join('')}
          </select>
        </div>

        <!-- Tabs Navigasi Mitra: Profil & Agenda -->
        <div class="admin-tab-nav">
          <button class="admin-tab-btn active" id="tab-btn-profile" onclick="window.App.switchAdminTab('profile')">
            🏢 ${window.t('admin_tab_profile', 'Profil & Kontak Kafe')}
          </button>
          <button class="admin-tab-btn" id="tab-btn-events" onclick="window.App.switchAdminTab('events')">
            🎉 ${window.t('admin_tab_events', 'Manajemen Agenda & Event')} (${events.length})
          </button>
        </div>

        <!-- TAB 1: EDIT PROFIL & KONTAK WHATSAPP KAFE (Req 1 & 2) -->
        <div id="admin-tab-content-profile">
          <form onsubmit="event.preventDefault(); window.App.saveCafeProfileChanges('${currentCafe?.id}');" style="display: flex; flex-direction: column; gap: 16px;">
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
              <div class="form-group">
                <label>${window.t('admin_form_cafe_name', 'Nama Kafe:')}</label>
                <input type="text" id="admin-cafe-name" class="form-control" value="${currentCafe?.name || ''}" required />
              </div>
              <div class="form-group">
                <label>${window.t('admin_form_wa_label', 'Nomor WhatsApp Pengelola (Format 62xxx):')}</label>
                <input type="text" id="admin-cafe-wa" class="form-control" value="${currentCafe?.whatsapp || '6281234567890'}" placeholder="Contoh: 6281234567890" required />
                <small style="font-size: 11px; color: var(--text-muted);">${window.t('admin_form_wa_hint', 'Digunakan untuk tombol langsung "Hubungi Pengelola" (tanpa menampilkan nomor mentah ke pengunjung).')}</small>
              </div>
            </div>

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px;">
              <div class="form-group">
                <label>${window.t('admin_form_region', 'Wilayah:')}</label>
                <select id="admin-cafe-city" class="form-control">
                  ${AppConfig.regions.filter(r => !r.includes('Semua')).map(r => `
                    <option value="${r}" ${r === currentCafe?.city ? 'selected' : ''}>${typeof I18nService !== 'undefined' ? I18nService.translateRegion(r) : r}</option>
                  `).join('')}
                </select>
              </div>
              <div class="form-group">
                <label>${window.t('admin_form_hours', 'Jam Operasional:')}</label>
                <input type="text" id="admin-cafe-hours" class="form-control" value="${currentCafe?.open_hours || '08.00 - 22.00 WIB'}" required />
              </div>
            </div>

            <div class="form-group">
              <label>${window.t('admin_form_address', 'Alamat Lengkap:')}</label>
              <input type="text" id="admin-cafe-address" class="form-control" value="${currentCafe?.address || ''}" required />
            </div>

            <div class="form-group">
              <label>${window.t('admin_form_desc', 'Deskripsi Kafe:')}</label>
              <textarea id="admin-cafe-desc" class="form-control" rows="3" required>${currentCafe?.description || ''}</textarea>
            </div>

            <div class="form-group">
              <label>${window.t('admin_form_facilities', 'Fasilitas (Pisahkan dengan koma):')}</label>
              <input type="text" id="admin-cafe-facilities" class="form-control" value="${(currentCafe?.facilities || []).join(', ')}" />
            </div>

            <button type="submit" class="btn-primary" style="padding: 12px; justify-content: center;">
              💾 ${window.t('btn_save_changes', 'Simpan Perubahan Profil')}
            </button>
          </form>
        </div>

        <!-- TAB 2: MANAJEMEN AGENDA & EVENT KAFE (Req 2) -->
        <div id="admin-tab-content-events" style="display: none;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px;">
            <h4 style="font-size: 14px; font-weight: 700;">${window.t('admin_events_list_title', `Daftar Agenda & Promo untuk ${currentCafe?.name}`, { cafe: currentCafe?.name || '' })}</h4>
            <button class="btn-primary" onclick="window.App.openCreateEventModal('${currentCafe?.id}')">
              ➕ ${window.t('btn_add_event', 'Tambah Agenda / Promo Baru')}
            </button>
          </div>

          <div class="admin-events-list">
            ${events.length === 0 ? `
              <div style="padding: 24px; text-align: center; color: var(--text-muted); background: var(--bg-card); border-radius: var(--radius-sm); border: 1px dashed var(--border-color);">
                ${window.t('admin_events_empty', 'Belum ada agenda atau promo aktif untuk kafe ini. Klik tombol di atas untuk menerbitkan event baru!')}
              </div>
            ` : events.map(e => `
              <div class="cafe-event-card" style="display: flex; justify-content: space-between; align-items: flex-start; gap: 14px;">
                <div style="flex: 1;">
                  <span class="cafe-event-badge">${e.badge || e.category}</span>
                  <h5 style="font-size: 15px; font-weight: bold; margin: 4px 0;">${e.title}</h5>
                  <div style="font-size: 12px; color: var(--accent-orange); margin-bottom: 4px;">⏰ ${e.date}</div>
                  <p style="font-size: 12px; color: var(--text-secondary);">${e.description}</p>
                </div>
                <button class="btn-secondary" style="color: #EF4444; padding: 6px 12px; font-size: 12px;" onclick="window.App.deleteEvent('${e.id}')">
                  🗑️ ${window.t('btn_delete', 'Hapus')}
                </button>
              </div>
            `).join('')}
          </div>
        </div>
      </div>
    `;
  },

  switchAdminTab(tabName) {
    const profContent = document.getElementById('admin-tab-content-profile');
    const evContent = document.getElementById('admin-tab-content-events');
    const profBtn = document.getElementById('tab-btn-profile');
    const evBtn = document.getElementById('tab-btn-events');

    if (tabName === 'profile') {
      if (profContent) profContent.style.display = 'block';
      if (evContent) evContent.style.display = 'none';
      if (profBtn) profBtn.classList.add('active');
      if (evBtn) evBtn.classList.remove('active');
    } else {
      if (profContent) profContent.style.display = 'none';
      if (evContent) evContent.style.display = 'block';
      if (profBtn) profBtn.classList.remove('active');
      if (evBtn) evBtn.classList.add('active');
    }
  },

  async handleAdminGateLogin() {
    const emailEl = document.getElementById('admin-gate-email');
    const passEl = document.getElementById('admin-gate-password');
    const errorEl = document.getElementById('admin-gate-error');
    const btn = document.getElementById('btn-admin-gate-submit');
    if (!emailEl || !passEl) return;

    const email = emailEl.value.trim().toLowerCase();
    const pass = passEl.value;

    if (errorEl) errorEl.style.display = 'none';
    if (btn) {
      btn.disabled = true;
      btn.textContent = window.t('admin_gate_verifying', 'Memverifikasi Akses Admin...');
    }

    // 1. Autentikasi kredensial resmi melalui Supabase Auth API
    const res = await AuthService.signIn(email, pass);
    if (!res.success) {
      if (btn) {
        btn.disabled = false;
        btn.textContent = window.t('admin_gate_btn_submit', '🔐 Verifikasi & Buka Panel Admin');
      }
      if (errorEl) {
        errorEl.style.display = 'block';
        errorEl.textContent = res.message || window.t('admin_gate_err_invalid', '❌ Email atau kata sandi tidak valid.');
      }
      return;
    }

    // 2. Verifikasi hak akses role admin pada backend database Supabase (is_admin RPC / user_profiles)
    const isAdmin = await AuthService.verifyAdminRole(res.token, res.user?.id);
    if (!isAdmin) {
      // Cabut sesi admin jika role akun bukan admin
      StorageService.setUserRole('user');
      if (btn) {
        btn.disabled = false;
        btn.textContent = window.t('admin_gate_btn_submit', '🔐 Verifikasi & Buka Panel Admin');
      }
      if (errorEl) {
        errorEl.style.display = 'block';
        errorEl.innerHTML = '⛔ <strong>Akses Ditolak:</strong> Akun ini berhasil masuk, namun tidak terdaftar sebagai Administrator pada basis data MAMPIR.';
      }
      this.updateUserProfileUI();
      return;
    }

    // 3. Hak akses admin terkonfirmasi
    StorageService.setUserRole('admin');
    this.updateUserProfileUI();
    this.render();
    this.showToast(window.t('toast_admin_login_success', '✅ Otentikasi Administrator Berhasil! Hak akses penuh aktif.'));
  },

  logoutAdmin() {
    StorageService.setUserRole('user');
    this.render();
    this.showToast(window.t('toast_admin_logout', '🔒 Keluar dari Panel Administrator. Kembali ke mode Pengguna biasa.'));
  },

  logoutPartner() {
    this.logoutAdmin();
  },

  switchManagedCafe(cafeId) {
    if (!StorageService.isAdmin()) return;
    StorageService.setUserRole('admin', cafeId);
    this.render();
  },

  async saveCafeProfileChanges(cafeId) {
    if (!StorageService.isAdmin()) {
      this.showToast(window.t('toast_admin_denied', '⛔ Akses ditolak: Hanya Administrator resmi yang berwenang!'));
      return;
    }

    const token = StorageService.getAuthToken();
    if (!token) {
      this.showToast('⛔ Sesi otentikasi admin tidak ditemukan. Silakan masuk ulang.');
      return;
    }

    const name = document.getElementById('admin-cafe-name')?.value?.trim();
    const wa = document.getElementById('admin-cafe-wa')?.value?.trim();
    const city = document.getElementById('admin-cafe-city')?.value;
    const hours = document.getElementById('admin-cafe-hours')?.value?.trim();
    const address = document.getElementById('admin-cafe-address')?.value?.trim();
    const desc = document.getElementById('admin-cafe-desc')?.value?.trim();
    const facilitiesRaw = document.getElementById('admin-cafe-facilities')?.value;
    const facilities = facilitiesRaw ? facilitiesRaw.split(',').map(s => s.trim()).filter(Boolean) : [];

    const saveBtn = document.querySelector('#admin-tab-content-profile button[type="submit"]');
    if (saveBtn) {
      saveBtn.disabled = true;
      saveBtn.textContent = '⏳ Menyimpan ke Supabase...';
    }

    const payload = {
      name,
      city,
      open_hours: hours,
      address,
      description: desc,
      facilities,
      override_fields: {
        name,
        city,
        open_hours: hours,
        address,
        description: desc,
        facilities,
        whatsapp: wa
      }
    };

    try {
      const response = await fetch(`${AppConfig.supabaseUrl}/rest/v1/places?id=eq.${encodeURIComponent(cafeId)}`, {
        method: 'PATCH',
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
          'Prefer': 'return=representation'
        },
        body: JSON.stringify(payload)
      });

      if (!response.ok) {
        const errData = await response.json().catch(() => ({}));
        throw new Error(errData.message || `HTTP ${response.status}`);
      }

      // Simpan juga di localStorage sebagai cache sinkron
      StorageService.saveCafeOverrides(cafeId, payload);
      const placeIdx = this.places.findIndex(p => p.id === cafeId);
      if (placeIdx !== -1) {
        this.places[placeIdx] = {
          ...this.places[placeIdx],
          ...payload,
          whatsapp: wa
        };
      }

      this.render();
      this.showToast(window.t('toast_admin_saved', '✅ Perubahan profil kafe berhasil disimpan ke Supabase!'));
    } catch (err) {
      console.error('Gagal sinkron profil kafe ke Supabase:', err);
      // Fallback simpan di cache lokal
      StorageService.saveCafeOverrides(cafeId, payload);
      this.showToast(`⚠️ Gagal sinkron ke database (${err.message}). Data disimpan ke cache lokal.`);
    } finally {
      if (saveBtn) {
        saveBtn.disabled = false;
        saveBtn.textContent = '💾 ' + window.t('btn_save_changes', 'Simpan Perubahan Profil');
      }
    }
  },

  openCreateEventModal(cafeId) {
    if (!StorageService.isAdmin()) {
      this.showToast(window.t('toast_admin_denied', '⛔ Akses ditolak: Anda harus masuk sebagai Administrator terlebih dahulu.'));
      return;
    }

    const modal = document.getElementById('modal-create-event');
    const select = document.getElementById('event-input-cafe-id');
    if (!modal) return;

    if (select) {
      select.innerHTML = this.places.map(p => `
        <option value="${p.id}" ${p.id === cafeId ? 'selected' : ''}>${p.name}</option>
      `).join('');
    }

    modal.classList.add('active');
  },

  saveNewEvent() {
    if (!StorageService.isAdmin()) {
      this.showToast(window.t('toast_admin_denied', '⛔ Akses ditolak: Hanya Administrator resmi yang berwenang menerbitkan agenda!'));
      return;
    }

    const cafeId = document.getElementById('event-input-cafe-id')?.value;
    const title = document.getElementById('event-input-title')?.value;
    const category = document.getElementById('event-input-category')?.value;
    const date = document.getElementById('event-input-date')?.value;
    const desc = document.getElementById('event-input-desc')?.value;
    const badge = document.getElementById('event-input-badge')?.value;

    const cafe = this.getPlaceById(cafeId);

    StorageService.addCafeEvent({
      placeId: cafeId,
      placeName: cafe?.name || 'Kafe Mitra',
      title,
      category,
      date,
      description: desc,
      badge: badge || category
    });

    const isEn = typeof I18nService !== 'undefined' && I18nService.getLanguage() === 'en';
    const notifTitle = isEn ? `🎉 New Event: ${title}` : `🎉 Agenda Baru: ${title}`;
    const notifMsg = isEn
      ? `${cafe?.name || 'Partner Cafe'} has just posted the event "${title}". Date: ${date}. Check schedule & set reminders!`
      : `${cafe?.name || 'Kafe Mitra'} baru saja menerbitkan agenda "${title}". Tanggal: ${date}. Cek jadwal dan pasang pengingat!`;
    const notifDate = window.t('notif_just_now', 'Baru saja');

    // Tambahkan notifikasi real-time untuk semua pengunjung (Req 7)
    StorageService.addNotification({
      placeId: cafeId,
      placeName: cafe?.name || 'Kafe Mitra',
      title: notifTitle,
      category: category,
      type: 'event',
      message: notifMsg,
      date: notifDate,
      read: false
    });
    this.updateNotificationBadge();

    this.closeModal('modal-create-event');
    this.render();
    this.showToast(window.t('toast_event_published', 'Agenda baru berhasil dipublikasikan!'));
  },

  deleteEvent(eventId) {
    if (!StorageService.isAdmin()) {
      this.showToast(window.t('toast_admin_denied', '⛔ Akses ditolak: Hanya Administrator resmi yang berwenang menghapus agenda!'));
      return;
    }

    if (confirm(window.t('confirm_delete_event', 'Yakin ingin menghapus agenda ini?'))) {
      StorageService.deleteCafeEvent(eventId);
      this.render();
      this.showToast(window.t('toast_event_deleted', 'Agenda berhasil dihapus.'));
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
  setTheme(theme) {
    StorageService.setTheme(theme);
    this.applyTheme(theme);
    this.render();
  },

  applyTheme(theme) {
    const isLight = theme === 'Terang';
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

