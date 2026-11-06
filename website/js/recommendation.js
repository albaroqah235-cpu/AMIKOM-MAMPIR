/**
 * MAMPIR Web - Recommendation & Utilities Service
 * Mengimplementasikan Algoritma Hybrid Content-Based & Budget Scoring
 * serta kalkulasi jarak Haversine dari Alun-Alun Purwokerto.
 */
const RecommendationService = {
  // Titik Alun-Alun Purwokerto
  CENTER_LAT: -7.4243,
  CENTER_LNG: 109.2303,

  /**
   * Menghitung jarak garis lurus (km) menggunakan Haversine Formula
   */
  calculateDistance(lat1, lon1, lat2 = this.CENTER_LAT, lon2 = this.CENTER_LNG) {
    if (!lat1 || !lon1) return 0;
    const R = 6371; // Radius bumi dalam kilometer
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return parseFloat((R * c).toFixed(1));
  },

  /**
   * Format mata uang Rupiah
   */
  formatRupiah(num) {
    return 'Rp ' + Number(num || 0).toLocaleString('id-ID');
  },

  /**
   * Format label harga (misal: "Mulai Rp 20.000")
   */
  formatPrice(place) {
    if (!place) return 'Rp 0';
    const min = place.min_price || 0;
    const max = place.max_price || min;
    if (min === max || max === 0) {
      return this.formatRupiah(min);
    }
    return `Mulai ${this.formatRupiah(min)}`;
  },

  /**
   * Mengambil rekomendasi tempat berdasarkan budget, preferensi fasilitas,
   * wilayah terpilih, dan query opsional.
   */
  getRecommendations({
    allPlaces = [],
    userBudget = 25000,
    selectedRegion = 'Purwokerto Kota',
    selectedCategory = 'Semua',
    userPreferences = ['WiFi', 'Colokan'],
    searchQuery = ''
  }) {
    if (!allPlaces || allPlaces.length === 0) return [];

    let candidates = [...allPlaces];

    // 1. Filter Regional
    if (selectedRegion && !selectedRegion.toLowerCase().includes('semua')) {
      const regionClean = selectedRegion.split('(')[0].trim().toLowerCase();
      const filtered = candidates.filter(p => {
        const c = (p.city || '').toLowerCase();
        const a = (p.address || '').toLowerCase();
        return c.includes(regionClean) || a.includes(regionClean);
      });
      if (filtered.length > 0) candidates = filtered;
    }

    // 2. Filter Kategori
    if (selectedCategory && selectedCategory !== 'Semua') {
      const catLower = selectedCategory.toLowerCase();
      const filtered = candidates.filter(p => (p.category || '').toLowerCase().includes(catLower));
      if (filtered.length > 0) candidates = filtered;
    }

    const queryTokens = (searchQuery || '').trim().toLowerCase().split(/\s+/).filter(Boolean);

    const scored = candidates.map(place => {
      const avgPrice = place.avg_price || Math.round((place.min_price + place.max_price) / 2) || 25000;
      const rating = place.rating || 4.5;

      // A. Skor Budget (0 - 35)
      let budgetScore = 0;
      if (avgPrice <= userBudget) {
        budgetScore = 35.0 - ((userBudget - avgPrice) / Math.max(userBudget, 1)) * 10.0;
        budgetScore = Math.max(25.0, Math.min(35.0, budgetScore));
      } else {
        const ratio = avgPrice / Math.max(userBudget, 1);
        budgetScore = Math.max(0.0, 35.0 - (ratio - 1.0) * 40.0);
      }

      // B. Skor Kemiripan Fasilitas & Kata Kunci (0 - 45)
      const placeFacilities = (place.facilities || []).map(f => f.toLowerCase());
      let facilityMatches = 0;
      userPreferences.forEach(pref => {
        if (placeFacilities.includes(pref.toLowerCase())) facilityMatches++;
      });
      const facilityScore = userPreferences.length > 0
        ? (facilityMatches / userPreferences.length) * 30.0
        : 20.0;

      let keywordScore = 0;
      if (queryTokens.length > 0) {
        const combined = `${place.name} ${place.description || ''} ${place.address || ''} ${place.category || ''}`.toLowerCase();
        let matches = 0;
        queryTokens.forEach(token => {
          if (combined.includes(token)) matches++;
        });
        keywordScore = (matches / queryTokens.length) * 15.0;
      } else {
        keywordScore = 15.0;
      }
      const similarityScore = facilityScore + keywordScore;

      // C. Skor Rating & Popularitas (0 - 20)
      const ratingScore = (rating / 5.0) * 20.0;

      const totalScore = parseFloat((budgetScore + similarityScore + ratingScore).toFixed(1));

      // D. Badge Alasan Cerdas
      let reasonBadge = '';
      if (avgPrice <= userBudget * 0.7) {
        reasonBadge = `Sangat Hemat (${this.formatRupiah(avgPrice)}) • Rating ${rating}`;
      } else if (avgPrice <= userBudget) {
        reasonBadge = `Pas di Kantong (${this.formatRupiah(avgPrice)}) • Rating ${rating}`;
      } else {
        reasonBadge = `Pilihan Populer • Rating ${rating} (${place.review_count || 100}+ ulasan)`;
      }

      const distance = this.calculateDistance(place.latitude, place.longitude);

      return {
        place: { ...place, distance },
        totalScore,
        budgetScore,
        similarityScore,
        ratingScore,
        reasonBadge
      };
    });

    scored.sort((a, b) => b.totalScore - a.totalScore);
    return scored;
  }
};

