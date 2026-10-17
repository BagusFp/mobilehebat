import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_provider.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _showPasswordView = false;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isVerifyingPassword = false;
  String? _passwordError;
  bool _hasPromptedBiometric = false;

  @override
  void initState() {
    super.initState();
    // Auto-prompt biometrik sekali saat layar pertama kali muncul
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasPromptedBiometric) {
        _hasPromptedBiometric = true;
        _triggerBiometricAuth();
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometricAuth() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.unlockWithBiometrics();
    // Jika gagal atau dibatalkan, AuthGate tetap menampilkan lock screen ini
    // Pengguna dapat menekan tombol pindai lagi atau beralih ke kata sandi
  }

  Future<void> _verifyPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordError = 'Silakan masukkan kata sandi akun Anda.';
      });
      return;
    }

    setState(() {
      _isVerifyingPassword = true;
      _passwordError = null;
    });

    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.verifyAccountPassword(password);

    if (!mounted) return;

    setState(() {
      _isVerifyingPassword = false;
    });

    if (!result.isSuccess) {
      setState(() {
        _passwordError = result.message;
      });
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        title: Row(
          children: const [
            Icon(Icons.logout, color: AppColors.error),
            SizedBox(width: 8),
            Text('Keluar dari Akun?'),
          ],
        ),
        content: const Text(
          'Sesi Supabase akan diakhiri dan Anda akan diarahkan ke halaman login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final userName = user?.name.isNotEmpty == true ? user!.name : 'Wisatawan Merapi';
    final userEmail = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top App Emblem
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(25),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.landscape_rounded,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'MeraTrip',
                      style: AppTypography.displayLarge.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: AppDimensions.roundedSm,
                      ),
                      child: const Text(
                        'Terkunci',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Aplikasi dikunci dengan autentikasi biometrik',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),

                // User Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: AppDimensions.roundedLg,
                    border: Border.all(color: AppColors.surfaceContainer, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withAlpha(6),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'W',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userEmail.isNotEmpty)
                              Text(
                                userEmail,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Dynamic Body: Biometric View OR Password View
                if (!_showPasswordView) ...[
                  // Biometric View Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: AppDimensions.roundedLg,
                      border: Border.all(color: AppColors.surfaceContainer, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.onSurface.withAlpha(8),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Biometric Sensor Button
                        GestureDetector(
                          onTap: authProvider.isLoading ? null : _triggerBiometricAuth,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryContainer],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(60),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: authProvider.isLoading
                                  ? const SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.fingerprint_rounded,
                                      size: 52,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Pindai Sidik Jari / Face ID',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tempelkan jari Anda pada sensor atau arahkan wajah ke kamera',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        if (authProvider.errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer.withAlpha(180),
                              borderRadius: AppDimensions.roundedMd,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authProvider.errorMessage!,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.onErrorContainer,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Primary Scan Trigger
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: authProvider.isLoading ? null : _triggerBiometricAuth,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Pindai Ulang Biometrik'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gunakan Password Button (Alternative)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPasswordView = true;
                          _passwordError = null;
                          _passwordController.clear();
                        });
                      },
                      icon: const Icon(Icons.password_rounded, size: 18),
                      label: const Text(
                        'Gunakan Kata Sandi Akun',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        foregroundColor: AppColors.onSurface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Password Alternative Form Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: AppDimensions.roundedLg,
                      border: Border.all(color: AppColors.surfaceContainer, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.onSurface.withAlpha(8),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryFixed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_rounded, size: 18, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Verifikasi Kata Sandi Akun',
                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Masukkan kata sandi Supabase akun MeraTrip Anda',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Kata Sandi Akun',
                          style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofocus: true,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                          decoration: InputDecoration(
                            hintText: 'Masukkan kata sandi',
                            prefixIcon: const Icon(Icons.key_rounded, color: AppColors.primary, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: AppColors.onSurfaceVariant,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          onSubmitted: (_) => _verifyPassword(),
                        ),
                        if (_passwordError != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer.withAlpha(200),
                              borderRadius: AppDimensions.roundedMd,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _passwordError!,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.onErrorContainer,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        PrimaryButton(
                          text: 'Verifikasi & Buka Aplikasi',
                          icon: Icons.check_circle_rounded,
                          isLoading: _isVerifyingPassword,
                          onPressed: _isVerifyingPassword ? null : _verifyPassword,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _isVerifyingPassword
                                ? null
                                : () {
                                    setState(() {
                                      _showPasswordView = false;
                                      _passwordError = null;
                                    });
                                  },
                            icon: const Icon(Icons.fingerprint_rounded, size: 18),
                            label: const Text('Kembali ke Autentikasi Biometrik'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Logout / Switch Account Option
                TextButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.error),
                  label: Text(
                    'Keluar / Ganti Akun Lain',
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
