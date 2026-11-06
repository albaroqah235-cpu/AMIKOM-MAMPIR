/**
 * MAMPIR Web - Storage Service (LocalStorage)
 * Mengelola penyimpanan lokal preferensi pengguna, bookmark favorit,
 * riwayat pencarian, dan sesi autentikasi.
 */
const StorageService = {
  KEYS: {
    FIRST_LAUNCH: 'mampir_first_launch',
    BUDGET: 'user_budget',
    REGION: 'selected_region',
    PREFERENCES: 'user_preferences',
    SEARCH_HISTORY: 'search_history',
    FAVORITES: 'favorite_places',
    IS_LOGGED_IN: 'is_logged_in',
    IS_GUEST: 'is_guest_mode',
    USER_NAME: 'user_name',
    USER_EMAIL: 'user_email',
    THEME: 'setting_theme',
    NOTIFICATION: 'setting_notification_enabled'
  },

  isFirstLaunch() {
    const val = localStorage.getItem(this.KEYS.FIRST_LAUNCH);
    return val === null; // true jika pertama kali buka
  },

  setFirstLaunchComplete() {
    localStorage.setItem(this.KEYS.FIRST_LAUNCH, 'false');
  },

  getBudget() {
    const val = localStorage.getItem(this.KEYS.BUDGET);
    return val ? parseInt(val, 10) : 25000;
  },

  setBudget(budget) {
    localStorage.setItem(this.KEYS.BUDGET, budget.toString());
  },

  getSelectedRegion() {
    return localStorage.getItem(this.KEYS.REGION) || 'Purwokerto Kota';
  },

  setSelectedRegion(region) {
    localStorage.setItem(this.KEYS.REGION, region);
  },

  getUserPreferences() {
    try {
      const val = localStorage.getItem(this.KEYS.PREFERENCES);
      return val ? JSON.parse(val) : ['WiFi', 'Colokan'];
    } catch {
      return ['WiFi', 'Colokan'];
    }
  },

  setUserPreferences(prefs) {
    localStorage.setItem(this.KEYS.PREFERENCES, JSON.stringify(prefs));
  },

  getFavorites() {
    try {
      const val = localStorage.getItem(this.KEYS.FAVORITES);
      return val ? JSON.parse(val) : [];
    } catch {
      return [];
    }
  },

  isFavorite(id) {
    return this.getFavorites().includes(id);
  },

  toggleFavorite(id) {
    let favs = this.getFavorites();
    if (favs.includes(id)) {
      favs = favs.filter(favId => favId !== id);
    } else {
      favs.push(id);
    }
    localStorage.setItem(this.KEYS.FAVORITES, JSON.stringify(favs));
    return favs.includes(id);
  },

  getSearchHistory() {
    try {
      const val = localStorage.getItem(this.KEYS.SEARCH_HISTORY);
      return val ? JSON.parse(val) : [];
    } catch {
      return [];
    }
  },

  addSearchHistory(query) {
    const clean = query.trim();
    if (!clean) return;
    let list = this.getSearchHistory().filter(q => q.toLowerCase() !== clean.toLowerCase());
    list.unshift(clean);
    if (list.length > 10) list = list.slice(0, 10);
    localStorage.setItem(this.KEYS.SEARCH_HISTORY, JSON.stringify(list));
  },

  removeSearchHistory(query) {
    let list = this.getSearchHistory().filter(q => q.toLowerCase() !== query.toLowerCase());
    localStorage.setItem(this.KEYS.SEARCH_HISTORY, JSON.stringify(list));
  },

  clearSearchHistory() {
    localStorage.removeItem(this.KEYS.SEARCH_HISTORY);
  },

  getUserSession() {
    const isLoggedIn = localStorage.getItem(this.KEYS.IS_LOGGED_IN) === 'true';
    const isGuest = localStorage.getItem(this.KEYS.IS_GUEST) === 'true';
    return {
      isLoggedIn,
      isGuest,
      name: localStorage.getItem(this.KEYS.USER_NAME) || (isGuest ? 'Tamu Purwokerto' : 'Pengguna MAMPIR'),
      email: localStorage.getItem(this.KEYS.USER_EMAIL) || ''
    };
  },

  setUserSession({ name, email, isGuest = false }) {
    localStorage.setItem(this.KEYS.IS_LOGGED_IN, isGuest ? 'false' : 'true');
    localStorage.setItem(this.KEYS.IS_GUEST, isGuest ? 'true' : 'false');
    localStorage.setItem(this.KEYS.USER_NAME, name);
    localStorage.setItem(this.KEYS.USER_EMAIL, email || '');
  },

  clearUserSession() {
    localStorage.removeItem(this.KEYS.IS_LOGGED_IN);
    localStorage.removeItem(this.KEYS.IS_GUEST);
    localStorage.removeItem(this.KEYS.USER_NAME);
    localStorage.removeItem(this.KEYS.USER_EMAIL);
  },

  getTheme() {
    return localStorage.getItem(this.KEYS.THEME) || 'Gelap';
  },

  setTheme(theme) {
    localStorage.setItem(this.KEYS.THEME, theme);
  }
};

