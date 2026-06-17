import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) return; // User cancelled

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mendapatkan token Google')),
          );
        }
        return;
      }

      await widget.state.loginWithGoogle(
        idToken: idToken,
        email: googleUser.email,
        name: googleUser.displayName ?? 'User',
        googleId: googleUser.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In gagal: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.state.authLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AppPage(
              child: ListView(
                padding: AppInsets.page,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: widget.state.backToWelcome,
                      tooltip: 'Kembali',
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset(
                      AppAssets.appLogo,
                      width: 210,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Masuk ke IqroKu',
                    textAlign: TextAlign.center,
                    style: AppText.hero.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Simpan progress Iqro, hafalan, bookmark Qur'an, dan profil anak dalam satu akun.",
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 28),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'contoh@email.com',
                            prefixIcon: Icon(Icons.mail_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => obscurePassword = !obscurePassword,
                              ),
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text('Lupa password?'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.state.authError != null) ...[
                          _AuthErrorBanner(message: widget.state.authError!),
                          const SizedBox(height: 12),
                        ],
                        FilledButton(
                          key: const ValueKey('login_submit_button'),
                          onPressed: isLoading
                              ? null
                              : () {
                                  final email = emailController.text.trim();
                                  final password = passwordController.text;
                                  if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Email tidak valid')),
                                    );
                                    return;
                                  }
                                  if (password.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Password wajib diisi')),
                                    );
                                    return;
                                  }
                                  unawaited(
                                    widget.state.loginWithEmail(
                                      email: email,
                                      password: password,
                                    ),
                                  );
                                },
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isLoading ? 'Masuk...' : 'Masuk',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: AppColors.line),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text('atau', style: AppText.caption),
                            ),
                            const Expanded(
                              child: Divider(color: AppColors.line),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: isLoading ? null : () => unawaited(_signInWithGoogle()),
                          icon: Image.asset(
                            AppAssets.googleLogo,
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                          label: const Text('Masuk dengan Google'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            foregroundColor: AppColors.text,
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Belum punya akun? ', style: AppText.body),
                      GestureDetector(
                        onTap: widget.state.goToRegister,
                        child: Text(
                          'Daftar Sekarang',
                          style: AppText.bodyStrong.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.coral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.coral.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        style: AppText.caption.copyWith(
          color: AppColors.coral,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
