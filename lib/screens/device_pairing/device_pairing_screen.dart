import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

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
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _devices.clear();
    });

    // Simulate BLE scan with mock devices
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _devices.addAll([
          const _BLEDevice(
              name: 'DriveMetrics-A1B2', rssi: -62, id: '00:1A:7D:DA:71:13'),
          const _BLEDevice(
              name: 'DriveMetrics-C3D4', rssi: -75, id: '00:1A:7D:DA:71:14'),
        ]);
      });
    }
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connect(_BLEDevice device) async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() {
        _scanning = false;
        _connected = true;
        _connectedDevice = device.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${device.name}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _disconnect() {
    setState(() {
      _connected = false;
      _connectedDevice = null;
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BLE visual
            _BLEVisual(
              scanning: _scanning,
              connected: _connected,
              pulseAnim: _pulseAnim,
            ),
            const SizedBox(height: 24),

            // Status card
            if (_connected)
              _ConnectedCard(
                deviceName: _connectedDevice!,
                onDisconnect: _disconnect,
              )
            else ...[
              // Scan button
              ElevatedButton.icon(
                onPressed: _scanning ? null : _startScan,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bluetooth_searching_rounded, size: 18),
                label: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
              ),
            ],

            // Device list
            if (_devices.isNotEmpty && !_connected) ...[
              const SizedBox(height: 24),
              const Text('Nearby Devices', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              ..._devices.map(
                (device) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DeviceTile(
                    device: device,
                    onConnect: () => _connect(device),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bluetooth_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'How to pair',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _HelpStep(
                      number: '1',
                      text:
                          'Power on your Drive Metrics AI device (hold button for 3 seconds)'),
                  const _HelpStep(
                      number: '2',
                      text: 'Ensure Bluetooth is enabled on your phone'),
                  const _HelpStep(
                      number: '3',
                      text:
                          'Tap "Scan for Devices" and select your device from the list'),
                  const _HelpStep(
                      number: '4',
                      text:
                          'The LED on your device will turn solid blue when connected'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: (connected ? AppColors.accent : AppColors.primary)
                        .withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: connected
                    ? AppColors.safeGradient
                    : AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: connected
                    ? [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : AppColors.primaryShadow,
              ),
              child: Icon(
                connected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_rounded,
                color: Colors.white,
                size: 38,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connected',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.success)),
                Text(deviceName, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: onDisconnect,
            child: Text('Disconnect',
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.danger)),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.memory_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
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
                    width: 4,
                    height: 8.0 + (i * 4),
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(
                      color: i < _signalBars
                          ? AppColors.primary
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onConnect,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: AppColors.primaryShadow,
                  ),
                  child: Text('Pair',
                      style: AppTextStyles.buttonMedium
                          .copyWith(color: Colors.white)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: AppTextStyles.overline.copyWith(color: Colors.white)),
            ),
          ),
          const SizedBox(width: 10),
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
