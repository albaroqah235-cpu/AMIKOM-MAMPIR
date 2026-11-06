/**
 * MAMPIR Web - Main Application Controller
 * Mengintegrasikan State Katalog, Supabase REST API, Algoritma Rekomendasi,
 * Peta Interaktif Leaflet, Modal Dialog, dan Web Admin Dashboard.
 */

window.App = {
  // State Utama
  places: [],
  filteredPlaces: [],
  currentView: 'beranda', // 'beranda', 'cari', 'favorit', 'pengaturan'
  selectedRegion: 'Purwokerto Kota',
  selectedCategory: 'Semua',
  userBudget: 25000,
  userPreferences: ['WiFi', 'Colokan'],
  searchQuery: '',
  sortBy: 'rekomendasi', // 'rekomendasi', 'rating', 'jarak', 'harga_murah'
  isApiOnline: false,

  async init() {
    console.log('Inisialisasi MAMPIR Web...');

    // Load initial user preferences from LocalStorage
    this.selectedRegion = StorageService.getSelectedRegion();
    this.userBudget = StorageService.getBudget();
    this.userPreferences = StorageService.getUserPreferences();

    // Setup Theme
    this.applyTheme(StorageService.getTheme());

    // Setup UI Controls & Listeners
    this.bindHeaderControls();
    this.bindSidebarNav();
    this.bindFilterModal();
    this.bindAuthModal();

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
  },

  /**
   * Mengambil data tempat kuliner dari Supabase REST API dengan offline fallback
   */
  async fetchPlaces() {
    const statusTextEl = document.getElementById('api-status-text');
    const statusDotEl = document.getElementById('api-status-dot');

    try {
      const response = await fetch(AppConfig.placesEndpoint, {
        headers: AppConfig.headers,
        cache: 'no-store'
      });

      if (response.ok) {
        const data = await response.json();
        if (Array.isArray(data) && data.length > 0) {
          this.places = data;
          this.isApiOnline = true;
          if (statusTextEl) statusTextEl.textContent = `Supabase REST API (${this.places.length} Tempat)`;
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
      if (statusTextEl) statusTextEl.textContent = `Offline Fallback (${this.places.length} Tempat)`;
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
    let list = [...this.places];

    // Jika di tab favorit, ambil hanya tempat yang di-bookmark
    if (this.currentView === 'favorit') {
      const favIds = StorageService.getFavorites();
      list = list.filter(p => favIds.includes(p.id));
    }

    // Rekomendasi scoring
    const recommendations = RecommendationService.getRecommendations({
      allPlaces: list,
      userBudget: this.userBudget,
      selectedRegion: this.selectedRegion,
      selectedCategory: this.selectedCategory,
      userPreferences: this.userPreferences,
      searchQuery: this.searchQuery
    });

    let result = recommendations.map(r => ({
      ...r.place,
      recommendationScore: r.totalScore,
      reasonBadge: r.reasonBadge
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

    const processed = this.getProcessedPlaces();

    // Render Markers on Map
    MapController.renderMarkers(processed, (place) => {
      this.openPlaceDetail(place.id);
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
      html += this.renderCategoryFilterBar();
    }

    // Grid of cards
    if (processed.length === 0) {
      html += `
        <div class="empty-state">
          <div class="empty-state-icon">🍽️</div>
          <h3>Tidak ada tempat yang cocok</h3>
          <p>Coba sesuaikan filter wilayah, kategori, atau naikkan batas anggaran Anda.</p>
          <button class="btn-primary" onclick="window.App.resetFilters()">Reset Filter</button>
        </div>
      `;
    } else {
      html += `<div class="section-header">
        <h3 class="section-title">
          <span>${this.getSectionTitle()}</span>
          <small style="font-size: 13px; color: var(--text-secondary); font-weight: normal;">(${processed.length} tempat ditemukan)</small>
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
    if (this.currentView === 'cari') return 'Hasil Pencarian';
    if (this.currentView === 'favorit') return 'Daftar Tempat Favorit Anda';
    return 'Rekomendasi Tempat Kuliner & Nongkrong';
  },

  renderFeaturedCard(place) {
    if (!place) return '';
    const isFav = StorageService.isFavorite(place.id);
    return `
      <div class="featured-card" onclick="window.App.openPlaceDetail('${place.id}')">
        <div class="featured-image-container">
          <img src="${place.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${place.name}" class="featured-image" />
          <div class="featured-overlay"></div>
          <div class="featured-badges">
            <span class="badge-featured">Rekomendasi Utama</span>
            <span class="badge-score">⭐ ${place.rating || 4.8}</span>
          </div>
          <button class="featured-bookmark-btn ${isFav ? 'active' : ''}" 
                  onclick="event.stopPropagation(); window.App.toggleFav('${place.id}')">
            ${isFav ? '❤️' : '🤍'}
          </button>
          <div class="featured-content">
            <div class="featured-reason">${place.reasonBadge || 'Paling cocok dengan budget Anda'}</div>
            <h2 class="featured-title">${place.name}</h2>
            <div class="featured-meta">
              <span>📍 ${place.city} (${place.distance || 0} km dari Alun-Alun)</span>
              <span>💰 ${RecommendationService.formatPrice(place)}</span>
              <span>🏷️ ${place.category}</span>
            </div>
          </div>
        </div>
      </div>
    `;
  },

  renderCategoryFilterBar() {
    const cats = ['Semua', 'Cafe', 'Warkop', 'Restoran'];
    return `
      <div class="category-pills">
        ${cats.map(cat => `
          <button class="category-pill ${this.selectedCategory === cat ? 'active' : ''}"
                  onclick="window.App.selectCategory('${cat}')">
            ${cat === 'Semua' ? '✨ Semua Tempat' : cat === 'Cafe' ? '☕ Cafe' : cat === 'Warkop' ? '🍵 Warkop' : '🍽️ Restoran'}
          </button>
        `).join('')}
      </div>
    `;
  },

  renderPlaceCard(place) {
    const isFav = StorageService.isFavorite(place.id);
    const facilities = (place.facilities || []).slice(0, 3);

    return `
      <div class="place-card" onclick="window.App.openPlaceDetail('${place.id}')">
        <div class="place-card-image-wrapper">
          <img src="${place.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${place.name}" class="place-card-img" loading="lazy" />
          <button class="place-card-fav-btn ${isFav ? 'active' : ''}"
                  onclick="event.stopPropagation(); window.App.toggleFav('${place.id}')">
            ${isFav ? '❤️' : '🤍'}
          </button>
          <span class="place-card-category-tag">${place.category || 'Cafe'}</span>
        </div>
        <div class="place-card-body">
          <div class="place-card-header">
            <h4 class="place-card-title">${place.name}</h4>
            <div class="place-card-rating">⭐ ${place.rating || 4.5}</div>
          </div>
          <div class="place-card-location">📍 ${place.city} • ${place.distance || 0} km</div>
          <div class="place-card-reason">${place.reasonBadge || 'Pas di kantong'}</div>
          <div class="place-card-facilities">
            ${facilities.map(f => `<span class="facility-chip-mini">${f}</span>`).join('')}
          </div>
          <div class="place-card-footer">
            <div class="place-card-price">
              ${RecommendationService.formatPrice(place)}
            </div>
            <div class="place-card-actions">
              <button class="btn-card-locate" onclick="event.stopPropagation(); window.App.focusMap('${place.id}', ${place.latitude}, ${place.longitude})">
                🗺️ Pin Peta
              </button>
            </div>
          </div>
        </div>
      </div>
    `;
  },

  renderSearchTabHeader() {
    const history = StorageService.getSearchHistory();
    return `
      <div class="search-tab-view">
        <div class="history-section">
          <div class="history-header">
            <span>Riwayat Pencarian Terakhir</span>
            ${history.length > 0 ? `<button class="btn-clear-history" onclick="window.App.clearSearchHistory()">Hapus Semua</button>` : ''}
          </div>
          <div class="history-chips">
            ${history.length === 0 ? `<span style="font-size: 12px; color: var(--text-muted);">Belum ada riwayat pencarian.</span>` : ''}
            ${history.map(item => `
              <div class="history-chip" onclick="window.App.applySearchQuery('${item}')">
                <span>${item}</span>
                <span class="chip-remove" onclick="event.stopPropagation(); window.App.removeSearchHistoryItem('${item}')">×</span>
              </div>
            `).join('')}
          </div>
        </div>
        <div class="results-meta-bar">
          <span>Menampilkan hasil pencarian untuk: <strong>"${this.searchQuery || 'Semua Tempat'}"</strong></span>
          <select class="sort-select" onchange="window.App.setSort(this.value)">
            <option value="rekomendasi" ${this.sortBy === 'rekomendasi' ? 'selected' : ''}>🎯 Paling Direkomendasikan</option>
            <option value="rating" ${this.sortBy === 'rating' ? 'selected' : ''}>⭐ Rating Tertinggi</option>
            <option value="jarak" ${this.sortBy === 'jarak' ? 'selected' : ''}>📍 Jarak Terdekat</option>
            <option value="harga_murah" ${this.sortBy === 'harga_murah' ? 'selected' : ''}>💰 Harga Termurah</option>
          </select>
        </div>
      </div>
    `;
  },

  renderFavoritesHeader(count) {
    const cats = ['Semua', 'Cafe', 'Warkop', 'Restoran'];
    return `
      <div style="margin-bottom: 20px;">
        <div class="category-pills" style="margin-bottom: 12px;">
          ${cats.map(cat => `
            <button class="category-pill ${this.selectedCategory === cat ? 'active' : ''}"
                    onclick="window.App.selectCategory('${cat}')">
              ${cat}
            </button>
          `).join('')}
        </div>
        <p style="font-size: 13px; color: var(--text-secondary);">
          Tersimpan ${count} tempat di penyimpanan browser lokal Anda (❤️).
        </p>
      </div>
    `;
  },

  renderSettingsView(container) {
    const session = StorageService.getUserSession();
    const currentTheme = StorageService.getTheme();

    container.innerHTML = `
      <div style="max-width: 600px; display: flex; flex-direction: column; gap: 24px;">
        <h2 class="section-title">⚙️ Pengaturan Aplikasi MAMPIR</h2>

        <div class="history-section">
          <h4 style="font-size: 14px; margin-bottom: 8px;">Informasi Akun</h4>
          <p style="font-size: 13px; color: var(--text-secondary);">Masuk sebagai: <strong>${session.name}</strong> (${session.isGuest ? 'Mode Tamu' : session.email})</p>
          <div style="margin-top: 12px; display: flex; gap: 10px;">
            <button class="btn-secondary" onclick="window.App.openAuthModal()">Ganti Akun</button>
            <button class="btn-secondary" style="color: #EF4444;" onclick="window.App.logout()">Keluar (Sign Out)</button>
          </div>
        </div>

        <div class="history-section">
          <h4 style="font-size: 14px; margin-bottom: 8px;">Tema Tampilan</h4>
          <div style="display: flex; gap: 12px;">
            <button class="category-pill ${currentTheme === 'Gelap' ? 'active' : ''}" onclick="window.App.setTheme('Gelap')">🌙 Mode Gelap</button>
            <button class="category-pill ${currentTheme === 'Terang' ? 'active' : ''}" onclick="window.App.setTheme('Terang')">☀️ Mode Terang</button>
          </div>
        </div>

        <div class="history-section">
          <h4 style="font-size: 14px; margin-bottom: 8px;">Tentang MAMPIR Web</h4>
          <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.6;">
            <strong>MAMPIR</strong>: Makan, Ampir, Pilih, dan Rekomendasi Tempat Makan & Nongkrong di Kota Purwokerto dan Sekitarnya.<br/>
            Edisi Multiplatform Web v2.0 • PML 2026.
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
    const regSelect = document.getElementById('global-region-select');
    if (regSelect) regSelect.value = 'Purwokerto Kota';
    const sInput = document.getElementById('global-search-input');
    if (sInput) sInput.value = '';
    this.render();
  },

  // ==================== DETAIL MODAL ====================
  openPlaceDetail(placeId) {
    const place = this.places.find(p => p.id === placeId);
    if (!place) return;

    const modal = document.getElementById('modal-place-detail');
    const body = document.getElementById('modal-place-detail-body');
    if (!modal || !body) return;

    const isFav = StorageService.isFavorite(place.id);
    const facilities = place.facilities || [];
    const menuHighlights = place.menu_highlights || [];
    const distance = RecommendationService.calculateDistance(place.latitude, place.longitude);

    body.innerHTML = `
      <img src="${place.image_url || 'assets/images/beranda_mockup.jpeg'}" alt="${place.name}" class="detail-modal-img" />
      <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px;">
        <div>
          <span class="badge-cat">${place.category}</span>
          <h2 style="font-size: 22px; margin-top: 6px;">${place.name}</h2>
          <p style="color: var(--text-secondary); font-size: 13px;">📍 ${place.address || place.city}</p>
        </div>
        <button class="place-card-fav-btn ${isFav ? 'active' : ''}" style="position: static;"
                onclick="window.App.toggleFav('${place.id}'); window.App.openPlaceDetail('${place.id}');">
          ${isFav ? '❤️' : '🤍'}
        </button>
      </div>

      <div style="display: flex; gap: 16px; margin-bottom: 18px; padding: 12px; background: var(--bg-card); border-radius: var(--radius-sm); border: 1px solid var(--border-color);">
        <div><small style="color: var(--text-muted);">Rating</small><div style="font-weight: bold; color: #FBBF24;">⭐ ${place.rating} (${place.review_count || 100}+)</div></div>
        <div><small style="color: var(--text-muted);">Rentang Harga</small><div style="font-weight: bold; color: var(--accent-orange);">${RecommendationService.formatPrice(place)}</div></div>
        <div><small style="color: var(--text-muted);">Jarak</small><div style="font-weight: bold;">${distance} km</div></div>
        <div><small style="color: var(--text-muted);">Jam Buka</small><div style="font-weight: bold;">${place.open_hours || '08.00 - 22.00'}</div></div>
      </div>

      <div class="detail-section">
        <h4>Deskripsi</h4>
        <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.6;">${place.description || 'Tempat kuliner favorit yang nyaman di kawasan Purwokerto.'}</p>
      </div>

      <div class="detail-section">
        <h4>Fasilitas Tersedia</h4>
        <div style="display: flex; gap: 6px; flex-wrap: wrap;">
          ${facilities.map(f => `<span class="category-pill" style="padding: 4px 10px; font-size: 11px;">✓ ${f}</span>`).join('')}
        </div>
      </div>

      <div class="detail-section">
        <h4>Menu Andalan</h4>
        <div class="menu-highlight-list">
          ${menuHighlights.map(m => `
            <div class="menu-item-row">
              <span>☕ ${m.name}</span>
              <strong>${RecommendationService.formatRupiah(m.price)}</strong>
            </div>
          `).join('')}
        </div>
      </div>

      <div style="margin-top: 24px; display: flex; gap: 12px;">
        <a href="https://www.google.com/maps/dir/?api=1&destination=${place.latitude},${place.longitude}" target="_blank"
           class="btn-primary" style="flex: 1; text-align: center; text-decoration: none; justify-content: center;">
          🗺️ Buka Rute di Google Maps
        </a>
      </div>
    `;

    modal.classList.add('active');
  },

  closeModal(modalId) {
    const el = document.getElementById(modalId);
    if (el) el.classList.remove('active');
  },

  // ==================== BUDGET FILTER MODAL ====================
  bindFilterModal() {
    const openBtn = document.getElementById('btn-open-budget-modal');
    const modal = document.getElementById('modal-budget-filter');
    const slider = document.getElementById('filter-budget-slider');
    const display = document.getElementById('filter-budget-val-display');

    if (openBtn && modal) {
      openBtn.addEventListener('click', () => {
        if (slider) slider.value = this.userBudget;
        if (display) display.textContent = RecommendationService.formatRupiah(this.userBudget);
        modal.classList.add('active');
      });
    }

    if (slider && display) {
      slider.addEventListener('input', (e) => {
        display.textContent = RecommendationService.formatRupiah(e.target.value);
      });
    }

    const applyBtn = document.getElementById('btn-apply-budget-filter');
    if (applyBtn) {
      applyBtn.addEventListener('click', () => {
        if (slider) {
          this.userBudget = parseInt(slider.value, 10);
          StorageService.setBudget(this.userBudget);
        }
        this.closeModal('modal-budget-filter');
        this.render();
        this.showToast(`Filter diterapkan: Budget ${RecommendationService.formatRupiah(this.userBudget)}`);
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
    this.showToast('Masuk sebagai Tamu.');
    this.render();
  },

  logout() {
    AuthService.signOut();
    this.updateUserProfileUI();
    this.showToast('Berhasil keluar.');
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

