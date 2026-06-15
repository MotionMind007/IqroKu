import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';

class SetupChildScreen extends StatefulWidget {
  const SetupChildScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<SetupChildScreen> createState() => _SetupChildScreenState();
}

class _SetupChildScreenState extends State<SetupChildScreen> {
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  int selectedAvatar = 0;

  static const _avatars = [
    _AvatarOption(asset: AppAssets.avatarMale, label: 'Putra', color: AppColors.blue),
    _AvatarOption(asset: AppAssets.avatarFemale, label: 'Putri', color: AppColors.coral),
  ];

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AppPage(
              child: ListView(
                padding: AppInsets.page,
                children: [
                  const SizedBox(height: 24),
                  // Illustration
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _avatars[selectedAvatar]
                            .color
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          _avatars[selectedAvatar].asset,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Tambah Profil Anak',
                    textAlign: TextAlign.center,
                    style: AppText.hero.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Buat profil anak untuk menyimpan progress belajar Iqro dan hafalan.',
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: 28),

                  // Avatar picker
                  const Text('Pilih Avatar', style: AppText.sectionTitle),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_avatars.length, (index) {
                      final avatar = _avatars[index];
                      final isSelected = selectedAvatar == index;
                      return GestureDetector(
                        onTap: () => setState(() => selectedAvatar = index),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? avatar.color.withValues(alpha: 0.15)
                                    : AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? avatar.color
                                      : AppColors.line,
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  avatar.asset,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              avatar.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? avatar.color
                                    : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Form
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama Anak',
                            hintText: 'Contoh: Nedy',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Usia (opsional)',
                            hintText: 'Contoh: 7',
                            prefixIcon: Icon(Icons.cake_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '* Usia opsional, bisa diisi nanti',
                            style: AppText.mini.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action buttons
                  FilledButton(
                    onPressed: nameController.text.trim().isNotEmpty
                        ? widget.state.completeSetup
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Simpan & Mulai Belajar',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: widget.state.completeSetup,
                      child: Text(
                        'Lewati, tambah nanti',
                        style: AppText.bodyStrong.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
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

class _AvatarOption {
  const _AvatarOption({
    required this.asset,
    required this.label,
    required this.color,
  });

  final String asset;
  final String label;
  final Color color;
}
