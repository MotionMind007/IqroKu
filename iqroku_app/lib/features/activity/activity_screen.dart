import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../models/prayer_models.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key, required this.state, this.onBack});

  final IqrokuState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return switch (state.activityView) {
      ActivityView.schedule => PrayerScheduleScreen(
        state: state,
        onBack: onBack,
      ),
      ActivityView.qibla => QiblaCompassScreen(state: state, onBack: onBack),
    };
  }
}

class PrayerScheduleScreen extends StatelessWidget {
  const PrayerScheduleScreen({super.key, required this.state, this.onBack});

  final IqrokuState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: ListView(
        padding: AppInsets.page,
        children: [
          AppTopBar(
            title: 'Jadwal Solat',
            trailing: Icons.tune,
            onBack: onBack ?? state.goHome,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18),
              const SizedBox(width: 6),
              Text(state.prayerLocationLabel, style: AppText.bodyStrong),
              const Spacer(),
              IconButton(
                tooltip: 'Muat ulang jadwal',
                onPressed: state.islamicActivityLoading
                    ? null
                    : () => unawaited(state.loadIslamicActivity()),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(state.prayerDateLabel, style: AppText.caption),
          if (state.islamicActivityLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.line,
            ),
          ],
          if (state.islamicActivityError != null) ...[
            const SizedBox(height: 12),
            _ActivityErrorCard(message: state.islamicActivityError!),
          ],
          const SizedBox(height: 18),
          PrayerHeroCard(
            compact: false,
            prayerName: state.activePrayerTime.name,
            prayerTime: state.activePrayerTime.time,
          ),
          const SizedBox(height: 14),
          ...state.prayerTimes.map((time) => PrayerTimeRow(time: time)),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class PrayerTimeRow extends StatelessWidget {
  const PrayerTimeRow({super.key, required this.time});

  final PrayerTime time;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: time.active ? AppColors.mint : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: time.active ? AppColors.primary : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _iconFor(time.name),
            color: time.active ? AppColors.primary : AppColors.gold,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(time.name, style: AppText.bodyStrong)),
          Text(time.time, style: AppText.bodyStrong),
          if (time.active) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.notifications_active,
              color: AppColors.primary,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconFor(String name) {
    return switch (name) {
      'Imsak' => Icons.nightlight_round,
      'Subuh' => Icons.wb_twilight,
      'Terbit' => Icons.wb_sunny_outlined,
      'Dzuhur' => Icons.light_mode_outlined,
      'Ashar' => Icons.mosque_outlined,
      'Maghrib' => Icons.sunny_snowing,
      _ => Icons.dark_mode_outlined,
    };
  }
}

class QiblaCard extends StatelessWidget {
  const QiblaCard({
    super.key,
    required this.qiblaDegrees,
    required this.headingDegrees,
  });

  final double qiblaDegrees;
  final double? headingDegrees;

  @override
  Widget build(BuildContext context) {
    final heading = headingDegrees;
    final relativeDegrees = heading == null
        ? qiblaDegrees
        : (qiblaDegrees - heading + 360) % 360;
    final instruction = _instructionFor(relativeDegrees);

    return Column(
      children: [
        SizedBox(
          width: 310,
          height: 350,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 264,
                height: 264,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF2E8D2),
                  border: Border.all(color: const Color(0xFF9A7042), width: 8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
              ),
              const Positioned(top: 48, child: _CompassText('0')),
              const Positioned(right: 48, child: _CompassText('90')),
              const Positioned(bottom: 46, child: _CompassText('180')),
              const Positioned(left: 48, child: _CompassText('270')),
              ...List.generate(36, (index) {
                final angle = index * 10 * math.pi / 180;
                final longTick = index % 3 == 0;
                return Transform.rotate(
                  angle: angle,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 48),
                      width: longTick ? 3 : 2,
                      height: longTick ? 14 : 8,
                      color: const Color(0xFF8E6B43),
                    ),
                  ),
                );
              }),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                child: Opacity(
                  opacity: 0.15,
                  child: Image.asset(AppAssets.kabah, fit: BoxFit.contain),
                ),
              ),
              Transform.rotate(
                angle: relativeDegrees * math.pi / 180,
                child: CustomPaint(
                  size: const Size(62, 250),
                  painter: _QiblaNeedlePainter(),
                ),
              ),
              Positioned(
                left: 70,
                bottom: 28,
                child: Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE35B7B),
                      width: 4,
                    ),
                  ),
                  child: Image.asset(AppAssets.kabah, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 10,
                child: Container(
                  width: 8,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          heading == null ? 'Menunggu sensor kompas' : instruction,
          textAlign: TextAlign.center,
          style: AppText.hero.copyWith(color: Colors.white, fontSize: 34),
        ),
        const SizedBox(height: 6),
        Text(
          'Selisih ${relativeDegrees.round()} deg dari arah kiblat',
          style: AppText.caption.copyWith(color: Colors.white70),
        ),
      ],
    );
  }

  String _instructionFor(double degrees) {
    if (degrees <= 8 || degrees >= 352) {
      return 'Arah sudah tepat';
    }
    if (degrees < 180) {
      return 'Berbaliklah ke kanan';
    }
    return 'Berbaliklah ke kiri';
  }
}

class QiblaCompassScreen extends StatelessWidget {
  const QiblaCompassScreen({super.key, required this.state, this.onBack});

  final IqrokuState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF00443C),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF005246), Color(0xFF003B35)],
        ),
      ),
      child: ListView(
        padding: AppInsets.page,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack ?? state.goHome,
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Kiblat',
                style: AppText.hero.copyWith(color: Colors.white, fontSize: 30),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _QiblaChip(
                  icon: Icons.flag,
                  label: state.activityLocationSource == LocationSource.device
                      ? state.prayerLocationLabel
                      : 'Fallback Papua',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QiblaChip(
                  icon: Icons.check_circle,
                  label: state.activityLocationSource == LocationSource.device
                      ? 'Akurasi GPS'
                      : 'Cek izin lokasi',
                ),
              ),
              const SizedBox(width: 8),
              _QiblaChip(
                icon: Icons.explore,
                label: '${state.qiblaDegrees.round()}',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${state.prayerLocationLabel} - ${state.activityLatitude.toStringAsFixed(4)}, ${state.activityLongitude.toStringAsFixed(4)}',
            style: AppText.mini.copyWith(color: Colors.white70),
          ),
          if (state.islamicActivityLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.line,
            ),
          ],
          const SizedBox(height: 18),
          StreamBuilder<CompassEvent>(
            stream: FlutterCompass.events,
            builder: (context, snapshot) {
              final heading = snapshot.data?.heading;
              return QiblaCard(
                qiblaDegrees: state.qiblaDegrees,
                headingDegrees: heading,
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                Image.asset(AppAssets.kabah, width: 44, height: 44),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Kalibrasi dengan menggerakkan HP membentuk angka 8. Jauhkan dari logam dan magnet.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: state.islamicActivityLoading
                      ? null
                      : () => unawaited(state.loadIslamicActivity()),
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QiblaChip extends StatelessWidget {
  const _QiblaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompassText extends StatelessWidget {
  const _CompassText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6E5538),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _QiblaNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final top = Offset(size.width / 2, 0);
    final bottom = Offset(size.width / 2, size.height);
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFE35B7B);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(center.dx - 26, center.dy)
        ..lineTo(center.dx, center.dy + 22)
        ..lineTo(center.dx + 26, center.dy)
        ..close(),
      paint,
    );

    paint.color = const Color(0xFFD25072);
    canvas.drawPath(
      Path()
        ..moveTo(bottom.dx, bottom.dy)
        ..lineTo(center.dx - 26, center.dy)
        ..lineTo(center.dx, center.dy + 22)
        ..lineTo(center.dx + 26, center.dy)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ActivityErrorCard extends StatelessWidget {
  const _ActivityErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_outlined, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppText.caption)),
        ],
      ),
    );
  }
}
