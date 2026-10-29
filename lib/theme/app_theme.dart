import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ============================================================
/// APP THEME & PALET WARNA — MAMPIR APP
/// ============================================================
/// Mengikuti desain mockup Dark Navy & Gold-Orange:
/// - Background Utama: #0D1326 / #111827
/// - Surface & Card: #1A233A / #1E293B
/// - Border halus: #263353
/// - Aksen Utama: Gradasi #FFB74D ke #F57C00 (#FFC107 - #E65100)
/// - Teks Utama: #FFFFFF
/// - Teks Sekunder: #94A3B8 / #CBD5E1
/// ============================================================
class AppTheme {
  // Warna Pokok
  static const Color scaffoldBg = Color(0xFF0D1326);
  static const Color surfaceNavy = Color(0xFF1A233A);
  static const Color cardNavy = Color(0xFF162035);
  static const Color searchNavy = Color(0xFF131B30);
  static const Color borderNavy = Color(0xFF263353);

  // Aksen Gradasi Emas-Oranye
  static const Color gold = Color(0xFFFFB74D);
  static const Color goldLight = Color(0xFFFFC107);
  static const Color orange = Color(0xFFF57C00);
  static const Color orangeDeep = Color(0xFFE65100);

  // Teks
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Gradasi tombol utama & ikon
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gold, orange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [goldLight, orangeDeep],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient subtleNavyGradient = LinearGradient(
    colors: [Color(0xFF131D36), Color(0xFF0D1326)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ==================== DYNAMIC THEME NOTIFIER ====================
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static void setThemeFromString(String themeStr) {
    if (themeStr == 'Terang') {
      themeModeNotifier.value = ThemeMode.light;
    } else if (themeStr == 'Sistem') {
      themeModeNotifier.value = ThemeMode.system;
    } else {
      themeModeNotifier.value = ThemeMode.dark;
    }
  }

  static String getThemeString() {
    switch (themeModeNotifier.value) {
      case ThemeMode.light:
        return 'Terang';
      case ThemeMode.system:
        return 'Sistem';
      case ThemeMode.dark:
        return 'Gelap';
    }
  }

  static bool isDark(BuildContext context) {
    if (themeModeNotifier.value == ThemeMode.light) return false;
    if (themeModeNotifier.value == ThemeMode.dark) return true;
    return Theme.of(context).brightness == Brightness.dark;
  }

  static AppColors colors(BuildContext context) {
    return AppColors(isDark: isDark(context));
  }

  // ==================== LIGHT THEME ====================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      primaryColor: orange,
      colorScheme: const ColorScheme.light(
        primary: orange,
        secondary: gold,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Color(0xFF0F172A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: const Color(0xFFE2E8F0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: orange, width: 1.5),
        ),
      ),
    );
  }

  // ==================== DARK THEME ====================
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBg,
      primaryColor: orange,
      colorScheme: const ColorScheme.dark(
        primary: orange,
        secondary: gold,
        surface: surfaceNavy,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceNavy,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderNavy, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceNavy,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: searchNavy,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderNavy),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderNavy),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      ),
    );
  }
}

/// ============================================================
/// ORNAMEN LATAR BELAKANG MANDALA / BATIK HALUS MULTI-SUDUT
/// ============================================================

enum OrnamentOrigin {
  topRight,
  bottomLeft,
  topLeft,
  bottomRight,
}

/// Ornamen Mandala / Batik yang digambar pada latar belakang layar
class MandalaOrnamentPainter extends CustomPainter {
  final Color? color;
  final double scale;
  final bool? isDark;
  final double strokeWidth;
  final OrnamentOrigin origin;

  MandalaOrnamentPainter({
    this.color,
    this.scale = 1.0,
    this.isDark,
    this.strokeWidth = 1.8,
    this.origin = OrnamentOrigin.topRight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Tentukan warna berdasarkan mode tema:
    // Mode Gelap: Emas amber hangat (0xFFFFB74D) dengan opasitas 0.20
    // Mode Terang: Emas tembaga terracotta (0xFFB45309) dengan opasitas 0.26
    final bool dark = isDark ?? true;
    final baseColor = color ??
        (dark ? const Color(0xFFFFB74D) : const Color(0xFFB45309));
    final double opacity = dark ? 0.20 : 0.26;

    final paint = Paint()
      ..color = baseColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fillPaint = Paint()
      ..color = baseColor.withValues(alpha: opacity * 0.45)
      ..style = PaintingStyle.fill;

    // Tentukan titik pusat motif berdasarkan origin
    Offset center;
    switch (origin) {
      case OrnamentOrigin.topRight:
        center = Offset(size.width, 0);
        break;
      case OrnamentOrigin.bottomLeft:
        center = Offset(0, size.height);
        break;
      case OrnamentOrigin.topLeft:
        center = const Offset(0, 0);
        break;
      case OrnamentOrigin.bottomRight:
        center = Offset(size.width, size.height);
        break;
    }

    final maxRadius = size.width * 0.78 * scale;
    const int petals = 12;

    // 1. Lingkaran konsentris utama
    for (double r = 36; r <= maxRadius; r += 28) {
      canvas.drawCircle(center, r, paint);
    }

    // 2. Garis radial & kelopak mandala lapis luar
    for (int i = 0; i < petals; i++) {
      final angle = (i * 2 * math.pi) / petals;
      final midR = maxRadius * 0.58;
      final x = center.dx + math.cos(angle) * midR;
      final y = center.dy + math.sin(angle) * midR;

      // Kelopak luar
      canvas.drawCircle(Offset(x, y), 22 * scale, paint);

      // Garis radial ke ujung luar
      final rx = center.dx + math.cos(angle) * maxRadius;
      final ry = center.dy + math.sin(angle) * maxRadius;
      canvas.drawLine(center, Offset(rx, ry), paint);

      // Titik aksen ujung luar
      canvas.drawCircle(Offset(rx, ry), 2.5 * scale, fillPaint);
    }

    // 3. Kelopak lapis dalam (offset rotasi berselang-seling)
    final innerR = maxRadius * 0.32;
    for (int i = 0; i < petals; i++) {
      final angle = (i * 2 * math.pi) / petals + (math.pi / petals);
      final x = center.dx + math.cos(angle) * innerR;
      final y = center.dy + math.sin(angle) * innerR;
      canvas.drawCircle(Offset(x, y), 14 * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant MandalaOrnamentPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.scale != scale ||
        oldDelegate.isDark != isDark ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.origin != origin;
  }
}

/// Aksen titik-titik ornamen batik & bintang mengambang halus di latar belakang
class FloatingBatikAccentPainter extends CustomPainter {
  final bool isDark;
  final double strokeWidth;

  FloatingBatikAccentPainter({
    required this.isDark,
    this.strokeWidth = 1.6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = isDark ? const Color(0xFFFFB74D) : const Color(0xFFB45309);
    final double opacity = isDark ? 0.18 : 0.24;

    final strokePaint = Paint()
      ..color = baseColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fillPaint = Paint()
      ..color = baseColor.withValues(alpha: opacity * 0.6)
      ..style = PaintingStyle.fill;

    // Titik-titik posisi aksen floating (relatif terhadap ukuran layar)
    final List<Offset> points = [
      Offset(size.width * 0.16, size.height * 0.30),
      Offset(size.width * 0.86, size.height * 0.48),
      Offset(size.width * 0.22, size.height * 0.68),
      Offset(size.width * 0.80, size.height * 0.82),
      Offset(size.width * 0.50, size.height * 0.15),
    ];

    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final double r = (i % 2 == 0) ? 14.0 : 10.0;

      // Bentuk berlian / bunga batik 4 sisi
      final path = Path();
      path.moveTo(pt.dx, pt.dy - r);
      path.quadraticBezierTo(pt.dx + r * 0.25, pt.dy - r * 0.25, pt.dx + r, pt.dy);
      path.quadraticBezierTo(pt.dx + r * 0.25, pt.dy + r * 0.25, pt.dx, pt.dy + r);
      path.quadraticBezierTo(pt.dx - r * 0.25, pt.dy + r * 0.25, pt.dx - r, pt.dy);
      path.quadraticBezierTo(pt.dx - r * 0.25, pt.dy - r * 0.25, pt.dx, pt.dy - r);
      path.close();

      canvas.drawPath(path, strokePaint);
      canvas.drawCircle(pt, 2.2, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant FloatingBatikAccentPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.strokeWidth != strokeWidth;
}

/// Widget ornamen latar belakang menyeluruh untuk aplikasi MAMPIR.
/// Menggambar mandala di pojok kanan atas, pojok kiri bawah, dan aksen floating halus.
/// Otomatis beradaptasi warna dan kontras dengan Mode Gelap & Mode Terang.
class AppBackgroundOrnament extends StatelessWidget {
  final bool showBottomCorner;
  final bool showFloatingAccents;
  final double topScale;
  final double bottomScale;
  final double topSize;
  final double bottomSize;

  const AppBackgroundOrnament({
    super.key,
    this.showBottomCorner = true,
    this.showFloatingAccents = true,
    this.topScale = 1.0,
    this.bottomScale = 0.85,
    this.topSize = 300,
    this.bottomSize = 260,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: [
          // 1. Ornamen Mandala Pojok Kanan Atas (Besar)
          Positioned(
            top: 0,
            right: 0,
            width: topSize,
            height: topSize,
            child: CustomPaint(
              painter: MandalaOrnamentPainter(
                scale: topScale,
                isDark: isDark,
                origin: OrnamentOrigin.topRight,
              ),
            ),
          ),

          // 2. Ornamen Mandala Pojok Kiri Bawah (Sedang / Elegan)
          if (showBottomCorner)
            Positioned(
              bottom: 0,
              left: 0,
              width: bottomSize,
              height: bottomSize,
              child: CustomPaint(
                painter: MandalaOrnamentPainter(
                  scale: bottomScale,
                  isDark: isDark,
                  origin: OrnamentOrigin.bottomLeft,
                ),
              ),
            ),

          // 3. Aksen Motif Bunga/Batik Floating di Sisi Layar
          if (showFloatingAccents)
            Positioned.fill(
              child: CustomPaint(
                painter: FloatingBatikAccentPainter(isDark: isDark),
              ),
            ),
        ],
      ),
    );
  }
}

/// ============================================================
/// DYNAMIC PALETTE HELPER — BERADAPTASI GELAP & TERANG
/// ============================================================
class AppColors {
  final bool isDark;
  const AppColors({required this.isDark});

  Color get scaffoldBg =>
      isDark ? const Color(0xFF0D1326) : const Color(0xFFF8FAFC);
  Color get surfaceNavy => isDark ? const Color(0xFF1A233A) : Colors.white;
  Color get cardNavy => isDark ? const Color(0xFF162035) : Colors.white;
  Color get searchNavy =>
      isDark ? const Color(0xFF131B30) : const Color(0xFFF1F5F9);
  Color get borderNavy =>
      isDark ? const Color(0xFF263353) : const Color(0xFFE2E8F0);
  Color get textPrimary =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  Color get textSecondary =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get textMuted =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get iconColor => isDark ? Colors.white : const Color(0xFF1E293B);
  Color get bottomNavBg => isDark ? const Color(0xFF0D1426) : Colors.white;
  Color get bottomNavBorder =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
}
