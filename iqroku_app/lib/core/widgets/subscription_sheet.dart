import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<void> showIqrokuPlusSheet({
  required BuildContext context,
  required VoidCallback onConfirm,
  required bool active,
  required String renewalLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return IqrokuPlusSheet(
        active: active,
        renewalLabel: renewalLabel,
        onConfirm: () {
          showDialog<void>(
            context: sheetContext,
            builder: (dialogContext) {
              return AlertDialog(
                title: const Text('Aktifkan IqroKu Plus?'),
                content: const Text(
                  'Prototype ini belum memproses pembayaran asli. Setelah dikonfirmasi, akses Plus akan langsung aktif.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.pop(sheetContext);
                      onConfirm();
                    },
                    child: const Text('Aktifkan'),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

class IqrokuPlusSheet extends StatelessWidget {
  const IqrokuPlusSheet({
    super.key,
    required this.active,
    required this.renewalLabel,
    required this.onConfirm,
  });

  final bool active;
  final String renewalLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IqroKu Plus', style: AppText.title),
          const SizedBox(height: 8),
          Text(
            active
                ? 'Subscription aktif. Semua materi dan fitur parent dashboard terbuka.'
                : 'Buka semua materi Iqro dan fitur pantau belajar anak dengan subscription bulanan.',
            style: AppText.body,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rp49.000/bulan', style: AppText.title),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'Aktif sampai $renewalLabel'
                      : 'Akses langsung aktif setelah pembayaran berhasil.',
                  style: AppText.caption.copyWith(color: AppColors.text),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SubscriptionBenefit(text: 'Buka semua halaman Iqro 1-6'),
          const _SubscriptionBenefit(text: 'Tambah hingga 5 profil anak'),
          const _SubscriptionBenefit(text: 'Dashboard progress per anak'),
          const _SubscriptionBenefit(
            text: 'Catatan belajar dan riwayat rekaman',
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: active ? null : onConfirm,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(active ? 'IqroKu Plus aktif' : 'Lanjutkan pembayaran'),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(active ? 'Tutup' : 'Nanti dulu'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionBenefit extends StatelessWidget {
  const _SubscriptionBenefit({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.bodyStrong)),
        ],
      ),
    );
  }
}
