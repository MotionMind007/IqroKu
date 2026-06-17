import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({
    super.key,
    required this.state,
    required this.isParentMode,
    this.childName,
  });

  final IqrokuState state;
  final bool isParentMode;
  final String? childName;

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  final List<String> _pin = [];
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final title = widget.isParentMode
        ? 'Masukkan PIN Orang Tua'
        : 'Masukkan PIN ${widget.childName ?? "Anak"}';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isParentMode ? Icons.lock_outline : Icons.child_care,
                    size: 64,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: AppText.hero.copyWith(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // PIN dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final filled = index < _pin.length;
                      return Container(
                        width: 56,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: filled
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _error != null
                                ? AppColors.coral
                                : filled
                                    ? AppColors.primary
                                    : AppColors.line,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: filled
                              ? const Icon(Icons.circle, size: 12, color: Colors.white)
                              : null,
                        ),
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: AppText.caption.copyWith(color: AppColors.coral),
                    ),
                  ],
                  const SizedBox(height: 48),
                  // Number pad
                  _buildNumberPad(),
                  const SizedBox(height: 24),
                  // Back button
                  TextButton(
                    onPressed: () {
                      widget.state.selectMode(AppMode.none);
                    },
                    child: const Text('Kembali'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('1'),
            _buildNumberButton('2'),
            _buildNumberButton('3'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('4'),
            _buildNumberButton('5'),
            _buildNumberButton('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberButton('7'),
            _buildNumberButton('8'),
            _buildNumberButton('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 88),
            _buildNumberButton('0'),
            _buildDeleteButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : () => _onNumberPressed(number),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _isLoading ? null : _onDeletePressed,
            child: const Center(
              child: Icon(Icons.backspace_outlined, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  void _onNumberPressed(String number) {
    if (_pin.length >= 4) return;

    setState(() {
      _pin.add(number);
      _error = null;
    });

    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onDeletePressed() {
    if (_pin.isEmpty) return;

    setState(() {
      _pin.removeLast();
      _error = null;
    });
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pin = _pin.join();

      if (widget.isParentMode) {
        final valid = await widget.state.verifyParentPin(pin);
        if (valid) {
          widget.state.enterParentMode();
        } else {
          setState(() {
            _error = 'PIN salah';
            _pin.clear();
          });
        }
      } else {
        final success = await widget.state.childLogin(pin);
        if (!success) {
          setState(() {
            _error = 'PIN salah';
            _pin.clear();
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan';
        _pin.clear();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
