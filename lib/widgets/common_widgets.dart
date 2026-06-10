import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../providers/app_state.dart';
import '../utils/app_utils.dart';
import '../utils/theme_utils.dart';
import '../utils/icon_map.dart';

// ─── Subcategory dropdown ────────────────────────────────────────────────────
/// Dropdown-style picker for an optional sub-category of [parentCat].
/// Renders nothing when the category has no sub-categories. Shared by the
/// personal Add Transaction and group Add Expense forms.
class SubcategoryDropdown extends StatelessWidget {
  final String parentCat;     // parent category emoji key
  final String? value;        // selected `sub:...` key (null = none)
  final ValueChanged<String?> onChanged;
  const SubcategoryDropdown({
    super.key,
    required this.parentCat,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final subs = AppState.subsFor(parentCat);
    if (subs.isEmpty) return const SizedBox.shrink();
    final sel = value == null ? null : AppState.subByKey(value!);
    final accent = colorForEmoji(parentCat, fallback: TC.primary(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('SUBCATEGORY · OPTIONAL',
              style: TC.geist(context,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: TC.text3(context),
                  letterSpacing: 1.5)),
        ),
        GestureDetector(
          onTap: () => _pick(context, subs, accent),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: TC.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: sel != null ? accent : TC.border(context),
                  width: sel != null ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Icon(sel?.materialIcon ?? Icons.segment_rounded,
                    size: 18,
                    color: sel != null ? accent : TC.text3(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(sel?.label ?? 'None',
                      style: TC.geist(context,
                          fontSize: 14,
                          fontWeight:
                              sel != null ? FontWeight.w600 : FontWeight.w500,
                          color: sel != null
                              ? TC.text(context)
                              : TC.text3(context))),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: TC.text3(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _pick(BuildContext context, List<CategoryItem> subs, Color accent) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: TC.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: TC.border(context),
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Subcategory',
                      style: TC.gloock(context,
                          fontSize: 18, color: TC.text(context))),
                ),
              ),
              ListTile(
                leading: Icon(Icons.not_interested_rounded,
                    size: 20, color: TC.text3(context)),
                title: Text('None',
                    style: TC.geist(context,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: TC.text(context))),
                trailing: value == null
                    ? Icon(Icons.check_circle_rounded,
                        size: 20, color: accent)
                    : null,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(null);
                  Navigator.pop(sheetCtx);
                },
              ),
              ...subs.map((s) => ListTile(
                    leading: Icon(s.materialIcon ?? Icons.category_rounded,
                        size: 20, color: accent),
                    title: Text(s.label,
                        style: TC.geist(context,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: TC.text(context))),
                    trailing: value == s.icon
                        ? Icon(Icons.check_circle_rounded,
                            size: 20, color: accent)
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(s.icon);
                      Navigator.pop(sheetCtx);
                    },
                  )),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

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
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
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
    super.key,
    required this.label,
    this.size = 40,
    this.bg,
    this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final initials = label
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join();
    return Container(
      width: size,
      height: size,
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
    super.key,
    required this.emoji,
    this.size = 48,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: TC.card2(context),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Icon(
        iconForEmoji(emoji),
        size: size * 0.5,
        color: AppColors.green,
      ),
    );
  }
}

// ─── SS Card ─────────────────────────────────────────────────────────────────
class SSCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final VoidCallback? onTap;
  const SSCard(
      {super.key, required this.child, this.padding, this.color, this.onTap});

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
  const SectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: TC.text3(context),
              letterSpacing: 2,
            )),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
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
  const SSChip(
      {super.key,
      required this.label,
      required this.active,
      required this.onTap});

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
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
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
                style: TC.geist(context,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDel ? TC.er(context) : TC.text(context),
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
  final Color? color;
  final String label;
  const AmountDisplay({
    super.key,
    required this.amount,
    required this.symbol,
    this.color,
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
  late Animation<double> _shakeAnim;
  bool _redBorder = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
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
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void shake() {
    HapticFeedback.mediumImpact();
    setState(() => _redBorder = true);
    _shakeCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _redBorder = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? TC.primary(context);
    final borderColor =
        _redBorder ? TC.er(context) : activeColor.withValues(alpha: 0.12);
    final bgColor = _redBorder
        ? TC.er(context).withValues(alpha: 0.06)
        : activeColor.withValues(alpha: 0.05);

    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0),
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(widget.label.toUpperCase(),
                style: TC.geist(context,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: TC.text3(context),
                  letterSpacing: 2,
                )),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: widget.symbol,
                    style: TC.gloock(context,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: activeColor.withValues(alpha: 0.6),
                    ),
                  ),
                  TextSpan(
                    text: widget.amount,
                    style: TC.gloock(context,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: activeColor),
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
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _float;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                child: Icon(iconForEmoji(widget.icon), size: 50, color: TC.primary(context)),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
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

// ─── Rich Empty State (art + pills + CTA + ghost) ──────────────────────────────
class EmptyPill {
  final String emoji;
  final String label;
  final VoidCallback? onTap;
  const EmptyPill(this.emoji, this.label, {this.onTap});
}

class RichEmptyState extends StatelessWidget {
  final String art;
  final String title;
  final String desc;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final String? ghostLabel;
  final VoidCallback? onGhost;
  final List<EmptyPill>? pills;

  const RichEmptyState({
    super.key,
    required this.art,
    required this.title,
    required this.desc,
    this.ctaLabel,
    this.onCta,
    this.ghostLabel,
    this.onGhost,
    this.pills,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 40),
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 112, height: 112,
              decoration: BoxDecoration(
                color: TC.primaryPale(context),
                borderRadius: BorderRadius.circular(32),
              ),
              alignment: Alignment.center,
              child: Icon(iconForEmoji(art), size: 52, color: TC.primary(context)),
            ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(title,
                textAlign: TextAlign.center,
                style: TC.gloock(context, fontSize: 22, color: TC.text(context), letterSpacing: -0.2))
                .animate().fadeIn(delay: 80.ms, duration: 320.ms),
            const SizedBox(height: 10),
            Text(desc,
                textAlign: TextAlign.center,
                style: TC.geist(context, fontSize: 14, color: TC.text2(context), height: 1.6))
                .animate().fadeIn(delay: 120.ms, duration: 320.ms),
            if (pills != null && pills!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                children: pills!.map((p) => GestureDetector(
                  onTap: p.onTap == null ? null : () { HapticFeedback.selectionClick(); p.onTap!(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: TC.card(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: TC.border(context)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(iconForEmoji(p.emoji), size: 15, color: TC.primaryMd(context)),
                        const SizedBox(width: 6),
                        Text(p.label,
                            style: TC.geist(context, fontSize: 13, fontWeight: FontWeight.w500, color: TC.text(context))),
                      ],
                    ),
                  ),
                )).toList(),
              ).animate().fadeIn(delay: 160.ms, duration: 340.ms),
            ],
            if (ctaLabel != null) ...[
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () { HapticFeedback.mediumImpact(); onCta?.call(); },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: TC.primary(context),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: TC.primaryGlow(context), blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  alignment: Alignment.center,
                  child: Text('+  $ctaLabel',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 340.ms),
            ],
            if (ghostLabel != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); onGhost?.call(); },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: TC.border(context), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(ghostLabel!,
                      style: TC.geist(context, fontSize: 14, fontWeight: FontWeight.w600, color: TC.text2(context))),
                ),
              ).animate().fadeIn(delay: 240.ms, duration: 340.ms),
            ],
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
  const ProgressBar(
      {super.key, required this.value, this.color = AppColors.blue});

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
  const ReceiptViewer(
      {super.key, required this.imagePath, this.title = 'Receipt'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: imagePath.startsWith('http')
              ? Image.network(
                  imagePath,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white54, strokeWidth: 2)),
                  errorBuilder: (_, __, ___) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white54, size: 60),
                      SizedBox(height: 12),
                      Text('Image not available',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                )
              : Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: Colors.white54, size: 60),
                      SizedBox(height: 12),
                      Text('Image not available',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Count-Up Number ──────────────────────────────────────────────────────────
/// Animates a numeric value, smoothly tweening from the previously shown value
/// to [value] whenever it changes. [builder] receives the interpolated value so
/// the caller controls formatting (currency symbol, decimals) and text style.
class CountUpText extends StatelessWidget {
  final double value;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext context, double value) builder;

  const CountUpText({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: duration,
      curve: curve,
      builder: (ctx, v, _) => builder(ctx, v),
    );
  }
}

// ─── Shimmer Skeletons ────────────────────────────────────────────────────────
/// A single shimmering placeholder block used while data loads.
class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TC.border(context).withValues(alpha: 0.35);
    final hi = TC.border(context).withValues(alpha: 0.12);
    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, _) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 - 2 * (1 - t) + 2, 0),
              colors: [base, hi, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// A card-shaped skeleton placeholder matching the app's card style.
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TC.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TC.border(context)),
      ),
      child: const Row(
        children: [
          ShimmerBox(width: 44, height: 44, radius: 12),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 140, height: 13),
                SizedBox(height: 8),
                ShimmerBox(width: 90, height: 11),
              ],
            ),
          ),
          SizedBox(width: 14),
          ShimmerBox(width: 56, height: 16),
        ],
      ),
    );
  }
}

/// A vertical stack of [count] skeleton cards for list placeholders.
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  final EdgeInsetsGeometry padding;
  const SkeletonList({
    super.key,
    this.count = 5,
    this.itemHeight = 80,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (int i = 0; i < count; i++) ...[
            SkeletonCard(height: itemHeight),
            if (i < count - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
