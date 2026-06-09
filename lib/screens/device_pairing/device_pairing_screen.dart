import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/storage/local_storage_service.dart';

// ─── The hardcoded device token must match what is flashed on the STM32. ───
// This is used as the Supabase filter for all trip queries.
// Change this to match your actual STM32 DEVICE_TOKEN #define.
const _kHardcodedDeviceToken = 'stm32-abc-123';

class DevicePairingScreen extends StatefulWidget {
  const DevicePairingScreen({super.key});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen>
    with SingleTickerProviderStateMixin {
  bool _scanning = false;
  bool _connected = false;
  String? _connectedDevice;
  String? _savedToken;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final List<_BLEDevice> _devices = [];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _loadSavedToken();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedToken() async {
    final token = await LocalStorageService.getDeviceToken();
    if (mounted) {
      setState(() {
        _savedToken = token;
        if (token != null) {
          _connected = true;
          _connectedDevice = token;
        }
      });
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _devices.clear();
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _devices.addAll([
          const _BLEDevice(
              name: 'DriveMetrics-A1B2', rssi: -62, id: _kHardcodedDeviceToken),
          const _BLEDevice(
              name: 'DriveMetrics-C3D4', rssi: -75, id: 'stm32-xyz-789'),
        ]);
      });
    }
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _scanning = false);
  }

  /// Connect to the device — saves its token to local storage so all
  /// Supabase queries in the app are automatically scoped to it.
  Future<void> _connect(_BLEDevice device) async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      await LocalStorageService.saveDeviceToken(device.id);

      if (!mounted) return;
      setState(() {
        _scanning = false;
        _connected = true;
        _connectedDevice = device.id;
        _savedToken = device.id;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.name}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r)),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await LocalStorageService.clearDeviceToken();
    setState(() {
      _connected = false;
      _connectedDevice = null;
      _savedToken = null;
      _devices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Device Pairing'),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BLEVisual(
              scanning: _scanning,
              connected: _connected,
              pulseAnim: _pulseAnim,
            ),
            SizedBox(height: 24.h),

            if (_connected)
              _ConnectedCard(
                deviceName: _connectedDevice ?? _savedToken ?? 'STM32 Device',
                onDisconnect: _disconnect,
              )
            else ...[
              ElevatedButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: _scanning
                    ? SizedBox(
                        width: 16.r,
                        height: 16.r,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.bluetooth_searching_rounded, size: 18.r),
                label: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
              ),
            ],

            if (_devices.isNotEmpty && !_connected) ...[
              SizedBox(height: 24.h),
              Text('Nearby Devices', style: AppTextStyles.h3),
              SizedBox(height: 12.h),
              ..._devices.map(
                (device) => Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: _DeviceTile(
                    device: device,
                    onConnect: () => _connect(device),
                  ),
                ),
              ),
            ],

            SizedBox(height: 24.h),

            // Token info (visible when connected for debugging)
            if (_savedToken != null)
              Container(
                padding: EdgeInsets.all(12.r),
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.vpn_key_outlined,
                        size: 14.r, color: AppColors.textSecondary),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Device token: $_savedToken',
                        style: AppTextStyles.monoSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // How-to guide
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bluetooth_rounded,
                          size: 16.r, color: AppColors.primary),
                      SizedBox(width: 8.w),
                      Text(
                        'How to pair',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  const _HelpStep(
                      number: '1',
                      text: 'Power on your Drive Metrics AI device (hold button for 3 seconds)'),
                  const _HelpStep(
                      number: '2',
                      text: 'Ensure Bluetooth is enabled on your phone'),
                  const _HelpStep(
                      number: '3',
                      text: 'Tap "Scan for Devices" and select your device from the list'),
                  const _HelpStep(
                      number: '4',
                      text: 'The LED on your device will turn solid blue when connected'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _BLEVisual extends StatelessWidget {
  final bool scanning;
  final bool connected;
  final Animation<double> pulseAnim;

  const _BLEVisual({
    required this.scanning,
    required this.connected,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (scanning || connected)
              Transform.scale(
                scale: scanning ? pulseAnim.value * 1.4 : 1.4,
                child: Container(
                  width: 120.r,
                  height: 120.r,
                  decoration: BoxDecoration(
                    color: (connected ? AppColors.accent : AppColors.primary)
                        .withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Container(
              width: 90.r,
              height: 90.r,
              decoration: BoxDecoration(
                gradient: connected ? AppColors.safeGradient : AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: connected
                    ? [BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )]
                    : AppColors.primaryShadow,
              ),
              child: Icon(
                connected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_rounded,
                color: Colors.white,
                size: 38.r,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  final String deviceName;
  final VoidCallback onDisconnect;

  const _ConnectedCard({required this.deviceName, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device Paired',
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.success)),
                Text(deviceName,
                    style: AppTextStyles.monoSmall,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton(
            onPressed: onDisconnect,
            child: Text('Unpair',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  final _BLEDevice device;
  final VoidCallback onConnect;

  const _DeviceTile({required this.device, required this.onConnect});

  int get _signalBars {
    if (device.rssi > -60) return 3;
    if (device.rssi > -75) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.memory_rounded, size: 20.r, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name, style: AppTextStyles.labelLarge),
                Text(device.id, style: AppTextStyles.monoSmall),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Container(
                    width: 4.w,
                    height: (8.0 + (i * 4)).h,
                    margin: EdgeInsets.only(left: 2.w),
                    decoration: BoxDecoration(
                      color: i < _signalBars ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              GestureDetector(
                onTap: onConnect,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: AppColors.primaryShadow,
                  ),
                  child: Text('Pair',
                      style: AppTextStyles.buttonMedium.copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final String number;
  final String text;
  const _HelpStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20.r,
            height: 20.r,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: AppTextStyles.overline.copyWith(color: Colors.white)),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall)),
        ],
      ),
    );
  }
}

class _BLEDevice {
  final String name;
  final int rssi;
  final String id;
  const _BLEDevice({required this.name, required this.rssi, required this.id});
}
