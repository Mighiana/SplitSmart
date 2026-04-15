import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../utils/app_utils.dart';


// ─── Pill Badge ──────────────────────────────────────────────────────────────
class PillBadge extends StatelessWidget {
  final String text;
  final Color color;
  const PillBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Avatar Circle ────────────────────────────────────────────────────────────
class AvatarCircle extends StatelessWidget {
  final String label;
  final double size;
  final Color? bg;
  final Color? fg;
  const AvatarCircle({
    super.key, required this.label, this.size = 40, this.bg, this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final initials = label.trim().split(RegExp(r'\s+')).take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: bg ?? AppColors.greenDim,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
            color: fg ?? AppColors.green,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.32,
          )),
    );
  }
}

// ─── Emoji Box ────────────────────────────────────────────────────────────────
class EmojiBox extends StatelessWidget {
  final String emoji;
  final double size;
  final double borderRadius;
  const EmojiBox({
    super.key, required this.emoji, this.size = 48, this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: TC.card2(context),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: size * 0.45)),
    );
  }
}

// ─── SS Card ─────────────────────────────────────────────────────────────────
class SSCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final VoidCallback? onTap;
  const SSCard({super.key, required this.child, this.padding, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: color ?? TC.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TC.border(context)),
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperCase(),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: TC.text3(context), letterSpacing: 2,
            )),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green,
                )),
          ),
      ],
    );
  }
}

// ─── Chip Selector ────────────────────────────────────────────────────────────
class SSChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const SSChip({super.key, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.greenDim : TC.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.green : TC.border(context),
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.green : TC.text2(context),
            )),
      ),
    );
  }
}

// ─── Numpad ───────────────────────────────────────────────────────────────────
class SSNumpad extends StatelessWidget {
  final void Function(String) onKey;
  const SSNumpad({super.key, required this.onKey});

  @override
  Widget build(BuildContext context) {
    final keys = ['1','2','3','4','5','6','7','8','9','.','0','⌫'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.9,
      ),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final k = keys[i];
        final isDel = k == '⌫';
        return GestureDetector(
          onTap: () => onKey(isDel ? 'del' : k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TC.border(context)),
            ),
            alignment: Alignment.center,
            child: Text(k,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDel ? AppColors.red : TC.text(context),
                )),
          ),
        );
      },
    );
  }
}

// ─── Amount Display (with shake animation) ──────────────────────────────────────
class AmountDisplay extends StatefulWidget {
  final String amount;
  final String symbol;
  final Color color;
  final String label;
  const AmountDisplay({
    super.key,
    required this.amount,
    required this.symbol,
    this.color = AppColors.green,
    this.label = 'Total Amount',
  });

  /// Call this on the GlobalKey<AmountDisplayState> to trigger a shake.
  static void shake(GlobalKey<AmountDisplayState> key) =>
      key.currentState?.shake();

  @override
  State<AmountDisplay> createState() => AmountDisplayState();
}

class AmountDisplayState extends State<AmountDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;
  bool _redBorder = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  void shake() {
    HapticFeedback.mediumImpact();
    setState(() => _redBorder = true);
    _shakeCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _redBorder = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _redBorder
        ? AppColors.red
        : widget.color.withValues(alpha: 0.12);
    final bgColor = _redBorder
        ? AppColors.red.withValues(alpha: 0.06)
        : widget.color.withValues(alpha: 0.05);

    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0),
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(widget.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: TC.text3(context), letterSpacing: 2,
                )),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: widget.symbol,
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800,
                      color: widget.color.withValues(alpha: 0.6),
                    ),
                  ),
                  TextSpan(
                    text: widget.amount,
                    style: TextStyle(
                        fontSize: 44, fontWeight: FontWeight.w800,
                        color: widget.color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Empty State ──────────────────────────────────────────────────────────────
class EmptyState extends StatefulWidget {
  final String icon, title, subtitle;
  const EmptyState({
    super.key, required this.icon, required this.title, required this.subtitle,
  });
  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _float;
  late Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _pulse = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Column(
          children: [
            Transform.translate(
              offset: Offset(0, _float.value),
              child: Transform.scale(
                scale: _pulse.value,
                child: Text(widget.icon, style: const TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16,
                  color: TC.text(context),
                )),
            const SizedBox(height: 6),
            Text(widget.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: TC.text2(context))),
          ],
        ),
      ),
    );
  }
}

// ─── Progress Bar ─────────────────────────────────────────────────────────────
class ProgressBar extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final Color color;
  const ProgressBar({super.key, required this.value, this.color = AppColors.blue});

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _initialized = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = constraints.maxWidth * widget.value.clamp(0.0, 1.0);
        return Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: TC.border(context),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(seconds: 1),
            curve: Curves.easeOutCubic,
            height: 6,
            width: _initialized ? targetWidth : 0,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      },
    );
  }
}

// ─── Receipt Viewer ───────────────────────────────────────────────────────────
/// Full-screen image viewer for receipts.
class ReceiptViewer extends StatelessWidget {
  final String imagePath;
  final String title;
  const ReceiptViewer({super.key, required this.imagePath, this.title = 'Receipt'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, color: Colors.white54, size: 60),
                SizedBox(height: 12),
                Text('Image not available',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
