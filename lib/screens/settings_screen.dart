import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'notification_screen.dart';

/// ============================================================
/// SETTINGS & USER PROFILE SCREEN — PENGATURAN MAMPIR APP
/// ============================================================
/// Mengelola profil pengguna dan seluruh menu pengaturan:
/// 1. Profil Pengguna (Avatar, Nama, Email, Edit Profil)
/// 2. Notifikasi (Switch preferensi notifikasi & akses ke layar riwayat)
/// 3. Izin Lokasi (Status GPS & penjelasan akses wilayah Purwokerto)
/// 4. Bahasa (Pilihan Indonesia, English, Basa Banyumasan/Ngapak)
/// 5. Tema (Pilihan Gelap, Terang, Ikuti Sistem)
/// 6. Bantuan & Hubungi Kami (WhatsApp CS, Email, FAQ)
/// 7. Tentang MAMPIR (Informasi versi, deskripsi, & tim pengembang)
/// 8. Bagikan Aplikasi (Salin tautan ke clipboard & bagikan ke WhatsApp)
/// 9. Beri Rating MAMPIR (Bintang 1-5 interaktif & input saran/ulasan)
/// 10. Keluar Akun (Logout dengan konfirmasi)
/// ============================================================
class SettingsScreen extends StatefulWidget {
  final bool isRootTab;

  const SettingsScreen({
    super.key,
    this.isRootTab = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PreferenceService _prefService = PreferenceService();

  String _userName = 'Penjelajah MAMPIR';
  String _userEmail = 'user@mampir.id';
  String _userBadge = '🌟 Penjelajah Purwokerto';
  bool _isGuest = false;
  bool _isNotificationEnabled = true;
  bool _isLocationEnabled = true;
  String _selectedLanguage = 'Indonesia';
  String _selectedTheme = 'Gelap';
  int _appRating = 5;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isGuest = await _prefService.isGuest();
    String name;
    String email;
    String badge;

    if (isGuest) {
      final region = await _prefService.getSelectedRegion();
      name = PreferenceService.formatGuestName(region);
      email = PreferenceService.formatGuestEmail(region);
      badge = PreferenceService.formatGuestBadge(region);
    } else {
      name = await _prefService.getUserName();
      email = await _prefService.getUserEmail();
      badge = '🌟 Penjelajah Purwokerto';
    }

    final notif = await _prefService.isNotificationEnabled();
    final loc = await _prefService.isLocationEnabled();
    final lang = await _prefService.getLanguage();
    final theme = await _prefService.getThemeMode();
    final rating = await _prefService.getAppRating();

    if (mounted) {
      setState(() {
        _isGuest = isGuest;
        _userName = name;
        _userEmail = email;
        _userBadge = badge;
        _isNotificationEnabled = notif;
        _isLocationEnabled = loc;
        _selectedLanguage = lang;
        _selectedTheme = theme;
        _appRating = rating;
      });
    }
  }

  Future<void> _openUrl(String urlString) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Tidak dapat membuka tautan: $urlString'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showEditProfileDialog() {
    final colors = AppTheme.colors(context);
    final nameCtrl = TextEditingController(text: _userName);
    final emailCtrl = TextEditingController(text: _userEmail);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Profil Pengguna',
            style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Nama Pengguna',
                labelStyle: const TextStyle(color: AppTheme.gold),
                filled: true,
                fillColor: colors.cardNavy,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderNavy),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderNavy),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: AppTheme.gold),
                filled: true,
                fillColor: colors.cardNavy,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderNavy),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colors.borderNavy),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newEmail = emailCtrl.text.trim();
              Navigator.pop(ctx);
              if (newName.isNotEmpty) {
                await _prefService.updateProfile(name: newName, email: newEmail);
                if (mounted) {
                  setState(() {
                    _userName = newName;
                    _userEmail = newEmail;
                  });
                }
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    final colors = AppTheme.colors(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text('Keluar Akun', style: TextStyle(color: colors.textPrimary, fontSize: 18)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun MAMPIR?',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _prefService.logout();

              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
          // Background Mandala di pojok kanan atas
          Positioned(
            top: 0,
            right: 0,
            width: 260,
            height: 260,
            child: CustomPaint(
              painter: MandalaOrnamentPainter(scale: 0.9),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      if (!widget.isRootTab) ...[
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back, color: colors.iconColor),
                          tooltip: 'Kembali',
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        'Pengaturan & Akun',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    children: [
                      // USER PROFILE CARD
                      _buildUserProfileCard(),
                      const SizedBox(height: 16),

                      // 1. Notifikasi
                      _buildSettingItem(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifikasi',
                        trailingText: _isNotificationEnabled ? 'Aktif' : 'Nonaktif',
                        onTap: _showNotificationSettingsModal,
                      ),
                      _buildDivider(),

                      // 2. Izin Lokasi
                      _buildSettingItem(
                        icon: Icons.location_on_outlined,
                        title: 'Izin Lokasi',
                        trailingText: _isLocationEnabled ? 'Diizinkan' : 'Ditolak',
                        onTap: _showLocationSettingsModal,
                      ),
                      _buildDivider(),

                      // 3. Bahasa
                      _buildSettingItem(
                        icon: Icons.language_rounded,
                        title: 'Bahasa',
                        trailingText: _selectedLanguage,
                        onTap: _showLanguageSelectorModal,
                      ),
                      _buildDivider(),

                      // 4. Tema
                      _buildSettingItem(
                        icon: Icons.nightlight_round,
                        title: 'Tema',
                        trailingText: _selectedTheme,
                        onTap: _showThemeSelectorModal,
                      ),
                      _buildDivider(),

                      // 5. Bantuan & Hubungi Kami
                      _buildSettingItem(
                        icon: Icons.help_outline_rounded,
                        title: 'Bantuan & Hubungi Kami',
                        onTap: _showHelpAndContactModal,
                      ),
                      _buildDivider(),

                      // 6. Tentang MAMPIR
                      _buildSettingItem(
                        icon: Icons.info_outline_rounded,
                        title: 'Tentang MAMPIR',
                        subtitle: 'Versi 1.0.0',
                        onTap: _showAboutMampirDialog,
                      ),
                      _buildDivider(),

                      // 7. Bagikan Aplikasi
                      _buildSettingItem(
                        icon: Icons.share_rounded,
                        title: 'Bagikan Aplikasi',
                        onTap: _showShareAppModal,
                      ),
                      _buildDivider(),

                      // 8. Beri Rating MAMPIR
                      _buildSettingItem(
                        icon: Icons.star_rounded,
                        title: 'Beri Rating MAMPIR',
                        subtitle: '$_appRating Bintang',
                        iconColor: AppTheme.gold,
                        onTap: _showRatingDialog,
                      ),
                      const SizedBox(height: 24),

                      // TOMBOL LOGOUT
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.redAccent.withAlpha(25),
                          ),
                          icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                          label: const Text(
                            'Keluar dari Akun',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _handleLogout,
                        ),
                      ),
                      const SizedBox(height: 32),
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

  // ======================== USER PROFILE CARD ========================
  Widget _buildUserProfileCard() {
    final colors = AppTheme.colors(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderNavy),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(colors.isDark ? 40 : 12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Lingkaran
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.orange.withAlpha(80),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'M',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info Nama & Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _userEmail,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.gold.withAlpha(80)),
                  ),
                  child: Text(
                    _userBadge,
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tombol Edit Profil
          if (!_isGuest)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.gold, size: 20),
              tooltip: 'Edit Profil',
              onPressed: _showEditProfileDialog,
            ),
        ],
      ),
    );
  }

  // ======================== MODAL: NOTIFIKASI ========================
  void _showNotificationSettingsModal() {
    final colors = AppTheme.colors(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: AppTheme.orange, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Pengaturan Notifikasi',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    activeThumbColor: AppTheme.orange,
                    activeTrackColor: AppTheme.orange.withAlpha(120),
                    contentPadding: EdgeInsets.zero,
                    title: Text('Izinkan Notifikasi',
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('Rekomendasi kuliner & pembaruan tempat nongkrong',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    value: _isNotificationEnabled,
                    onChanged: (val) async {
                      setModalState(() => _isNotificationEnabled = val);
                      setState(() => _isNotificationEnabled = val);
                      await _prefService.setNotificationEnabled(val);
                    },
                  ),
                  Divider(color: colors.borderNavy),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inbox_rounded, color: AppTheme.gold),
                    title: Text('Buka Riwayat Notifikasi',
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('Lihat pesan promo dan rekomendasi yang masuk',
                        style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                    trailing: Icon(Icons.chevron_right, color: colors.textSecondary),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationScreen()),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ======================== MODAL: IZIN LOKASI ========================
  void _showLocationSettingsModal() {
    final colors = AppTheme.colors(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppTheme.orange, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Pengaturan Izin Lokasi (GPS)',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'MAMPIR membutuhkan izin lokasi agar dapat merekomendasikan kuliner terdekat serta memandu rute perjalanan di Purwokerto, Baturraden, dan Sokaraja.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    activeThumbColor: AppTheme.orange,
                    activeTrackColor: AppTheme.orange.withAlpha(120),
                    contentPadding: EdgeInsets.zero,
                    title: Text('Akses Lokasi Perangkat',
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _isLocationEnabled ? 'GPS aktif untuk Purwokerto & Sekitarnya' : 'Lokasi nonaktif (menggunakan titik pusat kota)',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                    value: _isLocationEnabled,
                    onChanged: (val) async {
                      final messenger = ScaffoldMessenger.of(context);
                      setModalState(() => _isLocationEnabled = val);
                      setState(() => _isLocationEnabled = val);
                      await _prefService.setLocationEnabled(val);

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(val
                              ? 'Izin lokasi berhasil diaktifkan'
                              : 'Izin lokasi dinonaktifkan'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ======================== MODAL: PILIH BAHASA ========================
  void _showLanguageSelectorModal() {
    final colors = AppTheme.colors(context);
    final languages = [
      {'code': 'Indonesia', 'title': 'Bahasa Indonesia', 'subtitle': 'Bahasa Resmi'},
      {'code': 'English', 'title': 'English', 'subtitle': 'International Language'},
      {'code': 'Basa Ngapak', 'title': 'Basa Banyumasan', 'subtitle': 'Basa Khas Wong Purwokerto'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.language_rounded, color: AppTheme.orange, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Pilih Bahasa Aplikasi',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ...languages.map((lang) {
                final isSelected = _selectedLanguage == lang['code'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (colors.isDark ? AppTheme.cardNavy : const Color(0xFFFFF7ED))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.gold : colors.borderNavy,
                    ),
                  ),
                  child: ListTile(
                    title: Text(
                      lang['title']!,
                      style: TextStyle(
                        color: isSelected ? AppTheme.gold : colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      lang['subtitle']!,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.gold)
                        : null,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final newLang = lang['code']!;
                      Navigator.pop(ctx);
                      setState(() => _selectedLanguage = newLang);
                      await _prefService.setLanguage(newLang);

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Bahasa diubah ke ${lang['title']}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ======================== MODAL: PILIH TEMA ========================
  void _showThemeSelectorModal() {
    final colors = AppTheme.colors(context);
    final themes = [
      {'code': 'Gelap', 'title': 'Tema Gelap (Dark)', 'icon': Icons.nightlight_round},
      {'code': 'Terang', 'title': 'Tema Terang (Light)', 'icon': Icons.wb_sunny_rounded},
      {'code': 'Sistem', 'title': 'Ikuti Pengaturan Sistem', 'icon': Icons.settings_brightness_rounded},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.palette_rounded, color: AppTheme.orange, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Pilih Tema Tampilan',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ...themes.map((theme) {
                final isSelected = _selectedTheme == theme['code'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (colors.isDark ? AppTheme.cardNavy : const Color(0xFFFFF7ED))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.orange : colors.borderNavy,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      theme['icon'] as IconData,
                      color: isSelected ? AppTheme.orange : colors.textSecondary,
                    ),
                    title: Text(
                      theme['title'] as String,
                      style: TextStyle(
                        color: isSelected ? AppTheme.orange : colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.orange)
                        : null,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final newTheme = theme['code'] as String;
                      Navigator.pop(ctx);
                      setState(() => _selectedTheme = newTheme);
                      await _prefService.setThemeMode(newTheme);
                      AppTheme.setThemeFromString(newTheme);

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Tema diatur ke ${theme['title']}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ======================== MODAL: BANTUAN & HUBUNGI KAMI ========================
  void _showHelpAndContactModal() {
    final colors = AppTheme.colors(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surfaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.support_agent_rounded, color: AppTheme.orange, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      'Bantuan & Hubungi Kami',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Ada pertanyaan atau kendala seputar aplikasi MAMPIR? Hubungi kami langsung:',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Kontak WhatsApp
                _buildContactCard(
                  icon: Icons.chat_bubble_rounded,
                  iconColor: Colors.greenAccent,
                  title: 'WhatsApp CS MAMPIR',
                  subtitle: '+62 812-3456-7890 (Respon Cepat)',
                  onTap: () {
                    _openUrl(
                      'https://wa.me/6281234567890?text=Halo%20Admin%20MAMPIR,%20saya%20butuh%20bantuan%20terkait%20aplikasi%20MAMPIR',
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Kontak Email
                _buildContactCard(
                  icon: Icons.email_rounded,
                  iconColor: Colors.lightBlueAccent,
                  title: 'Email Dukungan',
                  subtitle: 'support@mampir.id',
                  onTap: () {
                    _openUrl('mailto:support@mampir.id?subject=Bantuan%20Aplikasi%20MAMPIR');
                  },
                ),
                const SizedBox(height: 8),

                // Website Resmi
                _buildContactCard(
                  icon: Icons.public_rounded,
                  iconColor: AppTheme.gold,
                  title: 'Situs Resmi MAMPIR',
                  subtitle: 'https://mampir.id',
                  onTap: () {
                    _openUrl('https://mampir.id');
                  },
                ),

                const SizedBox(height: 20),
                Text(
                  'Pertanyaan Sering Diajukan (FAQ)',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                _buildFaqItem(
                  'Bagaimana cara memfilter tempat sesuai budget?',
                  'Klik tombol filter budget (ikon Rp) pada Beranda atau Pencarian, lalu geser pengatur budget sesuai batas per orang yang diinginkan.',
                ),
                _buildFaqItem(
                  'Apakah data cafe dan restoran akurat?',
                  'Data diverifikasi secara berkala berdasarkan titik koordinat dan profil kuliner nyata di wilayah Purwokerto, Baturraden, dan Sokaraja.',
                ),
                _buildFaqItem(
                  'Bagaimana cara membuka panduan rute?',
                  'Pilih salah satu tempat makan, lalu tekan tombol "Buka Rute" di bagian bawah layar untuk melihat peta dan navigasi Google Maps.',
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = AppTheme.colors(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.cardNavy,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderNavy),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(38),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title,
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        trailing: Icon(Icons.arrow_forward_ios_rounded, color: colors.textSecondary, size: 14),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    final colors = AppTheme.colors(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.cardNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderNavy),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        iconColor: AppTheme.gold,
        collapsedIconColor: colors.textSecondary,
        title: Text(
          question,
          style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ======================== DIALOG: TENTANG MAMPIR ========================
  void _showAboutMampirDialog() {
    final colors = AppTheme.colors(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.orange.withAlpha(40),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.orange, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/app_icon.jpeg',
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppTheme.orange,
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'MAMPIR',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
            const Text(
              'Makan • Ampir • Pilih • Rekomendasi',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.gold,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: colors.isDark ? Colors.white10 : Colors.black.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Versi 1.0.0 (Release Build)',
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Aplikasi panduan dan rekomendasi tempat kuliner, cafe santai, dan tempat nongkrong favorit di Kota Purwokerto dan sekitarnya (Baturraden, Sokaraja) berbasis filter budget & peta interaktif.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: colors.borderNavy),
            Text(
              'Tugas Praktikum PML Semester 5\n© 2026 MAMPIR Purwokerto',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ======================== MODAL: BAGIKAN APLIKASI ========================
  void _showShareAppModal() {
    final colors = AppTheme.colors(context);
    const shareUrl = 'https://mampir.id/download';
    const shareMessage =
        'Yuk cari tempat makan & cafe nongkrong asik di Purwokerto dengan aplikasi MAMPIR! Download di: $shareUrl';

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.share_rounded, color: AppTheme.orange, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Bagikan Aplikasi MAMPIR',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ajak teman dan keluarga untuk mengeksplorasi kuliner lezat & tempat nongkrong asik di Purwokerto!',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Kotak Tautan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.cardNavy,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.borderNavy),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: AppTheme.gold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        shareUrl,
                        style: TextStyle(color: colors.textPrimary, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppTheme.gold, size: 18),
                      tooltip: 'Salin Tautan',
                      onPressed: () {
                        Clipboard.setData(const ClipboardData(text: shareUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tautan aplikasi berhasil disalin ke clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Bagikan WhatsApp
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_rounded, color: Colors.white),
                  label: const Text(
                    'Bagikan via WhatsApp',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final encoded = Uri.encodeComponent(shareMessage);
                    _openUrl('https://wa.me/?text=$encoded');
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ======================== DIALOG: BERI RATING ========================
  void _showRatingDialog() {
    final colors = AppTheme.colors(context);
    int currentRating = _appRating;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final labels = [
              '',
              'Kurang Puas 😞',
              'Cukup 😐',
              'Bagus! 😊',
              'Sangat Bagus! 😃',
              'Luar Biasa Memuaskan! 🌟',
            ];

            return AlertDialog(
              backgroundColor: colors.surfaceNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppTheme.gold, size: 26),
                  const SizedBox(width: 8),
                  Text('Beri Rating MAMPIR', style: TextStyle(color: colors.textPrimary, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Berapa bintang untuk pengalaman Anda memakai MAMPIR?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 14),

                  // Bintang Interaktif
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      return IconButton(
                        iconSize: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        icon: Icon(
                          starNum <= currentRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: AppTheme.gold,
                        ),
                        onPressed: () {
                          setDialogState(() => currentRating = starNum);
                        },
                      );
                    }),
                  ),

                  // Label Bintang
                  Text(
                    labels[currentRating],
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // TextField Ulasan
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Tuliskan ulasan atau saran Anda untuk MAMPIR...',
                      hintStyle: TextStyle(color: colors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: colors.cardNavy,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.borderNavy),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.borderNavy),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    setState(() => _appRating = currentRating);
                    await _prefService.saveAppRating(currentRating);

                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Terima kasih telah memberi rating $currentRating bintang untuk MAMPIR! ⭐',
                        ),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Kirim Penilaian',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ======================== WIDGET HELPER ========================
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailingText,
    Color iconColor = AppTheme.orange,
    required VoidCallback onTap,
  }) {
    final colors = AppTheme.colors(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surfaceNavy,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.borderNavy),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textSecondary,
            size: 20,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    final colors = AppTheme.colors(context);
    return Divider(
      color: colors.borderNavy,
      height: 1,
      indent: 58,
    );
  }
}
