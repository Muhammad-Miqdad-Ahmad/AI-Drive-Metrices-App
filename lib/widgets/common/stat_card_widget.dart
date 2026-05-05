import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/models.dart';

// ─── Stat Card ────────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    this.iconColor,
    this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    final iColor = iconColor ?? AppColors.primary;
    final iBg = iconBg ?? AppColors.primarySurface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iColor),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppTextStyles.h2),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit!, style: AppTextStyles.bodySmall),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

// ─── Event Badge ──────────────────────────────────────────────────────────
class EventBadge extends StatelessWidget {
  final TripEventType type;
  final bool compact;

  const EventBadge({super.key, required this.type, this.compact = false});

  _EventStyle get _style {
    switch (type) {
      case TripEventType.harshBraking:
        return const _EventStyle(
          icon: Icons.car_crash_rounded,
          label: 'Harsh Braking',
          color: AppColors.danger,
          bg: AppColors.dangerLight,
        );
      case TripEventType.sharpTurn:
        return const _EventStyle(
          icon: Icons.turn_right_rounded,
          label: 'Sharp Turn',
          color: AppColors.warning,
          bg: AppColors.warningLight,
        );
      case TripEventType.speeding:
        return const _EventStyle(
          icon: Icons.speed_rounded,
          label: 'Speeding',
          color: AppColors.danger,
          bg: AppColors.dangerLight,
        );
      case TripEventType.collision:
        return const _EventStyle(
          icon: Icons.warning_rounded,
          label: 'Collision',
          color: AppColors.danger,
          bg: AppColors.dangerLight,
        );
      case TripEventType.hardAccel:
        return const _EventStyle(
          icon: Icons.trending_up_rounded,
          label: 'Hard Accel',
          color: AppColors.warning,
          bg: AppColors.warningLight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: compact ? 12 : 14, color: s.color),
          const SizedBox(width: 4),
          Text(
            s.label,
            style: (compact
                    ? AppTextStyles.overline
                    : AppTextStyles.labelSmall)
                .copyWith(color: s.color),
          ),
        ],
      ),
    );
  }
}

class _EventStyle {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;

  const _EventStyle({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
  });
}

// ─── Section Header ───────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.h3),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

// ─── Health Bar ───────────────────────────────────────────────────────────
class HealthBar extends StatefulWidget {
  final String label;
  final double value; // 0–100
  final IconData icon;

  const HealthBar({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  State<HealthBar> createState() => _HealthBarState();
}

class _HealthBarState extends State<HealthBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0, end: widget.value / 100).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.scoreColor(widget.value);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.label, style: AppTextStyles.labelLarge)),
              Text(
                '${widget.value.toInt()}%',
                style: AppTextStyles.labelMedium.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _anim.value,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
