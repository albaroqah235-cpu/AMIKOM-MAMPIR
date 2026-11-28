import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/place_model.dart';
import '../services/api_service.dart';
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
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  final PageController _imagePageController = PageController();

  int _currentImageIndex = 0;
  bool _isFavorite = false;
  late List<String> _galleryImages;
  LatLng? _userLocation;
  List<Map<String, dynamic>> _reviews = [];

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
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final dbReviews = await _apiService.fetchReviews(widget.place.id);
    if (mounted) {
      setState(() => _reviews = dbReviews);
    }
  }

  void _showAddReviewModal(PlaceModel place) {
    final colors = AppTheme.colors(context);
    final nameCtrl = TextEditingController();
    final commentCtrl = TextEditingController();
    int selectedRating = 5;
    bool submitting = false;

    _preferenceService.getUserName().then((name) {
      if (name.isNotEmpty && nameCtrl.text.isEmpty) {
        nameCtrl.text = name;
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderNavy,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tulis Ulasan untuk ${place.name}',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (idx) {
                  final starVal = idx + 1;
                  return IconButton(
                    onPressed: () =>
                        setModalState(() => selectedRating = starVal),
                    icon: Icon(
                      starVal <= selectedRating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppTheme.gold,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nama Anda',
                  labelStyle: TextStyle(color: colors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.borderNavy),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.gold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Ulasan / Pengalaman Anda',
                  hintText: 'Bagaimana suasana, kopi, atau fasilitas di cafe ini?',
                  hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                  labelStyle: TextStyle(color: colors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colors.borderNavy),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.gold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final comment = commentCtrl.text.trim();
                          if (comment.isEmpty) {
                            ScaffoldMessenger.of(modalCtx).showSnackBar(
                              const SnackBar(
                                content: Text('Tuliskan ulasan kamu dulu ya!'),
                              ),
                            );
                            return;
                          }
                          final author = nameCtrl.text.trim().isNotEmpty
                              ? nameCtrl.text.trim()
                              : 'Pengunjung MAMPIR';
                          setModalState(() => submitting = true);
                          final ok = await _apiService.submitReview(
                            placeId: place.id,
                            authorName: author,
                            rating: selectedRating.toDouble(),
                            comment: comment,
                          );
                          if (mounted) {
                            setState(() {
                              _reviews.insert(0, {
                                'user': author,
                                'rating': selectedRating.toDouble(),
                                'comment': comment,
                              });
                            });
                          }
                          if (modalCtx.mounted) Navigator.pop(modalCtx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Ulasan berhasil diterbitkan! ⭐'
                                      : 'Ulasan ditambahkan (mode lokal)',
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kirim Ulasan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkFavorite() async {
    final fav = await _preferenceService.isFavorite(widget.place.id);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _openWhatsAppOwner(PlaceModel place) async {
    final raw = place.ownerPhone.trim();
    if (raw.isEmpty) return;
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    } else if (digits.startsWith('8')) {
      digits = '62$digits';
    }
    if (digits.isEmpty) return;
    final text = Uri.encodeComponent(
      'Halo, saya ingin bertanya mengenai ${place.name} dari aplikasi MAMPIR.',
    );
    final url = Uri.parse('https://wa.me/$digits?text=$text');
    await launchUrl(url, mode: LaunchMode.externalApplication);
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
                      if (place.ownerPhone.trim().isNotEmpty) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _openWhatsAppOwner(place),
                            icon: const Icon(
                              Icons.chat_rounded,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Hubungi Pemilik (WhatsApp)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
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
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.restaurant_menu,
                color: AppTheme.gold,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Rp ${item.price > 0 ? _formatRupiah(item.price) : '15.000'}',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab(PlaceModel place) {
    final colors = AppTheme.colors(context);
    final defaultReviews = [
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
            'Kopinya otentik enak, camilannya mantap dan pelayanannya cepet. Pasti bakal balik lagi!',
        'time': '1 minggu lalu',
      },
      {
        'user': 'Bagus Prasetyo',
        'rating': 4.5,
        'comment':
            'Suasananya syahdu, parkir luas, cocok buat nugas atau nongkrong malam.',
        'time': '2 minggu lalu',
      },
    ];
    final reviews = [..._reviews, ...defaultReviews];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: () => _showAddReviewModal(place),
              icon: const Icon(Icons.rate_review_rounded, color: AppTheme.gold, size: 18),
              label: const Text(
                'Tambah Ulasan',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.gold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            itemCount: reviews.length,
            separatorBuilder: (context, index) =>
                Divider(color: colors.borderNavy, height: 20),
            itemBuilder: (context, index) {
              final rev = reviews[index];
              final userName = (rev['user'] as String?)?.trim().isNotEmpty == true
                  ? rev['user'] as String
                  : 'Pengunjung MAMPIR';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.orange.withValues(alpha: 0.25),
                        child: Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        userName,
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
          ),
        ),
      ],
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
