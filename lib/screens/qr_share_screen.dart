import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../services/analytics_service.dart';

class QRShareScreen extends StatefulWidget {
  final GroupData group;
  const QRShareScreen({super.key, required this.group});

  @override
  State<QRShareScreen> createState() => _QRShareScreenState();
}

class _QRShareScreenState extends State<QRShareScreen> {
  final GlobalKey _qrKey = GlobalKey();

  /// Payload encoded into the QR
  String get _payload {
    final data = {
      'v': 1,
      'name': widget.group.name,
      'emoji': widget.group.emoji,
      'currency': widget.group.currency,
      'sym': widget.group.sym,
      'members': widget.group.members,
    };
    return jsonEncode(data);
  }

  Future<void> _shareQRImage() async {
    try {
      HapticFeedback.mediumImpact();
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/splitsmart_qr_${widget.group.name.replaceAll(' ', '_')}.png',
      );
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: 'Join ${widget.group.name} on SplitSmart',
          text:
              'Scan this QR code to join the "${widget.group.name}" group on SplitSmart!',
        ),
      );
      AnalyticsService.logGroupQRShared();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share QR: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TC.card(context),
              shape: BoxShape.circle,
              border: Border.all(color: TC.border(context)),
            ),
            alignment: Alignment.center,
            child: Text(
              '←',
              style: TextStyle(fontSize: 16, color: TC.text(context)),
            ),
          ),
        ),
        title: Text(
          'Share via QR',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: TC.text(context),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _shareQRImage,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.greenDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📤', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 4),
                  Text(
                    'Share QR',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // ── Instruction banner ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.greenDim,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('📲', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Show this QR code to a friend. They open SplitSmart, tap Scan QR, and the group imports instantly.',
                      style: TextStyle(
                        fontSize: 12,
                        color: TC.text(context),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── QR card ────────────────────────────────────────────────────
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TC.card(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: TC.border(context), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Group emoji + name
                    Text(widget.group.emoji, style: const TextStyle(fontSize: 48)),
                    const SizedBox(height: 8),
                    Text(
                      widget.group.name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: TC.text(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.group.currency} · ${widget.group.members.length} members',
                      style: TextStyle(fontSize: 13, color: TC.text2(context)),
                    ),

                    // Members row
                    if (widget.group.members.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: widget.group.members
                            .map(
                              (m) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  m,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: TC.text2(context),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // QR code
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: QrImageView(
                        data: _payload,
                        version: QrVersions.auto,
                        size: 220,
                        gapless: false,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0A0A0A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0A0A0A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Scan label
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.greenDim,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '✓ SplitSmart QR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Share QR image button ──────────────────────────────────────
            GestureDetector(
              onTap: _shareQRImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('📤', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text(
                      'Share QR Image',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Copy payload button ────────────────────────────────────────
            _CopyButton(payload: _payload),
            const SizedBox(height: 12),

            // ── Members list ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TC.border(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHAT\'S INCLUDED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TC.text3(context),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Group name', value: widget.group.name),
                  _InfoRow(label: 'Emoji', value: widget.group.emoji),
                  _InfoRow(
                    label: 'Currency',
                    value: '${widget.group.currency} (${widget.group.sym})',
                  ),
                  _InfoRow(
                    label: 'Members',
                    value: widget.group.members.join(', '),
                  ),
                  _InfoRow(label: 'Expenses', value: 'Not included (fresh start)'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: TC.text2(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: TC.text(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String payload;
  const _CopyButton({required this.payload});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        await Clipboard.setData(ClipboardData(text: widget.payload));
        setState(() => _copied = true);
        // SEC-9: Auto-clear clipboard after 30 seconds to prevent leaks
        Future.delayed(const Duration(seconds: 30), () {
          Clipboard.setData(const ClipboardData(text: ''));
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _copied ? AppColors.greenDim : TC.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _copied ? AppColors.green : TC.border(context),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _copied ? '✓ Copied to clipboard!' : '📋 Copy QR data',
          style: TextStyle(
            color: _copied ? AppColors.green : TC.text(context),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
