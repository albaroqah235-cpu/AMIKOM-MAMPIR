import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/preference_service.dart';
import '../theme/app_theme.dart';
import 'region_selection_screen.dart';

/// ============================================================
/// LOGIN SCREEN — AUTENTIKASI SUPABASE UNTUK MAMPIR APP
/// ============================================================
/// Fitur:
/// 1. Masuk (Login) dengan Email & Kata Sandi via Supabase Auth
/// 2. Daftar Akun Baru dengan konfirmasi kata sandi
/// 3. Lupa Kata Sandi: kirim OTP email -> verifikasi kode -> reset sandi
/// 4. SSO: Masuk dengan Google (hanya Google, tanpa Apple)
/// 5. Masuk sebagai Tamu (Guest Mode)
/// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PreferenceService _prefService = PreferenceService();
  final AuthService _authService = AuthService();

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ===========================================================
  // 1. MASUK (LOGIN via SUPABASE)
  // ===========================================================
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final result = await _authService.signIn(email: email, password: password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      final name = result.userName ?? email.split('@').first;
      await _prefService.login(
        name: name.isNotEmpty ? name : 'Penjelajah MAMPIR',
        email: email,
        isGuest: false,
      );
      if (!mounted) return;
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Email atau kata sandi salah.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ===========================================================
  // 2. DAFTAR AKUN BARU (REGISTER via SUPABASE)
  // ===========================================================
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    final result = await _authService.signUp(
      email: email,
      password: password,
      name: name,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Akun berhasil dibuat!'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      // Langsung simpan dan lanjut ke pemilihan wilayah
      await _prefService.login(
        name: name.isNotEmpty ? name : 'Penjelajah MAMPIR',
        email: email,
        isGuest: false,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RegionSelectionScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Gagal membuat akun.'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ===========================================================
  // 3. SSO: MASUK DENGAN GOOGLE
  // ===========================================================
  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));

    // Simulasi Google OAuth — di produksi gunakan supabase_flutter
    const googleName = 'Pengguna Google';
    const googleEmail = 'user@gmail.com';

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
            Text('Berhasil masuk dengan Google!'),
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

  // ===========================================================
  // 4. MASUK SEBAGAI TAMU (GUEST MODE)
  // ===========================================================
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

  // ===========================================================
  // LUPA SANDI: MULTI-STEP DIALOG
  // ===========================================================
  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ForgotPasswordDialog(authService: _authService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return Scaffold(
      backgroundColor: colors.scaffoldBg,
      body: Stack(
        children: [
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
                      // Logo
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

                      // Toggle Tab: Masuk / Daftar
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

                      // Nama Lengkap (khusus mode Daftar)
                      if (_isRegisterMode) ...[
                        _buildInputField(
                          controller: _nameController,
                          label: 'Nama Lengkap',
                          hint: 'Contoh: Asep Hendra',
                          icon: Icons.person_outline_rounded,
                          validator: (val) {
                            if (_isRegisterMode &&
                                (val == null || val.trim().isEmpty)) {
                              return 'Nama tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Email
                      _buildInputField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'nama@email.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!val.contains('@') || !val.contains('.')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Kata Sandi
                      _buildInputField(
                        controller: _passwordController,
                        label: 'Kata Sandi',
                        hint: 'Minimal 6 karakter',
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
                          if (val.length < 6) {
                            return 'Kata sandi minimal 6 karakter';
                          }
                          return null;
                        },
                      ),

                      // Konfirmasi Kata Sandi (khusus mode Daftar)
                      if (_isRegisterMode) ...[
                        const SizedBox(height: 14),
                        _buildInputField(
                          controller: _confirmPasswordController,
                          label: 'Konfirmasi Kata Sandi',
                          hint: 'Ulangi kata sandi kamu',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirmPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppTheme.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscureConfirmPassword =
                                  !_obscureConfirmPassword);
                            },
                          ),
                          validator: (val) {
                            if (_isRegisterMode &&
                                (val == null || val.trim().isEmpty)) {
                              return 'Konfirmasi kata sandi wajib diisi';
                            }
                            if (_isRegisterMode &&
                                val != _passwordController.text) {
                              return 'Kata sandi tidak cocok';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Lupa Kata Sandi (hanya mode Masuk)
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
                        const SizedBox(height: 4),
                      ],

                      // Tombol Masuk / Buat Akun
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
                          onPressed: _isLoading
                              ? null
                              : (_isRegisterMode ? _handleRegister : _handleLogin),
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
                                  _isRegisterMode
                                      ? 'Buat Akun Sekarang'
                                      : 'Masuk ke MAMPIR',
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

                      // Tombol Google (SATU-SATUNYA SSO)
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
                      const SizedBox(height: 16),

                      // Tombol Tamu
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// DIALOG LUPA SANDI — 2 TAHAP
// ===========================================================
class _ForgotPasswordDialog extends StatefulWidget {
  final AuthService authService;
  const _ForgotPasswordDialog({required this.authService});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  // Tahap 1: input email, Tahap 2: input OTP + kata sandi baru
  int _step = 1;
  bool _isLoading = false;
  String _email = '';

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirmNew = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan email yang valid!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await widget.authService.sendPasswordResetOtp(email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.success) {
        _email = email;
        _step = 2;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ??
            (result.success ? 'Kode OTP dikirim!' : 'Gagal mengirim OTP.')),
        backgroundColor:
            result.success ? Colors.green.shade700 : Colors.redAccent,
      ),
    );
  }

  Future<void> _verifyAndReset() async {
    final otp = _otpController.text.trim();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmNewPasswordController.text;

    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan kode OTP yang dikirim ke email kamu.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata sandi baru minimal 6 karakter.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata sandi baru tidak cocok!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await widget.authService.verifyOtpAndResetPassword(
      email: _email,
      token: otp,
      newPassword: newPass,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? ''),
        backgroundColor:
            result.success ? Colors.green.shade700 : Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );

    if (result.success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    return AlertDialog(
      backgroundColor: colors.surfaceNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.lock_reset_rounded, color: AppTheme.orange, size: 24),
          const SizedBox(width: 8),
          Text(
            _step == 1 ? 'Lupa Kata Sandi?' : 'Reset Kata Sandi',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: _step == 1 ? _buildStep1(colors) : _buildStep2(colors),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Batal', style: TextStyle(color: colors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.orange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : (_step == 1 ? _sendOtp : _verifyAndReset),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _step == 1 ? 'Kirim Kode' : 'Reset Sandi',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  Widget _buildStep1(dynamic colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Masukkan email yang terdaftar. Kami akan mengirimkan kode OTP untuk reset kata sandi.',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'nama@email.com',
            hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
            prefixIcon:
                const Icon(Icons.email_outlined, color: AppTheme.orange, size: 20),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.orange),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(dynamic colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.shade900.withAlpha(80),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade700),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.greenAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kode OTP dikirim ke $_email',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Kode OTP',
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 8,
          style: TextStyle(color: colors.textPrimary, fontSize: 18, letterSpacing: 4),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: '',
            hintText: '• • • • • •',
            hintStyle: TextStyle(color: colors.textMuted, letterSpacing: 6),
            filled: true,
            fillColor: colors.cardNavy,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.borderNavy),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.orange),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Kata Sandi Baru',
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNew,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Minimal 6 karakter',
            hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textSecondary,
                size: 18,
              ),
              onPressed: () => setState(() => _obscureNew = !_obscureNew),
            ),
            filled: true,
            fillColor: colors.cardNavy,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.borderNavy),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.orange),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('Konfirmasi Kata Sandi Baru',
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmNewPasswordController,
          obscureText: _obscureConfirmNew,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Ulangi kata sandi baru',
            hintStyle: TextStyle(color: colors.textMuted, fontSize: 13),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmNew
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.textSecondary,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirmNew = !_obscureConfirmNew),
            ),
            filled: true,
            fillColor: colors.cardNavy,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colors.borderNavy),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.orange),
            ),
          ),
        ),
      ],
    );
  }
}
