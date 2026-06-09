import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
            icon: Icon(Icons.edit_outlined, size: 20.r),
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

            SizedBox(height: 20.h),

            // Settings sections
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Account',
                      style: AppTextStyles.labelMedium.copyWith(
                        letterSpacing: 1.0,
                        color: AppColors.textTertiary,
                      )),
                  SizedBox(height: 8.h),
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
                  SizedBox(height: 20.h),

                  Text('Device',
                      style: AppTextStyles.labelMedium.copyWith(
                        letterSpacing: 1.0,
                        color: AppColors.textTertiary,
                      )),
                  SizedBox(height: 8.h),
                  _SettingsCard(
                    items: [
                      _SettingsItem(
                        icon: Icons.bluetooth_rounded,
                        label: 'Paired Device',
                        subtitle: 'DriveMetrics-A1B2',
                        onTap: () => context.push(AppRoutes.devicePairing),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(6.r),
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
                  SizedBox(height: 20.h),

                  Text('Preferences',
                      style: AppTextStyles.labelMedium.copyWith(
                        letterSpacing: 1.0,
                        color: AppColors.textTertiary,
                      )),
                  SizedBox(height: 8.h),
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
                  SizedBox(height: 20.h),

                  Text('Support',
                      style: AppTextStyles.labelMedium.copyWith(
                        letterSpacing: 1.0,
                        color: AppColors.textTertiary,
                      )),
                  SizedBox(height: 8.h),
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
                  SizedBox(height: 20.h),

                  // Logout
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.login),
                    icon: Icon(Icons.logout_rounded,
                        size: 18.r, color: AppColors.danger),
                    label: Text('Sign Out',
                        style: AppTextStyles.buttonLarge
                            .copyWith(color: AppColors.danger)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      foregroundColor: AppColors.danger,
                    ),
                  ),
                  SizedBox(height: 40.h),
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
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80.r,
            height: 80.r,
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
          SizedBox(height: 14.h),
          Text(user.fullName as String, style: AppTextStyles.h2),
          SizedBox(height: 2.h),
          Text(user.email as String, style: AppTextStyles.bodyMedium),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.scoreColorLight(avgScore),
              borderRadius: BorderRadius.circular(20.r),
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
      padding: EdgeInsets.symmetric(vertical: 16.h),
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
          SizedBox(height: 2.h),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36.h, color: AppColors.border);
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
        borderRadius: BorderRadius.circular(16.r),
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
      borderRadius: BorderRadius.circular(16.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
        child: Row(
          children: [
            Container(
              width: 34.r,
              height: 34.r,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Icon(icon, size: 17.r, color: AppColors.primary),
            ),
            SizedBox(width: 14.w),
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
                    ? Icon(Icons.chevron_right_rounded,
                        size: 18.r, color: AppColors.textTertiary)
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
