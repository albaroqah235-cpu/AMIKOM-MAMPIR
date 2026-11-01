import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ============================================================
/// NOTIFICATION SCREEN — SESUAI notifikasi_mampir.jpeg
/// ============================================================
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  int _selectedTabIndex = 0; // 0: Semua, 1: Pembaruan

  final List<Map<String, dynamic>> _allNotifications = [];

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final displayedList = _selectedTabIndex == 0
        ? _allNotifications
        : _allNotifications.where((n) => n['unread'] == true).toList();

    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
          // Background Mandala & Batik Multi-Sudut
          const AppBackgroundOrnament(),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: colors.iconColor),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Notifikasi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tabs: Semua vs Pembaruan
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: _selectedTabIndex == 0
                                  ? AppTheme.primaryGradient
                                  : null,
                              color: _selectedTabIndex == 0
                                  ? null
                                  : colors.surfaceNavy,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: _selectedTabIndex == 0
                                    ? Colors.transparent
                                    : colors.borderNavy,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Semua',
                              style: TextStyle(
                                color: _selectedTabIndex == 0
                                    ? Colors.white
                                    : colors.textSecondary,
                                fontWeight: _selectedTabIndex == 0
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: _selectedTabIndex == 1
                                  ? AppTheme.primaryGradient
                                  : null,
                              color: _selectedTabIndex == 1
                                  ? null
                                  : colors.surfaceNavy,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: _selectedTabIndex == 1
                                    ? Colors.transparent
                                    : colors.borderNavy,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Pembaruan',
                              style: TextStyle(
                                color: _selectedTabIndex == 1
                                    ? Colors.white
                                    : colors.textSecondary,
                                fontWeight: _selectedTabIndex == 1
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // List Notifikasi
                Expanded(
                  child: displayedList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: colors.cardNavy,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colors.borderNavy),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    size: 38,
                                    color: AppTheme.gold,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Belum Ada Notifikasi',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Kamu belum memiliki notifikasi baru. Pembaruan promo dan rekomendasi kuliner Purwokerto akan muncul di sini!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          itemCount: displayedList.length,
                          separatorBuilder: (context, index) =>
                              Divider(color: colors.borderNavy, height: 28),
                          itemBuilder: (context, index) {
                            final notif = displayedList[index];
                            final isMascot = notif['isMascot'] == true;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Thumbnail / Icon
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: colors.surfaceNavy,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: colors.borderNavy),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: isMascot
                                        ? Transform.scale(
                                            scale: 1.35,
                                            alignment: const Alignment(0, -0.04),
                                            child: Image.asset(
                                              'assets/images/app_icon.jpeg',
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Image.network(
                                            notif['image'] as String,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, st) =>
                                                const Icon(
                                              Icons.local_cafe_rounded,
                                              color: AppTheme.gold,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Detail Notifikasi
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notif['title'] as String,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif['subtitle'] as String,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        notif['time'] as String,
                                        style: const TextStyle(
                                          color: AppTheme.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Indicator unread
                                if (notif['unread'] == true)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
