import 'package:flutter/material.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import 'region_selection_screen.dart';

/// ============================================================
/// LOGIN SCREEN — AUTENTIKASI PENGGUNA MAMPIR
/// ============================================================
/// Menyediakan fitur:
/// 1. Masuk (Login) dengan Email & Kata Sandi
/// 2. Daftar Akun Baru (Register)
/// 3. Masuk dengan SSO (Single Sign-On): Google & Apple
/// 4. Masuk sebagai Tamu (Guest Mode)
/// 5. Desain bernuansa Deep Navy & Gold-Orange khas Purwokerto
/// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PreferenceService _prefService = PreferenceService();

  final _formKey = GlobalKey<FormState>();
  final _emailController =
      TextEditingController(text: 'yusuffikrisafiyulloh@gmail.com');
  final _passwordController = TextEditingController(text: 'yusuf2026');
  final _nameController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // 1. Masuk dengan Akun Biasa (Email & Password)
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));

    final email = _emailController.text.trim();
    String name = 'Penjelajah MAMPIR';

    if (_isRegisterMode) {
      name = _nameController.text.trim();
    } else {
      if (email.toLowerCase() == 'yusuffikrisafiyulloh@gmail.com') {
        name = 'Yusuf Fikri Safiyulloh';
      } else if (email.contains('@')) {
        final prefix = email.split('@').first;
        name = prefix[0].toUpperCase() + prefix.substring(1);
      } else {
        name = email[0].toUpperCase() + email.substring(1);
      }
    }

    await _prefService.login(
      name: name.isNotEmpty ? name : 'Penjelajah MAMPIR',
      email: email.isNotEmpty ? email : 'user@mampir.id',
      isGuest: false,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selamat datang, $name! ✨'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegionSelectionScreen()),
    );
  }

  // 2. SSO: Masuk dengan Akun Google
  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 650));

    const googleName = 'Yusuf Fikri Safiyulloh';
    const googleEmail = 'yusuffikrisafiyulloh@gmail.com';

    await _prefService.login(
      name: googleName,
      email: googleEmail,
      isGuest: false,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Berhasil masuk dengan Google sebagai Yusuf!'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegionSelectionScreen()),
    );
  }

  // 3. SSO: Masuk dengan Apple ID
  Future<void> _handleAppleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 650));

    const appleName = 'Pengguna Apple';
    const appleEmail = 'user@icloud.com';

    await _prefService.login(
      name: appleName,
      email: appleEmail,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Berhasil masuk dengan Apple ID!'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegionSelectionScreen()),
    );
  }

  // 4. Masuk sebagai Tamu (Guest Mode)
  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));

    final region = await _prefService.getSelectedRegion();
    final guestName = PreferenceService.formatGuestName(region);
    final guestEmail = PreferenceService.formatGuestEmail(region);

    await _prefService.login(
      name: guestName,
      email: guestEmail,
      isGuest: true,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegionSelectionScreen()),
    );
  }



  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
          // Background Mandala & Batik Multi-Sudut
          const AppBackgroundOrnament(),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Aplikasi
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: colors.surfaceNavy,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppTheme.orange, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.orange.withAlpha(50),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Transform.scale(
                            scale: 1.35,
                            alignment: const Alignment(0, -0.04),
                            child: Image.asset(
                              'assets/images/app_icon.jpeg',
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => const Icon(
                                Icons.restaurant_menu_rounded,
                                size: 40,
                                color: AppTheme.orange,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Nama Aplikasi & Slogan
                      Text(
                        'MAMPIR',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Kuliner & Tempat Nongkrong Purwokerto',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Toggle Tab: Masuk vs Daftar
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colors.cardNavy,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.borderNavy),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isRegisterMode = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !_isRegisterMode
                                        ? AppTheme.orange
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Masuk',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: !_isRegisterMode
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _isRegisterMode = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _isRegisterMode
                                        ? AppTheme.orange
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Daftar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: _isRegisterMode
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Input Nama Lengkap (Khusus Mode Daftar)
                      if (_isRegisterMode) ...[
                        _buildInputField(
                          controller: _nameController,
                          label: 'Nama Lengkap',
                          hint: 'Contoh: Yusuf Fikri',
                          icon: Icons.person_outline_rounded,
                          validator: (val) {
                            if (_isRegisterMode && (val == null || val.trim().isEmpty)) {
                              return 'Nama tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Input Email / Username
                      _buildInputField(
                        controller: _emailController,
                        label: 'Email / Username',
                        hint: 'nama@email.com atau username',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Email atau username wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Input Kata Sandi
                      _buildInputField(
                        controller: _passwordController,
                        label: 'Kata Sandi',
                        hint: 'Minimal 4 karakter',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Kata sandi wajib diisi';
                          }
                          if (val.length < 4) {
                            return 'Kata sandi minimal 4 karakter';
                          }
                          return null;
                        },
                      ),

                      if (!_isRegisterMode) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text(
                              'Lupa Kata Sandi?',
                              style: TextStyle(color: AppTheme.gold, fontSize: 12),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 14),
                      ],

                      // Tombol Masuk / Daftar Utama
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isRegisterMode ? 'Buat Akun Sekarang' : 'Masuk ke MAMPIR',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Divider ATAU
                      const Row(
                        children: [
                          Expanded(child: Divider(color: AppTheme.borderNavy)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'ATAU MASUK DENGAN',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: AppTheme.borderNavy)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ==================== SSO BUTTONS ====================
                      // Tombol Masuk dengan Google
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleGoogleLogin,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google Icon
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'G',
                                  style: TextStyle(
                                    color: Color(0xFF4285F4),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Lanjutkan dengan Google',
                                style: TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Tombol Masuk dengan Apple
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF161F33),
                            side: const BorderSide(color: AppTheme.borderNavy, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.apple_rounded, color: Colors.white, size: 22),
                          label: const Text(
                            'Lanjutkan dengan Apple',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleAppleLogin,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tombol Jelajahi sebagai Tamu
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary,
                          ),
                          icon: const Icon(Icons.person_pin_circle_outlined,
                              color: AppTheme.gold, size: 18),
                          label: const Text(
                            'Masuk Sementara sebagai Tamu',
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleGuestLogin,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final colors = AppTheme.colors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: AppTheme.orange, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: colors.cardNavy,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.borderNavy),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.borderNavy),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.orange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  void _showForgotPasswordDialog() {
    final colors = AppTheme.colors(context);
    final resetController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Kata Sandi', style: TextStyle(color: colors.textPrimary, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan email Anda. Kami akan mengirimkan tautan untuk mengatur ulang kata sandi akun MAMPIR Anda.',
              style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: resetController,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'nama@email.com',
                hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
                filled: true,
                fillColor: colors.cardNavy,
                border: OutlineInputBorder(
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
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Instruksi reset kata sandi telah dikirim ke email Anda!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Kirim', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
