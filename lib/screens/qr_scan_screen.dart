import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';
import 'group_detail_screen.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _processing = false;
  bool _torchOn = false;
  Map<String, dynamic>? _lastJson;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() => _processing = true);
    _ctrl.stop();

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['v'] != 1 || json['name'] == null) {
        _showError('Not a valid SplitSmart QR code.');
        return;
      }
      _showImportSheet(json);
    } catch (_) {
      _showError('Could not read QR code. Please try again.');
    }
  }

  void _showError(String msg) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _processing = false);
        _ctrl.start();
      }
    });
  }

  Future<void> _doImport(AppState state) async {
    final json = _lastJson;
    if (json == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import failed. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    final group = await state.importGroupFromQR(json);
    if (!mounted) return;

    if (group == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import failed. Please try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    } else {
      state.currentGroup = group;
      AnalyticsService.logGroupQRScanned();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GroupDetailScreen()),
      );
    }
  }

  void _showImportSheet(Map<String, dynamic> json) {
    _lastJson = json;

    HapticFeedback.mediumImpact();
    final name = (json['name'] as String?) ?? 'Imported Group';
    final emoji = (json['emoji'] as String?) ?? '🌍';
    final currency = (json['currency'] as String?) ?? 'USD';
    final sym = (json['sym'] as String?) ?? '\$';
    final members = ((json['members'] as List<dynamic>?) ?? [])
        .map((e) => e.toString())
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ImportPreviewSheet(
        name: name,
        emoji: emoji,
        currency: currency,
        sym: sym,
        members: members,
        json: json,
        onImport: () async {
          Navigator.pop(context);
          final state = context.read<AppState>();

          final alreadyExists = state.groups.any(
            (g) => g.name == name && g.currency == currency,
          );

          if (alreadyExists && mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: TC.card(context),
                title: Text(
                  'Group already exists',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: TC.text(context),
                  ),
                ),
                content: Text(
                  '"$name" ($currency) already exists in your groups.',
                  style: TextStyle(color: TC.text2(context)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.text2),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _doImport(state);
                    },
                    child: const Text(
                      'Import Anyway',
                      style: TextStyle(color: AppColors.green),
                    ),
                  ),
                ],
              ),
            );
            return;
          }

          await _doImport(state);
        },
        onRetry: () {
          Navigator.pop(context);
          if (mounted) {
            setState(() => _processing = false);
            _ctrl.start();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ScanOverlayPainter(),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30),
                          ),
                          child: const Text(
                            '←',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Scan Group QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _ctrl.toggleTorch();
                          setState(() => _torchOn = !_torchOn);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _torchOn
                                ? AppColors.green.withValues(alpha: 0.3)
                                : Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _torchOn
                                  ? AppColors.green
                                  : Colors.white30,
                            ),
                          ),
                          child: Icon(
                            _torchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: _torchOn
                                ? AppColors.green
                                : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  margin: const EdgeInsets.only(bottom: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _processing
                        ? '⏳ Processing...'
                        : '📷 Point at a SplitSmart QR code',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double boxSize = 240;
    final cx = size.width / 2;
    final cy = size.height / 2 - 40;

    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: boxSize,
      height: boxSize,
    );

    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, rect.top), paint);
    canvas.drawRect(Rect.fromLTWH(0, rect.top, rect.left, rect.height), paint);
    canvas.drawRect(
      Rect.fromLTWH(rect.right, rect.top, size.width - rect.right, rect.height),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, rect.bottom, size.width, size.height - rect.bottom),
      paint,
    );

    final bracketPaint = Paint()
      ..color = AppColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const r = 16.0;
    const len = 28.0;

    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      final dx = corner == rect.topLeft || corner == rect.bottomLeft ? 1 : -1;
      final dy = corner == rect.topLeft || corner == rect.topRight ? 1 : -1;
      canvas.drawLine(
        corner + Offset(dx * r, 0),
        corner + Offset(dx * len, 0),
        bracketPaint,
      );
      canvas.drawLine(
        corner + Offset(0, dy * r),
        corner + Offset(0, dy * len),
        bracketPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ImportPreviewSheet extends StatelessWidget {
  final String name, emoji, currency, sym;
  final List<String> members;
  final Map<String, dynamic> json;
  final VoidCallback onImport;
  final VoidCallback onRetry;

  const _ImportPreviewSheet({
    required this.name,
    required this.emoji,
    required this.currency,
    required this.sym,
    required this.members,
    required this.json,
    required this.onImport,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: TC.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: TC.text(context),
                      ),
                    ),
                    Text(
                      '$currency ($sym) · ${members.length} members',
                      style: TextStyle(fontSize: 13, color: TC.text2(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (members.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MEMBERS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TC.text3(context),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: members
                    .map(
                      (m) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: m == 'You'
                              ? AppColors.greenDim
                              : TC.card(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: m == 'You'
                                ? AppColors.green
                                : TC.border(context),
                          ),
                        ),
                        child: Text(
                          m,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: m == 'You'
                                ? AppColors.green
                                : TC.text(context),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blueDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('ℹ️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This will create a new group with these members. No expenses from the sender are imported.',
                    style: TextStyle(
                      fontSize: 12,
                      color: TC.text(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onImport,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text(
                '✓ Import Group',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text(
                'Scan a different code',
                style: TextStyle(
                  fontSize: 14,
                  color: TC.text2(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
