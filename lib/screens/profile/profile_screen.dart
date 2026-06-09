import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/supabase_service.dart';
import '../../core/storage/local_storage_service.dart';
import '../../models/models.dart';
import '../../app_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  bool _loadingUser = true;

  // Live stats
  int    _totalTrips   = 0;
  double _totalKm      = 0;
  double _avgScore     = 0;
  String _bestGrade    = '—';
  bool   _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadStats();
  }

  Future<void> _loadUser() async {
    final user = await LocalStorageService.getCurrentUser();
    if (mounted) setState(() { _user = user; _loadingUser = false; });
  }

  Future<void> _loadStats() async {
    try {
      final token = await LocalStorageService.getDeviceToken();
      if (token == null) {
        if (mounted) setState(() => _loadingStats = false);
        return;
      }
      final svc   = SupabaseService(deviceToken: token);
      final stats = await svc.getDashboardStats();

      if (mounted) {
        setState(() {
          _totalTrips   = stats.totalTrips;
          _totalKm      = stats.totalKm;
          _avgScore     = stats.avgScore;
          _bestGrade    = DriverScoreModel.gradeFromScore(stats.bestScore);
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _logout() async {
    await LocalStorageService.logout();
    if (mounted) context.go(AppRoutes.login);
  }

  void _showEditProfile() {
    if (_user == null) return;
    showDialog(
      context: context,
      builder: (_) => _EditProfileDialog(
        user: _user!,
        onSaved: _loadUser,
      ),
    );
  }

  void _showChangePassword() {
    showDialog(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  void _showEditDeviceId() {
    if (_user == null) return;
    showDialog(
      context: context,
      builder: (_) => _EditDeviceIdDialog(
        currentDeviceId: _user!.deviceId ?? '',
        onSaved: () {
          _loadUser();
          _loadStats(); // Reload stats for new device
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _showEditProfile,
          ),
        ],
      ),
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _ProfileHeader(user: _user, avgScore: _avgScore),
                  _StatsRow(
                    totalTrips: _totalTrips,
                    totalKm: _totalKm,
                    bestGrade: _bestGrade,
                    loading: _loadingStats,
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Account'),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Icons.person_outline_rounded,
                              label: 'Edit Profile',
                              onTap: _showEditProfile,
                            ),
                            _SettingsItem(
                              icon: Icons.notifications_outlined,
                              label: 'Notifications',
                              onTap: () {},
                              trailing: _ToggleTrailing(),
                            ),
                            _SettingsItem(
                              icon: Icons.lock_outline_rounded,
                              label: 'Change Password',
                              onTap: _showChangePassword,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _sectionLabel('Device'),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Icons.memory_rounded,
                              label: 'Device ID',
                              subtitle: _user?.deviceId ?? 'Not set',
                              onTap: _showEditDeviceId,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_user?.deviceId != null &&
                                          _user!.deviceId!.isNotEmpty)
                                      ? AppColors.successLight
                                      : AppColors.danger
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (_user?.deviceId != null &&
                                          _user!.deviceId!.isNotEmpty)
                                      ? 'Active'
                                      : 'None',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: (_user?.deviceId != null &&
                                            _user!.deviceId!.isNotEmpty)
                                        ? AppColors.success
                                        : AppColors.danger,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _sectionLabel('Preferences'),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Icons.speed_rounded,
                              label: 'Speed Unit',
                              subtitle: 'km/h',
                              onTap: () {},
                            ),
                            _SettingsItem(
                              icon: Icons.language_rounded,
                              label: 'Language',
                              subtitle: 'English',
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _sectionLabel('Support'),
                        const SizedBox(height: 8),
                        _SettingsCard(
                          items: [
                            _SettingsItem(
                              icon: Icons.help_outline_rounded,
                              label: 'Help & FAQ',
                              onTap: () {},
                            ),
                            _SettingsItem(
                              icon: Icons.privacy_tip_outlined,
                              label: 'Privacy Policy',
                              onTap: () {},
                            ),
                            _SettingsItem(
                              icon: Icons.info_outline_rounded,
                              label: 'App Version',
                              subtitle: 'v1.0.0',
                              onTap: () {},
                              showArrow: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout_rounded,
                              size: 18, color: AppColors.danger),
                          label: Text('Sign Out',
                              style: AppTextStyles.buttonLarge
                                  .copyWith(color: AppColors.danger)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.danger),
                            foregroundColor: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: AppTextStyles.labelMedium.copyWith(
          letterSpacing: 1.0,
          color: AppColors.textTertiary,
        ),
      );
}

// ─── Profile Header ────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserModel? user;
  final double avgScore;
  const _ProfileHeader({required this.user, required this.avgScore});

  @override
  Widget build(BuildContext context) {
    final name     = user?.fullName ?? 'User';
    final email    = user?.email    ?? '';
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: AppColors.primaryShadow,
            ),
            child: Center(
              child: Text(
                initials,
                style: AppTextStyles.h2.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(name, style: AppTextStyles.h2),
          const SizedBox(height: 2),
          Text(email, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 10),
          if (avgScore > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.scoreColorLight(avgScore),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Avg Score: ${avgScore.toInt()} / 100',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.scoreColor(avgScore),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Stats Row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int    totalTrips;
  final double totalKm;
  final String bestGrade;
  final bool   loading;

  const _StatsRow({
    required this.totalTrips,
    required this.totalKm,
    required this.bestGrade,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Row(
              children: [
                _StatItem(value: '$totalTrips',                   label: 'Trips'),
                _Divider(),
                _StatItem(value: totalKm.toStringAsFixed(0),      label: 'Total km'),
                _Divider(),
                _StatItem(value: bestGrade,                       label: 'Best Grade'),
              ],
            ),
    );
  }
}

// ─── Shared small widgets ──────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.h2),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: AppColors.border);
}

// ─── Edit Profile Dialog ───────────────────────────────────────────────────

class _EditProfileDialog extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSaved;
  const _EditProfileDialog({required this.user, required this.onSaved});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _loading  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.user.fullName);
    _emailCtrl = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final err = await LocalStorageService.updateProfile(
      fullName: _nameCtrl.text.trim(),
      email:    _emailCtrl.text.trim(),
      deviceId: widget.user.deviceId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      setState(() => _error = err);
    } else {
      widget.onSaved();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile', style: AppTextStyles.h3),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(_error!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.danger)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Change Password Dialog ────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey     = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final err = await LocalStorageService.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword:     _newCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password', style: AppTextStyles.h3),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(_error!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.danger)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _currentCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Current Password',
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18, color: AppColors.textTertiary),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCtrl,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'New Password'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              decoration:
                  const InputDecoration(labelText: 'Confirm New Password'),
              validator: (v) =>
                  v != _newCtrl.text ? 'Passwords do not match' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Update'),
        ),
      ],
    );
  }
}

// ─── Edit Device ID Dialog ─────────────────────────────────────────────────

class _EditDeviceIdDialog extends StatefulWidget {
  final String currentDeviceId;
  final VoidCallback onSaved;
  const _EditDeviceIdDialog({
    required this.currentDeviceId,
    required this.onSaved,
  });

  @override
  State<_EditDeviceIdDialog> createState() => _EditDeviceIdDialogState();
}

class _EditDeviceIdDialogState extends State<_EditDeviceIdDialog> {
  late final TextEditingController _deviceCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _loading  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _deviceCtrl = TextEditingController(text: widget.currentDeviceId);
  }

  @override
  void dispose() {
    _deviceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final user = await LocalStorageService.getCurrentUser();
    if (user == null) {
      setState(() { _loading = false; _error = 'Not logged in.'; });
      return;
    }

    final err = await LocalStorageService.updateProfile(
      fullName: user.fullName,
      email:    user.email,
      deviceId: _deviceCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      setState(() => _error = err);
    } else {
      widget.onSaved();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device ID updated — data refreshed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Device ID', style: AppTextStyles.h3),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the ID of your Drive Metrics device. '
              'Changing it will load data for the new device.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.danger)),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _deviceCtrl,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                hintText: 'e.g. STM32_DEVICE_001',
                prefixIcon: Icon(Icons.memory_rounded, size: 20),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ─── Settings Card / Item ──────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i    = entry.key;
          final item = entry.value;
          return Column(
            children: [
              item,
              if (i < items.length - 1) const Divider(height: 1, indent: 52),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showArrow;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.trailing,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.labelLarge),
                  if (subtitle != null)
                    Text(subtitle!, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            trailing ??
                (showArrow
                    ? const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.textTertiary)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class _ToggleTrailing extends StatefulWidget {
  @override
  State<_ToggleTrailing> createState() => _ToggleTrailingState();
}

class _ToggleTrailingState extends State<_ToggleTrailing> {
  bool _value = true;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: _value,
      onChanged: (v) => setState(() => _value = v),
      activeThumbColor: AppColors.primary,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
