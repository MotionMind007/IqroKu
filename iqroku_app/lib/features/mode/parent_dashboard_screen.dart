import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key, required this.state});

  final IqrokuState state;

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  int _selectedTab = 0;

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
                _buildTab(1, Icons.notifications, 'Notifikasi'),
                _buildTab(2, Icons.settings, 'Pengaturan'),
              ],
            ),
          ),
          // Content
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _ReviewTab(state: widget.state),
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
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.muted),
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
            Icon(Icons.check_circle_outline, size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
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
      _loadPendingReviews();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bacaan berhasil di-approve')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _repeatReview(Map<String, Object?> review, int fromPage) async {
    try {
      await widget.state.authService.repeatReview(
        attemptId: review['id'] as String,
        fromPage: fromPage,
      );
      _loadPendingReviews();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anak diminta mengulang dari halaman $fromPage')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.onApprove,
    required this.onRepeat,
  });

  final Map<String, Object?> review;
  final VoidCallback onApprove;
  final Function(int fromPage) onRepeat;

  @override
  Widget build(BuildContext context) {
    final childName = review['child_name'] as String? ?? 'Anak';
    final bookId = review['book_id'] as int? ?? 1;
    final pageNumber = review['page_number'] as int? ?? 1;
    final duration = review['duration_seconds'] as int? ?? 0;

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
                Expanded(
                  child: Text(childName, style: AppText.bodyStrong),
                ),
                Text(
                  'Iqro $bookId - Hal $pageNumber',
                  style: AppText.caption.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Durasi: ${duration}s', style: AppText.caption),
            const SizedBox(height: 12),
            // Audio player placeholder
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {
                      // TODO: Play audio
                    },
                  ),
                  Expanded(
                    child: Text('Putar rekaman', style: AppText.caption),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRepeatDialog(context),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Ulangi'),
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
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

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
        trailing: read ? null : Container(
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
              title: child.name,
              subtitle: '${child.age} tahun',
              onTap: () {
                // TODO: Navigate to child settings
              },
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
              onTap: () {
                // TODO: Change parent PIN
              },
            ),
            _SettingsTile(
              icon: Icons.logout,
              title: 'Keluar',
              onTap: () => state.logout(),
            ),
          ],
        ),
      ],
    );
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
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
