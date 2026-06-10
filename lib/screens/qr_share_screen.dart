import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../utils/theme_utils.dart';
import '../utils/icon_map.dart';
import '../services/analytics_service.dart';
import '../services/firestore_service.dart';
import 'paywall_screen.dart';

class QRShareScreen extends StatefulWidget {
  final GroupData group;
  const QRShareScreen({super.key, required this.group});

  @override
  State<QRShareScreen> createState() => _QRShareScreenState();
}

class _QRShareScreenState extends State<QRShareScreen>
    with TickerProviderStateMixin {
  final GlobalKey _qrKey = GlobalKey();
  String? _inviteCode;
  bool _isLoadingCode = true;
  bool _sharing = false;
  bool _copied = false;
  bool _guestBusy = false;

  late AnimationController _glowCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _glowAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _glowAnim = Tween(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _fetchInviteCode();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInviteCode() async {
    _inviteCode = widget.group.inviteCode;
    if (_inviteCode == null || _inviteCode!.isEmpty) {
      final fetched =
          await FirestoreService.instance.getGroupInviteCode(widget.group.id);
      if (fetched != null) {
        _inviteCode = fetched;
        widget.group.inviteCode = fetched;
      }
    }
    if (_inviteCode != null && _inviteCode!.isNotEmpty) {
      await FirestoreService.instance
          .ensureInviteCodeMapping(widget.group.id, _inviteCode!);
    }
    if (mounted) {
      setState(() => _isLoadingCode = false);
      _entryCtrl.forward();
    }
  }

  String get _payload {
    final data = {
      'v': 1,
      'name': widget.group.name,
      'emoji': widget.group.emoji,
      'currency': widget.group.currency,
      'sym': widget.group.sym,
      if (_inviteCode != null && _inviteCode!.isNotEmpty)
        'inviteCode': _inviteCode,
      'members': widget.group.members,
    };
    return jsonEncode(data);
  }

  Future<void> _shareQRImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
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
          '${dir.path}/splitsmart_qr_${widget.group.name.replaceAll(' ', '_')}.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: 'Join ${widget.group.name} on SplitSmart',
        text: 'Scan this QR code to join "${widget.group.name}" on SplitSmart!',
      ));
      AnalyticsService.logGroupQRShared();
      try { await file.delete(); } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copyCode() async {
    if (_copied) return;
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: _inviteCode ?? _payload));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TC.bg(context),
      body: _isLoadingCode
          ? _buildLoader()
          : Stack(
              children: [
                // ── Ambient glow background ─────────────────────────────
                Positioned(
                  top: -80,
                  left: size.width * 0.1,
                  child: AnimatedBuilder(
                    animation: _glowAnim,
                    builder: (_, __) => Opacity(
                      opacity: _glowAnim.value * 0.18,
                      child: Container(
                        width: size.width * 0.8,
                        height: size.width * 0.8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            Color(0xFF14A085),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Main content ────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SafeArea(
                      child: Column(
                        children: [
                          _buildHeader(context),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              child: Column(
                                children: [
                                  const SizedBox(height: 16),
                                  RepaintBoundary(
                                    key: _qrKey,
                                    child: _buildQRPanel(context, isDark),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildActionButtons(context),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Loading state ───────────────────────────────────────────────────────────
  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.green, strokeWidth: 2.5),
          SizedBox(height: 16),
          Text('Generating invite code…',
              style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: TC.card(context),
                shape: BoxShape.circle,
                border: Border.all(color: TC.border(context)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: TC.text(context)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('INVITE',
                    style: TC.geist(
                      context,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TC.primaryMd(context),
                      letterSpacing: 1.5,
                    )),
                const SizedBox(height: 1),
                Text('Invite via QR',
                    style: TC.gloock(
                      context,
                      fontSize: 22,
                      letterSpacing: -0.5,
                      color: TC.text(context),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── QR Panel ────────────────────────────────────────────────────────────────
  Widget _buildQRPanel(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: TC.primary(context).withValues(alpha: 0.10),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Group identity — so the shared QR image says what it's for.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: TC.primaryPale(context),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(iconForEmoji(widget.group.emoji),
                      size: 20, color: TC.primary(context)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TC.gloock(context,
                              fontSize: 18, color: TC.text(context))),
                      Text(
                          '${widget.group.members.length} ${widget.group.members.length == 1 ? 'member' : 'members'} · ${widget.group.currency}',
                          style: TC.geist(context,
                              fontSize: 11, color: TC.text3(context))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // QR code with animated glow ring
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, child) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: _glowAnim.value * 0.22),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: QrImageView(
                  data: _payload,
                  version: QrVersions.auto,
                  size: 190,
                  gapless: true,
                  // Higher correction (Q = 25%) keeps the styled/rounded code
                  // reliably scannable.
                  errorCorrectionLevel: QrErrorCorrectLevel.Q,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle,
                    color: Color(0xFF0D7377), // brand teal eyes
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: Color(0xFF0A1A1C), // near-black for contrast
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Divider
            Container(height: 1, color: TC.border(context)),
            const SizedBox(height: 16),

            // Invite code — tap to copy
            Text(
              'INVITE CODE',
              style: TC.geist(
                context,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: TC.text3(context),
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _copyCode,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _inviteCode != null && _inviteCode!.isNotEmpty
                        ? _inviteCode!
                        : 'No code',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: TC.text(context),
                      letterSpacing: 4,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                      key: ValueKey(_copied),
                      size: 18,
                      color: _copied ? TC.primary(context) : TC.text3(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _copied ? 'Copied to clipboard' : 'Tap the code to copy',
              style: TC.geist(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _copied ? TC.primary(context) : TC.text3(context),
              ),
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: TC.border(context)),
            const SizedBox(height: 12),
            // How-to-join hint.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner_rounded,
                    size: 14, color: TC.text3(context)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Scan in SplitSmart, or enter the code to join',
                    textAlign: TextAlign.center,
                    style: TC.geist(context,
                        fontSize: 11, color: TC.text3(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Guest access (premium, owner-controlled) ────────────────────────────────
  Future<void> _toggleGuestAccess(bool enable) async {
    final state = context.read<AppState>();

    // Enabling requires Premium → send non-subscribers to the paywall.
    if (enable && !state.hasPremium) {
      final purchased = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      if (purchased != true || !mounted) return;
    }

    setState(() => _guestBusy = true);
    final ok = await state.setGroupGuestAccess(widget.group, enable);
    if (!mounted) return;
    setState(() {
      _guestBusy = false;
      if (ok) widget.group.isPremiumGroup = enable;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update guest access. Try again.'),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  Widget _buildGuestAccessCard(BuildContext context) {
    final enabled = widget.group.isPremiumGroup;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? AppColors.green : TC.border(context),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.link_rounded, size: 22, color: Color(0xFF0D7377)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Allow guests to join',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: TC.text(context))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.greenDim,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('PREMIUM',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.green)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('People can join without an account.',
                    style:
                        TextStyle(fontSize: 12, color: TC.text2(context))),
              ],
            ),
          ),
          _guestBusy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Switch.adaptive(
                  value: enabled,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => _toggleGuestAccess(v),
                ),
        ],
      ),
    );
  }

  // ── Action buttons ──────────────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context) {
    // Premium "guest join" isn't being sold yet — only the owner sees this
    // control; regular users don't see any premium option.
    final isOwner = context.read<AppState>().isOwner;
    return Column(
      children: [
        if (isOwner) _buildGuestAccessCard(context),
        // Primary: Share QR
        GestureDetector(
          onTap: _sharing ? null : _shareQRImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: _sharing
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF14A085), Color(0xFF0D7377)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: _sharing ? TC.card(context) : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _sharing
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.green.withValues(alpha: 0.32),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
              border: _sharing
                  ? Border.all(color: TC.border(context))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_sharing)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.green),
                  )
                else
                  const Icon(Icons.ios_share_rounded,
                      size: 18, color: Colors.white),
                const SizedBox(width: 9),
                Text(
                  _sharing ? 'Preparing image…' : 'Share QR Image',
                  style: TextStyle(
                    color: _sharing ? TC.text2(context) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary: Copy invite code
        GestureDetector(
          onTap: _copyCode,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: _copied
                  ? AppColors.green.withValues(alpha: 0.08)
                  : TC.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _copied
                    ? AppColors.green.withValues(alpha: 0.5)
                    : TC.border(context),
                width: _copied ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    _copied
                        ? Icons.check_circle_rounded
                        : Icons.copy_rounded,
                    key: ValueKey(_copied),
                    size: 18,
                    color: _copied ? AppColors.green : TC.text2(context),
                  ),
                ),
                const SizedBox(width: 9),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _copied ? 'Code Copied!' : 'Copy Invite Code',
                    key: ValueKey(_copied),
                    style: TextStyle(
                      color: _copied ? AppColors.green : TC.text(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
