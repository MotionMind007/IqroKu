import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final emailController = TextEditingController();
  final tokenController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool obscurePassword = true;
  bool obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    emailController.text = widget.state.passwordResetEmail ?? '';
    final token = widget.state.passwordResetDevToken;
    if (token != null && token.isNotEmpty) {
      tokenController.text = token;
    }
  }

  @override
  void didUpdateWidget(covariant PasswordResetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final token = widget.state.passwordResetDevToken;
    if (token != null && token.isNotEmpty && tokenController.text.isEmpty) {
      tokenController.text = token;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    tokenController.dispose();
    passwordController.dispose();
    confirmController.dispose();
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
                      onPressed: isLoading ? null : widget.state.goToLogin,
                      tooltip: 'Kembali ke login',
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Image.asset(
                      AppAssets.appLogo,
                      width: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Reset Password',
                    textAlign: TextAlign.center,
                    style: AppText.hero.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kirim kode reset ke email, lalu buat password baru.',
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
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
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () => unawaited(
                                    widget.state.requestPasswordReset(
                                      emailController.text,
                                    ),
                                  ),
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Kirim kode reset'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: tokenController,
                          decoration: const InputDecoration(
                            labelText: 'Kode reset',
                            prefixIcon: Icon(Icons.key_outlined),
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
                            labelText: 'Password baru',
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
                          controller: confirmController,
                          obscureText: obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Konfirmasi password',
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
                        if (widget.state.passwordResetDevToken != null) ...[
                          const SizedBox(height: 10),
                          _AuthBanner(
                            message:
                                'Mode local: kode reset sudah tersedia dari backend.',
                          ),
                        ],
                        const SizedBox(height: 14),
                        if (widget.state.authError != null) ...[
                          _AuthBanner(
                            message: widget.state.authError!,
                            isError: true,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (widget.state.authMessage != null) ...[
                          _AuthBanner(message: widget.state.authMessage!),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          onPressed: isLoading
                              ? null
                              : () {
                                  final password = passwordController.text;
                                  if (password.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Password minimal 6 karakter.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (password != confirmController.text) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Konfirmasi password belum sama.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  unawaited(
                                    widget.state.confirmPasswordReset(
                                      token: tokenController.text,
                                      password: password,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            isLoading ? 'Menyimpan...' : 'Ganti password',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBanner extends StatelessWidget {
  const _AuthBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.coral : AppColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        style: AppText.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
