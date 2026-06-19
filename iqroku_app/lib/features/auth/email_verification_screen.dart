import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final token = widget.state.emailVerificationDevToken;
    if (token != null && token.isNotEmpty) {
      tokenController.text = token;
    }
  }

  @override
  void dispose() {
    tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.state.authLoading;
    final email = widget.state.pendingVerificationEmail ?? 'email kamu';
    final canSkip = !widget.state.emailVerificationRequired;

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
                      tooltip: 'Kembali',
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
                    'Verifikasi Email',
                    textAlign: TextAlign.center,
                    style: AppText.hero.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Masukkan kode dari email $email untuk mengamankan akun.',
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: tokenController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Kode verifikasi',
                            prefixIcon: Icon(Icons.mark_email_read_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        if (widget.state.emailVerificationDevToken != null) ...[
                          const SizedBox(height: 10),
                          _InfoBanner(
                            message:
                                'Mode local: kode sudah diisi otomatis dari backend.',
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
                              : () => unawaited(
                                    widget.state.verifyEmailToken(
                                      tokenController.text,
                                    ),
                                  ),
                          icon: const Icon(Icons.verified_outlined),
                          label: Text(isLoading ? 'Memeriksa...' : 'Verifikasi'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: isLoading
                              ? null
                              : () => unawaited(
                                    widget.state.resendEmailVerification(),
                                  ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Kirim ulang kode'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        if (canSkip) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : widget.state.continueAfterEmailVerification,
                            child: const Text('Lanjutkan dulu'),
                          ),
                        ],
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _AuthBanner(message: message);
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
