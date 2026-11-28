import 'dart:math' as math;
import '../models/place_model.dart';

/// Hasil rekomendasi yang menyertakan tempat, skor total, dan badge alasan.
class RecommendationResult {
  final PlaceModel place;
  final double totalScore;
  final double budgetScore;
  final double similarityScore;
  final double ratingScore;
  final String reasonBadge;

  RecommendationResult({
    required this.place,
    required this.totalScore,
    required this.budgetScore,
    required this.similarityScore,
    required this.ratingScore,
    required this.reasonBadge,
  });
}

/// ============================================================
/// RECOMMENDATION SERVICE — HYBRID CONTENT-BASED & BUDGET SCORING
/// ============================================================
/// Mengimplementasikan algoritma rekomendasi cerdas sesuai Spec 6:
/// 1. Skor Efisiensi Budget (0 - 35 poin)
/// 2. Reference Place & Keyword Similarity (0 - 45 poin)
/// 3. Rating & Popularity Boost (0 - 20 poin)
/// ============================================================
class RecommendationService {
  /// Merekomendasikan tempat berdasarkan budget, input pencarian/acuan,
  /// preferensi fasilitas, dan filter wilayah.
  static List<RecommendationResult> getRecommendations({
    required List<PlaceModel> allPlaces,
    required int userBudget,
    String userInputQuery = '',
    List<String> userPreferences = const [],
    String? selectedRegion,
    String? selectedCategory,
  }) {
    if (allPlaces.isEmpty) return [];

    // Filter regional jika dispesifikasikan (kecuali 'Semua' / 'Semua Wilayah')
    List<PlaceModel> candidatePlaces = allPlaces;
    if (selectedRegion != null &&
        selectedRegion.isNotEmpty &&
        !selectedRegion.toLowerCase().contains('semua')) {
      final regionKeywords = getRegionKeywords(selectedRegion);
      candidatePlaces = candidatePlaces.where((place) {
        final pCity = place.city.toLowerCase();
        final pAddr = place.address.toLowerCase();
        final pName = place.name.toLowerCase();
        final combined = '$pCity $pAddr $pName';
        return regionKeywords.any(
          (kw) => combined.contains(kw),
        );
      }).toList();
    }

    // Filter khusus Cafe & Coffee Shop (Aplikasi Khusus Cafe)
    candidatePlaces = candidatePlaces.where((place) {
      final cat = place.category.toLowerCase();
      final name = place.name.toLowerCase();
      return cat.contains('cafe') ||
          cat.contains('coffee') ||
          name.contains('cafe') ||
          name.contains('coffee') ||
          name.contains('kopi') ||
          name.contains('kafe') ||
          name.contains('bistro') ||
          name.contains('roastery');
    }).toList();

    // Filter kategori opsional jika dipilih di UI
    if (selectedCategory != null &&
        selectedCategory.isNotEmpty &&
        selectedCategory != 'Semua' &&
        selectedCategory != 'Lainnya') {
      final sel = selectedCategory.toLowerCase();
      bool matchesCategory(PlaceModel p) {
        final cat = p.category.toLowerCase();
        final name = p.name.toLowerCase();
        final desc = p.description.toLowerCase();
        if (cat.contains(sel) || sel.contains(cat)) return true;
        if (name.contains(sel)) return true;
        if (sel == 'resto' || sel == 'restoran') {
          return cat.contains('resto') ||
              cat.contains('restoran') ||
              name.contains('resto') ||
              name.contains('rumah makan') ||
              name.contains('restoran') ||
              name.contains('kitchen') ||
              desc.contains('restoran');
        }
        if (sel == 'warung makan' ||
            sel == 'warkop' ||
            sel.contains('warung') ||
            sel.contains('warkop')) {
          return cat.contains('warung') ||
              cat.contains('warkop') ||
              name.contains('warung') ||
              name.contains('warkop') ||
              name.contains('angkringan') ||
              name.contains('warmindo') ||
              name.contains('soto') ||
              name.contains('bakso') ||
              name.contains('makan');
        }
        if (sel == 'cafe' || sel == 'coffee shop') {
          return cat.contains('cafe') ||
              cat.contains('coffee') ||
              cat.contains('kopi') ||
              name.contains('cafe') ||
              name.contains('kafe') ||
              name.contains('coffee') ||
              name.contains('kopi') ||
              desc.contains('cafe');
        }
        if (sel == 'bakery') {
          return cat.contains('bakery') ||
              cat.contains('roti') ||
              cat.contains('kue') ||
              name.contains('roti') ||
              name.contains('bakery') ||
              name.contains('kue') ||
              name.contains('getuk') ||
              name.contains('serabi') ||
              name.contains('nopia') ||
              desc.contains('roti');
        }
        if (sel == 'fast food') {
          return cat.contains('fast food') ||
              name.contains('burger') ||
              name.contains('pizza') ||
              name.contains('fried chicken') ||
              name.contains('cepat saji');
        }
        return p.facilities.any((f) => f.toLowerCase().contains(sel));
      }

      candidatePlaces = candidatePlaces.where(matchesCategory).toList();
    }

    // Filter budget maksimal ketat:
    // Sesuai permintaan pengguna: Jika budget maksimal ditentukan (misal 10k, < 150.000),
    // maka HANYA tempat yang harga minimalnya <= userBudget yang boleh muncul.
    // Tempat dengan harga di atas budget pengguna DILARANG muncul.
    if (userBudget > 0 && userBudget < 150000) {
      candidatePlaces = candidatePlaces.where((place) => place.minPrice <= userBudget).toList();
    }

    // Deteksi apakah user memasukkan nama tempat acuan spesifik
    PlaceModel? referencePlace;
    final cleanQuery = userInputQuery.trim().toLowerCase();
    if (cleanQuery.isNotEmpty) {
      for (final p in allPlaces) {
        if (p.name.toLowerCase() == cleanQuery ||
            cleanQuery.contains(p.name.toLowerCase()) ||
            p.name.toLowerCase().contains(cleanQuery)) {
          referencePlace = p;
          break;
        }
      }
    }

    final queryTokens = _tokenize(cleanQuery);
    final results = <RecommendationResult>[];

    for (final place in candidatePlaces) {
      // 1. Budget Score (0 - 35 poin)
      final budgetScore = _calculateBudgetScore(place, userBudget);

      // 2. Similarity Score (0 - 45 poin)
      final simScore = _calculateSimilarityScore(
        place: place,
        queryTokens: queryTokens,
        referencePlace: referencePlace,
        userPreferences: userPreferences,
      );

      // 3. Rating & Popularity Boost (0 - 20 poin)
      final ratingScore = (place.rating.clamp(0.0, 5.0) / 5.0) * 20.0;

      final totalScore = budgetScore + simScore + ratingScore;

      final reason = _generateReasonBadge(
        place: place,
        userBudget: userBudget,
        referencePlace: referencePlace,
        budgetScore: budgetScore,
        simScore: simScore,
        userPreferences: userPreferences,
      );

      results.add(
        RecommendationResult(
          place: place,
          totalScore: totalScore,
          budgetScore: budgetScore,
          similarityScore: simScore,
          ratingScore: ratingScore,
          reasonBadge: reason,
        ),
      );
    }

    // Urutkan dari total skor tertinggi ke terendah
    results.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return results;
  }

  /// 1. Skor Efisiensi Budget (0 - 35 poin)
  /// Semakin pas averagePrice tempat di bawah atau setara userBudget, semakin tinggi skornya.
  static double _calculateBudgetScore(PlaceModel place, int userBudget) {
    // Jika budget bebas / 0 / sangat besar (>= 150.000)
    if (userBudget <= 0 || userBudget >= 150000) {
      return 30.0;
    }

    // Jika harga minimal di atas budget user -> kena penalti soft budget
    if (place.minPrice > userBudget) {
      final overRatio = (place.minPrice - userBudget) / (userBudget + 1);
      final penalized = 10.0 - (overRatio * 15.0);
      return math.max(0.0, penalized);
    }

    // Rumus dari spesifikasi:
    // budgetScore = 35 * (1 - ((place.averagePrice - place.minPrice) / (userBudget + 1)))
    // Dibatasi antara 10 hingga 35 poin jika masuk budget.
    final spread = math.max(0, place.avgPrice - place.minPrice);
    double score = 35.0 * (1.0 - (spread / (userBudget + 1)));

    // Bonus jika averagePrice pas di bawah userBudget
    if (place.avgPrice <= userBudget) {
      score += 5.0;
    }

    return score.clamp(10.0, 35.0);
  }

  /// 2. Reference Place & Keyword Similarity (0 - 45 poin)
  static double _calculateSimilarityScore({
    required PlaceModel place,
    required List<String> queryTokens,
    PlaceModel? referencePlace,
    required List<String> userPreferences,
  }) {
    double score = 0.0;

    // Jika ada tempat acuan yang user ketik/sukai
    if (referencePlace != null && referencePlace.id != place.id) {
      // Cocokkan kesamaan kategori (+15 poin)
      if (place.category.toLowerCase() ==
          referencePlace.category.toLowerCase()) {
        score += 15.0;
      }
      // Cocokkan fasilitas tempat acuan (+5 poin per fasilitas sama)
      for (final fac in referencePlace.facilities) {
        if (place.facilities.any((f) => f.toLowerCase() == fac.toLowerCase())) {
          score += 5.0;
        }
      }
    }

    // Pencocokan token kata kunci query
    if (queryTokens.isNotEmpty) {
      for (final token in queryTokens) {
        if (token.length < 2) continue;

        // place.name (+20 poin)
        if (place.name.toLowerCase().contains(token)) {
          score += 20.0;
        }
        // place.category (+15 poin)
        if (place.category.toLowerCase().contains(token)) {
          score += 15.0;
        }
        // place.facilities & menuHighlights (+15 poin)
        final matchFacility = place.facilities.any(
          (f) => f.toLowerCase().contains(token),
        );
        final matchMenu = place.menuHighlights.any(
          (m) => m.name.toLowerCase().contains(token),
        );
        if (matchFacility || matchMenu) {
          score += 15.0;
        }
        // place.address / place.city (+10 poin)
        if (place.address.toLowerCase().contains(token) ||
            place.city.toLowerCase().contains(token)) {
          score += 10.0;
        }
      }
    }

    // Pencocokan fasilitas preferensi user (WiFi, Colokan, AC, dll)
    if (userPreferences.isNotEmpty) {
      for (final pref in userPreferences) {
        if (place.facilities.any(
          (f) => f.toLowerCase() == pref.toLowerCase(),
        )) {
          score += 6.0;
        }
      }
    }

    // Default relevansi jika tidak ada input sama sekali
    if (queryTokens.isEmpty &&
        userPreferences.isEmpty &&
        referencePlace == null) {
      score = 25.0;
    }

    return score.clamp(0.0, 45.0);
  }

  /// Tokenisasi teks input user
  static List<String> _tokenize(String input) {
    if (input.isEmpty) return [];
    return input
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Helper untuk memetakan nama wilayah ke kata kunci pencarian
  static List<String> getRegionKeywords(String region) {
    final r = region.toLowerCase();
    if (r.contains('baturraden')) {
      return [
        'baturraden',
        'karanggintung',
        'rempoah',
        'ketenger',
        'palawi',
        'curug',
        'limpakuwus',
      ];
    } else if (r.contains('utara')) {
      return [
        'unsoed',
        'bunyamin',
        'grendeng',
        'purwokerto utara',
        'pabuaran',
        'karangwangkal',
      ];
    } else if (r.contains('sokaraja')) {
      return ['sokaraja', 'soto sokaraja', 'getuk'];
    } else if (r.contains('timur') || r.contains('sumbang')) {
      return [
        'sumbang',
        'kembaran',
        'arcawinangun',
        'dukuhwaluh',
        'ump',
        'ledug',
        'purwokerto timur',
      ];
    } else if (r.contains('barat') && r.contains('selatan')) {
      return [
        'purwokerto barat',
        'stasiun',
        'kober',
        'purwokerto selatan',
        'tanjung',
        'terminal',
        'karangpucung',
        'gerilya',
        'andhang',
      ];
    } else if (r.contains('barat')) {
      return ['purwokerto barat', 'stasiun', 'kober', 'andhang'];
    } else if (r.contains('selatan')) {
      return ['purwokerto selatan', 'tanjung', 'terminal', 'karangpucung', 'gerilya'];
    } else if (r.contains('purwokerto kota') ||
        r.contains('kota') ||
        r.contains('pusat')) {
      return [
        'purwokerto kota',
        'alun-alun',
        'gor',
        'sudirman',
        'dr. angka',
        'isdiman',
        'sukun',
        'pramuka',
        'suharso',
        'gatot subroto',
      ];
    }
    return [r];
  }

  /// Generate teks alasan rekomendasi yang menarik
  static String _generateReasonBadge({
    required PlaceModel place,
    required int userBudget,
    PlaceModel? referencePlace,
    required double budgetScore,
    required double simScore,
    required List<String> userPreferences,
  }) {
    if (referencePlace != null && referencePlace.id != place.id) {
      return 'Mirip ${referencePlace.name} • Sesuai Budget';
    }

    if (userBudget > 0 && userBudget < 150000 && place.avgPrice <= userBudget) {
      final formatted = _formatK(userBudget);
      if (simScore >= 25) {
        return 'Cocok budget $formatted • Mirip pilihanmu';
      }
      return 'Pas di kantong ($formatted) • Rating ${place.rating.toStringAsFixed(1)}';
    }

    if (userPreferences.isNotEmpty) {
      final matched = place.facilities
          .where(
            (f) =>
                userPreferences.any((p) => p.toLowerCase() == f.toLowerCase()),
          )
          .toList();
      if (matched.isNotEmpty) {
        return 'Ada ${matched.first} • Rating ${place.rating.toStringAsFixed(1)}';
      }
    }

    if (place.rating >= 4.7) {
      return 'Sangat Populer (${place.formattedReviewCount} ulasan)';
    }

    return 'Rekomendasi Spesial • ${place.category}';
  }

  static String _formatK(int amount) {
    if (amount >= 1000) {
      return 'Rp ${(amount ~/ 1000)}rb';
    }
    return 'Rp $amount';
  }
}
