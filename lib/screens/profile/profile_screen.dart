import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/mock_data_service.dart';
import '../../app_router.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockDataService.currentUser;
    final trips = MockDataService.trips;
    final avgScore = trips.map((t) => t.score.overall).reduce((a, b) => a + b) /
        trips.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            _ProfileHeader(user: user, avgScore: avgScore),

            // Stats row
            _StatsRow(trips: trips),

            const SizedBox(height: 20),

            // Settings sections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Account',
                      style: AppTextStyles.labelMedium.copyWith(
                        letterSpacing: 1.0,
                        color: AppColors.textTertiary,
                      )),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    items: [
                      _SettingsItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Edit Profile',
                        onTap: () {},
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
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text('Device',
                      style: AppTextStyles.labelMedium.copyWith(
                        letterSpacing: 1.0,
                        color: AppColors.textTertiary,
                      )),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    items: [
                      _SettingsItem(
                        icon: Icons.bluetooth_rounded,
                        label: 'Paired Device',
                        subtitle: 'DriveMetrics-A1B2',
                        onTap: () => context.push(AppRoutes.devicePairing),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Connected',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.success)),
                        ),
                      ),
                      _SettingsItem(
                        icon: Icons.tune_rounded,
                        label: 'Sensor Calibration',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text('Preferences',
                      style: AppTextStyles.labelMedium.copyWith(
                        letterSpacing: 1.0,
                        color: AppColors.textTertiary,
                      )),
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

                  Text('Support',
                      style: AppTextStyles.labelMedium.copyWith(
                        letterSpacing: 1.0,
                        color: AppColors.textTertiary,
                      )),
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

                  // Logout
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.login),
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
}

class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  final double avgScore;
  const _ProfileHeader({required this.user, required this.avgScore});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Avatar
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
                (user.fullName as String)
                    .split(' ')
                    .map((w) => w[0])
                    .take(2)
                    .join(),
                style: AppTextStyles.h2.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(user.fullName as String, style: AppTextStyles.h2),
          const SizedBox(height: 2),
          Text(user.email as String, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 10),
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

class _StatsRow extends StatelessWidget {
  final List trips;
  const _StatsRow({required this.trips});

  @override
  Widget build(BuildContext context) {
    final totalKm = trips.fold(0.0, (s, t) => s + (t.distanceKm as double));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _StatItem(value: '${trips.length}', label: 'Trips'),
          _Divider(),
          _StatItem(value: totalKm.toStringAsFixed(0), label: 'Total km'),
          _Divider(),
          const _StatItem(value: 'A', label: 'Best Grade'),
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.border);
  }
}

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
          final i = entry.key;
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
