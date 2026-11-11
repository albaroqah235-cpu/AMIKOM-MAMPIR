import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/place_model.dart';
import '../services/location_service.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import 'route_screen.dart';

/// ============================================================
/// PLACE DETAIL SCREEN — SESUAI detailTempat_mampir.jpeg
/// & tempat disimpan(detailnya)_mampir.jpeg
/// ============================================================
class PlaceDetailScreen extends StatefulWidget {
  final PlaceModel place;
  final int? userBudget;
  final LatLng? userLocation;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    this.userBudget,
    this.userLocation,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen>
    with SingleTickerProviderStateMixin {
  final PreferenceService _preferenceService = PreferenceService();
  late TabController _tabController;
  final PageController _imagePageController = PageController();

  int _currentImageIndex = 0;
  bool _isFavorite = false;
  late List<String> _galleryImages;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userLocation = widget.userLocation ?? LocationService.instance.currentLatLng;
    if (_userLocation == null) {
      LocationService.instance.getCurrentLocation().then((pos) {
        if (pos != null && mounted) {
          setState(() {
            _userLocation = LatLng(pos.latitude, pos.longitude);
          });
        }
      });
    }

    final rawImg = widget.place.imageUrl.trim();
    _galleryImages = rawImg.isNotEmpty ? [rawImg] : [];

    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final fav = await _preferenceService.isFavorite(widget.place.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    final newStatus = await _preferenceService.toggleFavorite(widget.place.id);
    if (mounted) {
      setState(() => _isFavorite = newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Ditambahkan ke Favorit ❤️'
                : 'Dihapus dari Favorit',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
          // Background Mandala & Batik Multi-Sudut
          const AppBackgroundOrnament(),

          SafeArea(
            child: Column(
              children: [
                // 1. Top Bar: Back, Share, Favorite
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: colors.surfaceNavy,
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: colors.iconColor,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // 2. Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Carousel or Hero Image / Placeholder
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Stack(
                            children: [
                              Container(
                                height: 230,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colors.borderNavy,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: _galleryImages.isEmpty
                                      ? Container(
                                          width: double.infinity,
                                          color: colors.surfaceNavy,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.restaurant_rounded,
                                                size: 54,
                                                color: AppTheme.orange,
                                              ),
                                              const SizedBox(height: 10),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                ),
                                                child: Text(
                                                  place.name,
                                                  style: TextStyle(
                                                    color: colors.textPrimary,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Foto tempat belum tersedia',
                                                style: TextStyle(
                                                  color: colors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : _galleryImages.length == 1
                                          ? Image.network(
                                              _galleryImages.first,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (ctx, err, st) =>
                                                  Container(
                                                color: colors.surfaceNavy,
                                                child: const Icon(
                                                  Icons.restaurant_rounded,
                                                  size: 64,
                                                  color: AppTheme.orange,
                                                ),
                                              ),
                                            )
                                          : PageView.builder(
                                              controller: _imagePageController,
                                              onPageChanged: (i) => setState(
                                                  () => _currentImageIndex = i),
                                              itemCount: _galleryImages.length,
                                              itemBuilder: (context, idx) {
                                                return Image.network(
                                                  _galleryImages[idx],
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  errorBuilder:
                                                      (ctx, err, st) =>
                                                          Container(
                                                    color: colors.surfaceNavy,
                                                    child: const Icon(
                                                      Icons.restaurant_rounded,
                                                      size: 64,
                                                      color: AppTheme.orange,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                ),
                              ),

                              // Counter Badge (only when multiple images exist)
                              if (_galleryImages.length > 1)
                                Positioned(
                                  right: 14,
                                  bottom: 14,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_currentImageIndex + 1}/${_galleryImages.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Place Info Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name & Bookmark
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      place.name,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: _isFavorite
                                          ? Colors.redAccent
                                          : colors.textSecondary,
                                      size: 26,
                                    ),
                                    tooltip: _isFavorite
                                        ? 'Hapus dari Favorit'
                                        : 'Tambah ke Favorit',
                                    onPressed: _toggleFavorite,
                                  ),
                                ],
                              ),

                              // Rating, Reviews & Distance
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: AppTheme.gold,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${place.rating.toStringAsFixed(1)} (${place.formattedReviewCount})',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '• ${place.formattedDistance(_userLocation?.latitude, _userLocation?.longitude)}',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Category & Price Range
                              Text(
                                '${place.category} • ${place.priceRange}',
                                style: const TextStyle(
                                  color: AppTheme.gold,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Facility Chips
                              if (place.facilities.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: place.facilities.map((fac) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceNavy,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: colors.borderNavy,
                                        ),
                                      ),
                                      child: Text(
                                        fac,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                )
                              else
                                Text(
                                  'Informasi fasilitas belum tercatat',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tab Bar: Deskripsi, Menu, Ulasan
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: colors.borderNavy,
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicatorColor: AppTheme.gold,
                            indicatorWeight: 3,
                            labelColor: colors.textPrimary,
                            unselectedLabelColor: colors.textSecondary,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Tab(text: 'Deskripsi'),
                              Tab(text: 'Menu'),
                              Tab(text: 'Ulasan'),
                            ],
                          ),
                        ),

                        // Tab Content
                        SizedBox(
                          height: 220,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Tab 1: Deskripsi & Alamat & Mini Map
                              _buildDescriptionTab(place),

                              // Tab 2: Menu Andalan
                              _buildMenuTab(place),

                              // Tab 3: Ulasan
                              _buildReviewsTab(place),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),

                // 3. Bottom Action Bar: "Lihat Rute" & "Hapus dari Favorit"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colors.scaffoldBg,
                    border: Border(top: BorderSide(color: colors.borderNavy)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: colors.isDark ? 0.5 : 0.08,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.orange.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => RouteScreen(
                                  place: place,
                                  userLocation: _userLocation ??
                                      LocationService.instance.currentLatLng,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.near_me_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Lihat Rute',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionTab(PlaceModel place) {
    final colors = AppTheme.colors(context);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          place.description,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(
              Icons.access_time_rounded,
              color: AppTheme.gold,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              place.openHours,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: AppTheme.orange,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${place.address}, ${place.city}',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Mini preview map
        Container(
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.borderNavy),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(place.latitude, place.longitude),
                initialZoom: 14.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                  subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                  userAgentPackageName: 'com.mampir.mampir_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(place.latitude, place.longitude),
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTab(PlaceModel place) {
    final colors = AppTheme.colors(context);
    if (place.menuHighlights.isEmpty) {
      return Center(
        child: Text(
          'Belum ada daftar menu andalan tercatat untuk tempat ini.',
          style: TextStyle(color: colors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      itemCount: place.menuHighlights.length,
      separatorBuilder: (context, index) =>
          Divider(color: colors.borderNavy, height: 16),
      itemBuilder: (context, index) {
        final item = place.menuHighlights[index];
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.restaurant_menu,
                  color: AppTheme.gold,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  item.name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              'Rp ${item.price > 0 ? _formatRupiah(item.price) : '15.000'}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewsTab(PlaceModel place) {
    final colors = AppTheme.colors(context);
    final reviews = [
      {
        'user': 'Rian S.',
        'rating': 5.0,
        'comment':
            'Tempatnya enak banget buat nugas, wifinya kenceng dan colokan banyak. Harganya beneran pas di kantong!',
        'time': '3 hari lalu',
      },
      {
        'user': 'Dwi Lestari',
        'rating': 4.8,
        'comment':
            'Makanannya otentik enak, porsinya nendang dan pelayanannya cepet. Pasti bakal balik lagi!',
        'time': '1 minggu lalu',
      },
      {
        'user': 'Bagus Prasetyo',
        'rating': 4.5,
        'comment':
            'Suasananya syahdu, parkir luas, cocok buat kumpul keluarga atau nongkrong malam.',
        'time': '2 minggu lalu',
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      itemCount: reviews.length,
      separatorBuilder: (context, index) =>
          Divider(color: colors.borderNavy, height: 20),
      itemBuilder: (context, index) {
        final rev = reviews[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.orange.withValues(alpha: 0.25),
                  child: Text(
                    (rev['user'] as String)[0],
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  rev['user'] as String,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.star_rounded, color: AppTheme.gold, size: 16),
                const SizedBox(width: 2),
                Text(
                  (rev['rating'] as double).toStringAsFixed(1),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rev['comment'] as String,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatRupiah(int amount) {
    final str = amount.toString();
    final result = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result.write('.');
      }
      result.write(str[i]);
    }
    return result.toString();
  }
}
