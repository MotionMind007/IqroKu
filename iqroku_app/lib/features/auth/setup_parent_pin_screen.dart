import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';

class SetupParentPinScreen extends StatefulWidget {
  const SetupParentPinScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<SetupParentPinScreen> createState() => _SetupParentPinScreenState();
}

class _SetupParentPinScreenState extends State<SetupParentPinScreen> {
  final pinController = TextEditingController();
  final confirmPinController = TextEditingController();

  @override
  void dispose() {
    pinController.dispose();
    confirmPinController.dispose();
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
                  const SizedBox(height: 28),
                  Center(
                    child: Image.asset(
                      AppAssets.parentAvatar,
                      width: 150,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Buat PIN Orang Tua',
                    textAlign: TextAlign.center,
                    style: AppText.hero.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PIN ini dipakai saat masuk ke mode orang tua.',
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'PIN Orang Tua (4 digit)',
                            prefixIcon: Icon(Icons.pin_outlined),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmPinController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Konfirmasi PIN',
                            prefixIcon: Icon(Icons.pin_outlined),
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        if (widget.state.authError != null) ...[
                          const SizedBox(height: 12),
                          _AuthErrorBanner(message: widget.state.authError!),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isLoading ? 'Menyimpan...' : 'Simpan PIN',
                            style: const TextStyle(fontWeight: FontWeight.w800),
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

  void _submit() {
    final pin = pinController.text.trim();
    final confirm = confirmPinController.text.trim();

    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN harus 4 digit angka.')));
      return;
    }
    if (pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi PIN belum sama.')),
      );
      return;
    }

    unawaited(widget.state.completeParentPinSetup(pin));
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
