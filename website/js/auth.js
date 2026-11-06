/**
 * MAMPIR Web - Supabase Auth Service
 * Menangani otentikasi pendaftaran, login email/password, dan guest mode
 */
const AuthService = {
  translateError(raw) {
    if (!raw) return 'Terjadi kendala pada sistem. Silakan coba kembali.';
    const lower = raw.toLowerCase();
    if (lower.indexOf('email not confirmed') !== -1 || lower.indexOf('email_not_confirmed') !== -1) {
      return 'Email kamu belum dikonfirmasi. Silakan buka kotak masuk (atau spam) email kamu dan klik tautan konfirmasi pendaftaran sebelum masuk.';
    }
    if (lower.indexOf('invalid login credentials') !== -1 || lower.indexOf('invalid_credentials') !== -1 || lower.indexOf('invalid') !== -1) {
      return 'Email atau kata sandi salah, atau akun ini belum terdaftar. Silakan periksa kembali atau klik tab "Daftar Akun" untuk membuat akun baru.';
    }
    if (lower.indexOf('user already registered') !== -1 || lower.indexOf('already been registered') !== -1) {
      return 'Email ini sudah terdaftar. Silakan masuk menggunakan kata sandi kamu.';
    }
    if (lower.indexOf('password should be at least 6') !== -1) {
      return 'Kata sandi minimal harus 6 karakter.';
    }
    return raw;
  },

  async signUp(email, password, name) {
    try {
      const response = await fetch(`${AppConfig.authEndpoint}/signup`, {
        method: 'POST',
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email: email.trim(),
          password: password,
          data: { name: name.trim(), full_name: name.trim() }
        })
      });

      const data = await response.json();
      if (response.ok) {
        return {
          success: true,
          message: 'Pendaftaran berhasil! Silakan periksa email Anda untuk konfirmasi tautan pendaftaran.',
          user: data.user
        };
      } else {
        return {
          success: false,
          message: this.translateError(data.msg || data.message || data.error_description)
        };
      }
    } catch (e) {
      return {
        success: false,
        message: 'Koneksi gagal. Periksa sambungan internet Anda.'
      };
    }
  },

  async signIn(email, password) {
    try {
      const response = await fetch(`${AppConfig.authEndpoint}/token?grant_type=password`, {
        method: 'POST',
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email: email.trim(),
          password: password
        })
      });

      const data = await response.json();
      if (response.ok) {
        const user = data.user || {};
        const meta = user.user_metadata || {};
        const name = meta.name || meta.full_name || email.split('@')[0];
        
        StorageService.setUserSession({
          name: name,
          email: email,
          isGuest: false
        });

        return {
          success: true,
          token: data.access_token,
          user: user,
          name: name
        };
      } else {
        return {
          success: false,
          message: this.translateError(data.error_description || data.msg || data.message)
        };
      }
    } catch (e) {
      return {
        success: false,
        message: 'Koneksi gagal. Periksa sambungan internet Anda.'
      };
    }
  },

  signInAsGuest(region = 'Purwokerto Kota') {
    let guestName = 'Tamu Purwokerto Kota';
    const lower = region.toLowerCase();
    if (lower.indexOf('baturraden') !== -1) guestName = 'Tamu Baturraden';
    else if (lower.indexOf('sokaraja') !== -1) guestName = 'Tamu Sokaraja';
    else if (lower.indexOf('unsoed') !== -1 || lower.indexOf('utara') !== -1) guestName = 'Tamu Purwokerto Utara';
    else if (lower.indexOf('sumbang') !== -1 || lower.indexOf('timur') !== -1) guestName = 'Tamu Purwokerto Timur';
    else if (lower.indexOf('barat') !== -1) guestName = 'Tamu Purwokerto Barat';
    else if (lower.indexOf('selatan') !== -1) guestName = 'Tamu Purwokerto Selatan';

    StorageService.setUserSession({
      name: guestName,
      email: '',
      isGuest: true
    });
    return { success: true, name: guestName };
  },

  signOut() {
    StorageService.clearUserSession();
  }
};

