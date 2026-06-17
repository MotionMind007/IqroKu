import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirm = true;
  bool agreedToTerms = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
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
                      onPressed: widget.state.goToLogin,
                      tooltip: 'Kembali ke login',
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset(
                      AppAssets.appLogo,
                      width: 160,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Buat Akun Baru',
                    textAlign: TextAlign.center,
                    style: AppText.hero.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Daftar untuk menyimpan progress belajar anak dan sinkronisasi data.',
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
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
                        const SizedBox(height: 14),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Konfirmasi Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(
                                () => obscureConfirm = !obscureConfirm,
                              ),
                              icon: Icon(
                                obscureConfirm
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
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Checkbox(
                              value: agreedToTerms,
                              onChanged: (value) => setState(
                                () => agreedToTerms = value ?? false,
                              ),
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(
                                  () => agreedToTerms = !agreedToTerms,
                                ),
                                child: Text(
                                  'Saya setuju dengan Syarat & Ketentuan dan Kebijakan Privasi',
                                  style: AppText.caption.copyWith(
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (widget.state.authError != null) ...[
                          _AuthErrorBanner(message: widget.state.authError!),
                          const SizedBox(height: 12),
                        ],
                        FilledButton(
                          onPressed: agreedToTerms && !isLoading
                              ? () {
                                  final email = emailController.text.trim();
                                  final password = passwordController.text;
                                  final confirmPassword = confirmPasswordController.text;

                                  if (nameController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Nama wajib diisi.')),
                                    );
                                    return;
                                  }
                                  if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Email tidak valid.')),
                                    );
                                    return;
                                  }
                                  if (password.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Password minimal 6 karakter.')),
                                    );
                                    return;
                                  }
                                  if (password != confirmPassword) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Konfirmasi password belum sama.')),
                                    );
                                    return;
                                  }
                                  unawaited(
                                    widget.state.registerWithEmail(
                                      name: nameController.text.trim(),
                                      email: email,
                                      password: password,
                                    ),
                                  );
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isLoading ? 'Mendaftarkan...' : 'Daftar',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 12),
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
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: null,
                          icon: Image.asset(
                            AppAssets.googleLogo,
                            width: 22,
                            height: 22,
                            fit: BoxFit.contain,
                          ),
                          label: const Text('Daftar dengan Google (segera)'),
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
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Sudah punya akun? ', style: AppText.body),
                      GestureDetector(
                        onTap: widget.state.goToLogin,
                        child: Text(
                          'Masuk',
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
