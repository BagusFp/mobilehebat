import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/widgets/primary_button.dart';
import 'auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password) || RegExp(r'[!@#\$&*~]').hasMatch(password)) strength++;
    return strength;
  }

  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi seluruh formulir pendaftaran.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan format email yang valid.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kata sandi minimal 6 karakter.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfirmasi kata sandi tidak cocok.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda harus menyetujui ketentuan dan protokol keamanan.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      name: name,
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran berhasil! Akun tersimpan di Supabase.'),
          backgroundColor: AppColors.secondary,
        ),
      );
      Navigator.of(context).pop(); // Tutup halaman register
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Gagal mendaftar.'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final passwordStrength = _calculatePasswordStrength(_passwordController.text);
    final isPasswordMatch = _passwordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Registrasi Pengguna',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Crest & Title
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppDimensions.roundedLg,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(40),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.volcano_rounded, color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Daftar Akun Penjelajah',
                style: AppTypography.headlineMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                'Mulai petualangan terencana dan aman di kawasan lereng Gunung Merapi.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Registration Form Card
              Container(
                padding: AppDimensions.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppDimensions.roundedLg,
                  border: Border.all(color: AppColors.surfaceContainer, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field Nama Lengkap
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Nama Lengkap',
                            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Sesuai KTP/Paspor',
                            style: AppTypography.bodySmall.copyWith(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                      decoration: const InputDecoration(
                        hintText: 'Misal: Danang Baskoro',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Field Email
                    Text('Email atau Kontak', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                      decoration: const InputDecoration(
                        hintText: 'email@domain.com',
                        prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.primary, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Field Kata Sandi
                    Text('Kata Sandi', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (_) => setState(() {}),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Minimal 8 karakter',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Password Strength Indicator
                    if (_passwordController.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppDimensions.roundedSm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    passwordStrength == 3
                                        ? 'Kekuatan Sandi: Kuat'
                                        : passwordStrength == 2
                                            ? 'Kekuatan Sandi: Sedang'
                                            : 'Kekuatan Sandi: Lemah',
                                    style: AppTypography.labelSmall.copyWith(
                                      color: passwordStrength == 3 ? AppColors.primary : AppColors.volcanoStatusWaspada,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '$passwordStrength/3 Kriteria',
                                    style: AppTypography.bodySmall.copyWith(fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: AppDimensions.roundedFull,
                              child: LinearProgressIndicator(
                                value: passwordStrength / 3,
                                minHeight: 4,
                                backgroundColor: AppColors.surfaceContainer,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  passwordStrength == 3 ? AppColors.primary : AppColors.volcanoStatusWaspada,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),

                    // Field Konfirmasi Kata Sandi
                    Text('Konfirmasi Kata Sandi', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      onChanged: (_) => setState(() {}),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Ulangi kata sandi',
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 20),
                        suffixIcon: isPasswordMatch
                            ? const Icon(Icons.task_alt_rounded, color: AppColors.secondary, size: 20)
                            : IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.onSurfaceVariant,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Checkbox Agreement
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreeTerms,
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) => setState(() => _agreeTerms = val ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Saya menyetujui Ketentuan Layanan, Kebijakan Privasi, dan Protokol Keamanan Wisata Merapi (BPPTKG).',
                            style: AppTypography.bodySmall.copyWith(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tombol Submit
                    PrimaryButton(
                      text: 'Daftar Akun MeraTrip',
                      icon: Icons.terrain_rounded,
                      isLoading: authProvider.isLoading,
                      onPressed: _handleRegister,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Komitmen Hijau MeraTrip Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppDimensions.roundedMd,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.forest_rounded, size: 20, color: AppColors.onSecondaryContainer),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Komitmen Hijau MeraTrip', style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            'Setiap pendaftaran mendonasikan 1 bibit pinus untuk restorasi hutan lereng Merapi.',
                            style: AppTypography.bodySmall.copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
