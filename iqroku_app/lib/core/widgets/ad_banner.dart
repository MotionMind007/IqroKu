import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class IqrokuAdBanner extends StatelessWidget {
  const IqrokuAdBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: AppColors.gold,
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Iklan', style: AppText.smallStrong),
                if (!compact)
                  Text(
                    'Area ini siap diganti AdMob saat akun iklan sudah aktif.',
                    style: AppText.mini.copyWith(color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
