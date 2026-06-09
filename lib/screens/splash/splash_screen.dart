import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/storage/local_storage_service.dart';
import '../../app_router.dart';

// ─── Data ──────────────────────────────────────────────────────────────────

class _Stat {
  final String value;
  final String label;
  final IconData icon;
  const _Stat(this.value, this.label, this.icon);
}

const _stats = [
  _Stat('98%', 'Safety Rate', Icons.shield_outlined),
  _Stat('2.4M+', 'Trips Analyzed', Icons.route_outlined),
  _Stat('50ms', 'Real-time AI', Icons.bolt_outlined),
  _Stat('A+', 'Top Driver Grade', Icons.emoji_events_outlined),
];

// ─── Floating particle model ───────────────────────────────────────────────

class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  const _Particle(this.x, this.y, this.size, this.speed, this.opacity);
}

List<_Particle> _buildParticles(int count) {
  final rng = math.Random(42);
  return List.generate(
      count,
      (_) => _Particle(
            rng.nextDouble(),
            rng.nextDouble(),
            rng.nextDouble() * 5 + 2,
            rng.nextDouble() * 0.4 + 0.2,
            rng.nextDouble() * 0.35 + 0.08,
          ));
}

// ─── Screen ────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _master;
  late AnimationController _particles;
  late AnimationController _ticker;
  int _statIndex = 0;
  bool _statVisible = true;
  late AnimationController _pulse;

  final _particleList = _buildParticles(22);

  late Animation<double> _iconScale;
  late Animation<double> _iconFade;
  late Animation<double> _ringFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineFade;
  late Animation<Offset> _taglineSlide;
  late Animation<double> _statFade;
  late Animation<double> _dividerScale;
  late Animation<double> _bgParticleFade;

  @override
  void initState() {
    super.initState();

    _master = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800));

    _bgParticleFade = _curved(_master, 0.00, 0.30, Curves.easeOut);
    _iconFade = _curved(_master, 0.00, 0.35, Curves.easeOut);
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(
        parent: _master,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack)));
    _ringFade = _curved(_master, 0.15, 0.50, Curves.easeOut);
    _titleFade = _curved(_master, 0.30, 0.60, Curves.easeOut);
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _master,
            curve: const Interval(0.28, 0.60, curve: Curves.easeOut)));
    _taglineFade = _curved(_master, 0.45, 0.72, Curves.easeOut);
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _master,
            curve: const Interval(0.44, 0.72, curve: Curves.easeOut)));
    _statFade = _curved(_master, 0.60, 0.85, Curves.easeOut);
    _dividerScale = _curved(_master, 0.55, 0.80, Curves.easeOut);

    _master.forward();

    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);

    _particles =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..repeat();

    _ticker = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    Future.delayed(const Duration(milliseconds: 2400), _cycleStat);

    Future.delayed(const Duration(milliseconds: 4200), () async {
      if (!mounted) return;
      final loggedIn = await LocalStorageService.isLoggedIn();
      if (mounted) {
        context.go(loggedIn ? AppRoutes.dashboard : AppRoutes.login);
      }
    });
  }

  Animation<double> _curved(
      AnimationController c, double t0, double t1, Curve curve) {
    return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: c, curve: Interval(t0, t1, curve: curve)));
  }

  Future<void> _cycleStat() async {
    if (!mounted) return;
    setState(() => _statVisible = false);
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() {
      _statIndex = (_statIndex + 1) % _stats.length;
      _statVisible = true;
    });
    await Future.delayed(const Duration(milliseconds: 1600));
    _cycleStat();
  }

  @override
  void dispose() {
    _master.dispose();
    _pulse.dispose();
    _particles.dispose();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_master, _pulse, _particles]),
        builder: (context, _) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF050D1F),
                  Color(0xFF0A2463),
                  Color(0xFF0057FF)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Opacity(
                  opacity: _bgParticleFade.value * 0.18,
                  child: CustomPaint(
                    size: size,
                    painter: _GridPainter(),
                  ),
                ),
                Opacity(
                  opacity: _bgParticleFade.value,
                  child: CustomPaint(
                    size: size,
                    painter: _ParticlePainter(_particleList, _particles.value),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.12),
                  child: Opacity(
                    opacity: _ringFade.value * 0.45,
                    child: Container(
                      width: 260.r,
                      height: 260.r,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0x880057FF), Colors.transparent],
                          stops: [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      _buildLogo(),
                      SizedBox(height: 36.h),
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: _buildTitle(),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      SlideTransition(
                        position: _taglineSlide,
                        child: FadeTransition(
                          opacity: _taglineFade,
                          child: Text(
                            'Drive Smart. Stay Safe.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 48.h),
                      FadeTransition(
                        opacity: _dividerScale,
                        child: _buildDivider(),
                      ),
                      SizedBox(height: 32.h),
                      FadeTransition(
                        opacity: _statFade,
                        child: _buildStatTicker(),
                      ),
                      const Spacer(flex: 3),
                      FadeTransition(
                        opacity: _statFade,
                        child: _buildLoadingBar(size.width),
                      ),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Logo with pulsing ring ───────────────────────────────────────────────

  Widget _buildLogo() {
    final pulseValue = _pulse.value;

    return FadeTransition(
      opacity: _iconFade,
      child: ScaleTransition(
        scale: _iconScale,
        child: SizedBox(
          width: 140.r,
          height: 140.r,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (true)
                Opacity(
                  opacity: _ringFade.value * (0.25 + pulseValue * 0.25),
                  child: Container(
                    width: 138.r + pulseValue * 14.r,
                    height: 138.r + pulseValue * 14.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: _ringFade.value * (0.4 + pulseValue * 0.2),
                child: Container(
                  width: 118.r,
                  height: 118.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Container(
                width: 96.r,
                height: 96.r,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.r),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E6FFF), Color(0xFF0040CC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0057FF)
                          .withValues(alpha: 0.55 + pulseValue * 0.2),
                      blurRadius: 28 + pulseValue * 12,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 6,
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 28.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.r),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Icon(Icons.directions_car_rounded,
                        color: Colors.white, size: 46.r),
                  ],
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Opacity(
                  opacity: _ringFade.value,
                  child: Container(
                    width: 12.r,
                    height: 12.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.7),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Title ────────────────────────────────────────────────────────────────

  Widget _buildTitle() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Drive',
            style: AppTextStyles.h1.copyWith(
              color: Colors.white,
              fontSize: 38.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: ' Metrics ',
            style: AppTextStyles.h1.copyWith(
              color: Colors.white,
              fontSize: 38.sp,
              fontWeight: FontWeight.w300,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: 'AI',
            style: AppTextStyles.h1.copyWith(
              color: AppColors.accent,
              fontSize: 38.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ── Divider ──────────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48.w,
          height: 1.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.white.withValues(alpha: 0.3)],
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 10.w),
          width: 5.r,
          height: 5.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        Container(
          width: 48.w,
          height: 1.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withValues(alpha: 0.3), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  // ── Stat ticker ──────────────────────────────────────────────────────────

  Widget _buildStatTicker() {
    final stat = _stats[_statIndex];
    return AnimatedOpacity(
      opacity: _statVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 260),
      child: AnimatedSlide(
        offset: _statVisible ? Offset.zero : const Offset(0, 0.3),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36.r,
                height: 36.r,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(stat.icon, color: AppColors.accent, size: 18.r),
              ),
              SizedBox(width: 14.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stat.value,
                    style: AppTextStyles.h2.copyWith(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    stat.label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loading bar ──────────────────────────────────────────────────────────

  Widget _buildLoadingBar(double screenWidth) {
    return Column(
      children: [
        Text(
          'Initializing...',
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white.withValues(alpha: 0.35),
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          width: screenWidth * 0.45,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 3,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dy = (p.y - t * p.speed) % 1.0;
      final dx = p.x + math.sin(t * math.pi * 2 + p.y * 6) * 0.02;
      final cx = dx * size.width;
      final cy = dy * size.height;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(cx, cy), p.size * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
