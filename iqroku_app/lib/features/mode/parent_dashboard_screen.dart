import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/assets/app_assets.dart';
import '../../core/theme/app_theme.dart';
import '../../features/activity/activity_screen.dart';
import '../../features/prayers/daily_prayers_screen.dart';
import '../../features/quran/quran_screen.dart';
import '../../models/profile_models.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _selectedTab = 0;
  _ParentFeature? _activeFeature;

  void _openFeature(_ParentFeature feature) {
    setState(() {
      _activeFeature = feature;
      _selectedTab = 1;
    });
  }

  void _closeFeature() {
    setState(() => _activeFeature = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Orang Tua'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => widget.state.logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            color: AppColors.surface,
            child: Row(
              children: [
                _buildTab(0, Icons.rate_review, 'Review'),
                _buildTab(1, Icons.apps, 'Fitur'),
                _buildTab(2, Icons.notifications, 'Notifikasi'),
                _buildTab(3, Icons.settings, 'Pengaturan'),
              ],
            ),
          ),
          // Content
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _ReviewTab(state: widget.state),
                _FeatureTab(
                  state: widget.state,
                  activeFeature: _activeFeature,
                  onOpenFeature: _openFeature,
                  onCloseFeature: _closeFeature,
                ),
                _NotificationTab(state: widget.state),
                _SettingsTab(state: widget.state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppText.mini.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ParentFeature { quran, prayerSchedule, qibla, dailyPrayers }

class _FeatureTab extends StatelessWidget {
  const _FeatureTab({
    required this.state,
    required this.activeFeature,
    required this.onOpenFeature,
    required this.onCloseFeature,
  });

  final IqrokuState state;
  final _ParentFeature? activeFeature;
  final ValueChanged<_ParentFeature> onOpenFeature;
  final VoidCallback onCloseFeature;

  @override
  Widget build(BuildContext context) {
    final feature = activeFeature;
    if (feature != null) {
      return _buildFeature(feature);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ParentHero(state: state),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: [
            _FeatureCard(
              asset: AppAssets.quranNew,
              title: "Al-Qur'an",
              subtitle: 'Baca, hafalan, dan murottal',
              onTap: () {
                state.backToQuranList();
                onOpenFeature(_ParentFeature.quran);
              },
            ),
            _FeatureCard(
              asset: AppAssets.prayerTime,
              title: 'Jadwal Solat',
              subtitle: 'Waktu solat harian',
              onTap: () {
                state.activityView = ActivityView.schedule;
                onOpenFeature(_ParentFeature.prayerSchedule);
              },
            ),
            _FeatureCard(
              asset: AppAssets.qiblaCompass,
              title: 'Kiblat',
              subtitle: 'Arah kiblat keluarga',
              onTap: () {
                state.activityView = ActivityView.qibla;
                onOpenFeature(_ParentFeature.qibla);
              },
            ),
            _FeatureCard(
              asset: AppAssets.doaDoa,
              title: 'Doa Harian',
              subtitle: 'Kumpulan doa anak',
              onTap: () {
                state.loadDailyPrayers(forceRefresh: true);
                onOpenFeature(_ParentFeature.dailyPrayers);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeature(_ParentFeature feature) {
    return switch (feature) {
      _ParentFeature.quran => QuranScreen(state: state, onBack: onCloseFeature),
      _ParentFeature.prayerSchedule => PrayerScheduleScreen(
        state: state,
        onBack: onCloseFeature,
      ),
      _ParentFeature.qibla => QiblaCompassScreen(
        state: state,
        onBack: onCloseFeature,
      ),
      _ParentFeature.dailyPrayers => DailyPrayersScreen(
        state: state,
        onBack: onCloseFeature,
      ),
    };
  }
}

class _ParentHero extends StatelessWidget {
  const _ParentHero({required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    final parentName = state.parentAccount?.name ?? 'Orang Tua';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipOval(
              child: Image.asset(
                AppAssets.parentAvatar,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(parentName, style: AppText.bodyStrong),
                  const SizedBox(height: 4),
                  Text(
                    'Akses cepat ibadah keluarga',
                    style: AppText.caption.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String asset;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(child: Image.asset(asset, fit: BoxFit.contain)),
              ),
              const SizedBox(height: 10),
              Text(title, style: AppText.bodyStrong),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTab extends StatefulWidget {
  const _ReviewTab({required this.state});

  final IqrokuState state;

  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  List<Map<String, Object?>> _pendingReviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingReviews();
  }

  Future<void> _loadPendingReviews() async {
    setState(() => _isLoading = true);
    try {
      _pendingReviews = await widget.state.authService.getPendingReviews();
    } catch (e) {
      debugPrint('Failed to load reviews: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pendingReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('Tidak ada rekaman yang perlu direview', style: AppText.body),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingReviews,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingReviews.length,
        itemBuilder: (context, index) {
          final review = _pendingReviews[index];
          return _ReviewCard(
            state: widget.state,
            review: review,
            onApprove: () => _approveReview(review),
            onRepeat: (fromPage) => _repeatReview(review, fromPage),
          );
        },
      ),
    );
  }

  Future<void> _approveReview(Map<String, Object?> review) async {
    try {
      await widget.state.authService.approveReview(review['id'] as String);
      if (!mounted) return;
      await widget.state.refreshChildrenFromBackend();
      if (!mounted) return;
      _loadPendingReviews();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bacaan berhasil di-approve')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> _repeatReview(Map<String, Object?> review, int fromPage) async {
    try {
      await widget.state.authService.repeatReview(
        attemptId: review['id'] as String,
        fromPage: fromPage,
      );
      if (!mounted) return;
      await widget.state.refreshChildrenFromBackend();
      if (!mounted) return;
      _loadPendingReviews();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Anak diminta mengulang dari halaman $fromPage'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.state,
    required this.review,
    required this.onApprove,
    required this.onRepeat,
  });

  final IqrokuState state;
  final Map<String, Object?> review;
  final VoidCallback onApprove;
  final Function(int fromPage) onRepeat;

  @override
  Widget build(BuildContext context) {
    final childName = review['child_name'] as String? ?? 'Anak';
    final bookId = review['book_id'] as int? ?? 1;
    final pageNumber = review['page_number'] as int? ?? 1;
    final duration = review['duration_seconds'] as int? ?? 0;
    final attemptId = review['id'] as String? ?? '';
    final audioPath =
        review['audio_path'] as String? ?? review['audio_url'] as String?;

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final isPlaying = state.playingAttemptId == attemptId;
        final canPlay = attemptId.isNotEmpty && audioPath != null;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.child_care, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(childName, style: AppText.bodyStrong)),
                    Text(
                      'Iqro $bookId - Hal $pageNumber',
                      style: AppText.caption.copyWith(color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Durasi: ${duration}s', style: AppText.caption),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.stop_circle : Icons.play_arrow,
                        ),
                        color: AppColors.primary,
                        onPressed: canPlay
                            ? () => state.toggleReviewPlayback(
                                attemptId: attemptId,
                                audioPath: audioPath,
                              )
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          canPlay
                              ? isPlaying
                                    ? 'Memutar rekaman'
                                    : 'Putar rekaman'
                              : 'Rekaman belum tersedia',
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.playbackError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.playbackError!,
                    style: AppText.caption.copyWith(color: AppColors.coral),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRepeatDialog(context),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Perlu Ulang'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.coral,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check),
                        label: const Text('Lancar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRepeatDialog(BuildContext context) {
    final pageController = TextEditingController(
      text: '${review['page_number'] ?? 1}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ulangi dari Halaman'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Anak akan dimulai ulang dari halaman yang dipilih:'),
            const SizedBox(height: 16),
            TextField(
              controller: pageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nomor Halaman',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(pageController.text) ?? 1;
              Navigator.pop(context);
              onRepeat(page);
            },
            child: const Text('Ulangi'),
          ),
        ],
      ),
    );
  }
}

class _NotificationTab extends StatefulWidget {
  const _NotificationTab({required this.state});

  final IqrokuState state;

  @override
  State<_NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends State<_NotificationTab> {
  List<Map<String, Object?>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      _notifications = await widget.state.authService.getNotifications();
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: AppColors.muted),
            const SizedBox(height: 16),
            Text('Belum ada notifikasi', style: AppText.body),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return _NotificationCard(
            notification: notif,
            onTap: () => _markAsRead(notif),
          );
        },
      ),
    );
  }

  Future<void> _markAsRead(Map<String, Object?> notif) async {
    final id = notif['id'] as String?;
    if (id != null) {
      await widget.state.authService.markNotificationRead(id);
      _loadNotifications();
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final Map<String, Object?> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final read = notification['read'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: read ? null : AppColors.primary.withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: read ? AppColors.muted : AppColors.primary,
          child: const Icon(Icons.notifications, color: Colors.white, size: 20),
        ),
        title: Text(title, style: AppText.bodyStrong),
        subtitle: Text(message, style: AppText.caption),
        trailing: read
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.state});

  final IqrokuState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: 'Profil Anak',
          children: state.childProfiles.map((child) {
            return _SettingsTile(
              icon: Icons.child_care,
              asset: _childAvatarFor(child),
              title: child.name,
              subtitle: '${child.age} tahun • Atur PIN & Jadwal',
              onTap: () => _showChildSettings(context, child),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Akun',
          children: [
            _SettingsTile(
              icon: Icons.lock,
              title: 'Ubah PIN Orang Tua',
              onTap: () => _showChangePinDialog(context, isParent: true),
            ),
            _SettingsTile(
              icon: Icons.exit_to_app,
              title: 'Keluar Mode Orang Tua',
              onTap: () => state.exitToModeSelection(),
            ),
            _SettingsTile(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () => state.logout(),
            ),
          ],
        ),
      ],
    );
  }

  void _showChildSettings(BuildContext context, ChildProfile child) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ChildSettingsSheet(state: state, child: child),
    );
  }

  void _showChangePinDialog(
    BuildContext context, {
    required bool isParent,
    String? childId,
    String? childName,
  }) {
    showDialog(
      context: context,
      builder: (context) => _ChangePinDialog(
        state: state,
        isParent: isParent,
        childId: childId,
        childName: childName,
      ),
    );
  }
}

class _ChildSettingsSheet extends StatelessWidget {
  const _ChildSettingsSheet({required this.state, required this.child});

  final IqrokuState state;
  final ChildProfile child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  _childAvatarFor(child),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                child.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsTile(
            icon: Icons.lock,
            title: 'Atur PIN Anak',
            subtitle: 'PIN untuk akses mode anak',
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => _ChangePinDialog(
                  state: state,
                  isParent: false,
                  childId: child.id,
                  childName: child.name,
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.schedule,
            title: 'Atur Jadwal Belajar',
            subtitle: 'Waktu belajar harian',
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) =>
                    _ScheduleDialog(state: state, child: child),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog({
    required this.state,
    required this.isParent,
    this.childId,
    this.childName,
  });

  final IqrokuState state;
  final bool isParent;
  final String? childId;
  final String? childName;

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.isParent
        ? 'Ubah PIN Orang Tua'
        : 'Atur PIN ${widget.childName ?? "Anak"}';

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'PIN Baru (4 digit)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Konfirmasi PIN',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _savePin,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _savePin() async {
    final pin = _pinController.text;
    final confirm = _confirmController.text;

    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'PIN harus 4 digit angka');
      return;
    }

    if (pin != confirm) {
      setState(() => _error = 'PIN tidak cocok');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.isParent) {
        await widget.state.setParentPin(pin);
      } else {
        await widget.state.setChildPin(widget.childId!, pin);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PIN berhasil disimpan')));
      }
    } catch (e) {
      setState(() => _error = 'Gagal menyimpan PIN');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({required this.state, required this.child});

  final IqrokuState state;
  final ChildProfile child;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Mon-Fri
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Jadwal Belajar ${widget.child.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Waktu Belajar'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (time != null) setState(() => _startTime = time);
                  },
                  child: Text('Mulai: ${_startTime.format(context)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (time != null) setState(() => _endTime = time);
                  },
                  child: Text('Selesai: ${_endTime.format(context)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Hari Belajar'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildDayChip(1, 'Sen'),
              _buildDayChip(2, 'Sel'),
              _buildDayChip(3, 'Rab'),
              _buildDayChip(4, 'Kam'),
              _buildDayChip(5, 'Jum'),
              _buildDayChip(6, 'Sab'),
              _buildDayChip(7, 'Min'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveSchedule,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildDayChip(int day, String label) {
    final selected = _selectedDays.contains(day);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _selectedDays.add(day);
          } else {
            _selectedDays.remove(day);
          }
        });
      },
    );
  }

  Future<void> _saveSchedule() async {
    setState(() => _isLoading = true);

    try {
      await widget.state.authService.setChildSchedule(
        childId: widget.child.id,
        startTime:
            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        endTime:
            '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        days: _selectedDays.toList()..sort(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jadwal berhasil disimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.sectionTitle),
        const SizedBox(height: 8),
        Card(child: Column(children: children)),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.asset,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String? asset;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: asset == null
          ? Icon(icon, color: AppColors.primary)
          : ClipOval(
              child: Image.asset(
                asset!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

String _childAvatarFor(ChildProfile child) {
  return child.avatarAsset == AppAssets.avatarFemale
      ? AppAssets.femaleKid
      : AppAssets.boyKid;
}
