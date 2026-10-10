import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../errors/app_exception.dart';
import '../i18n/language.dart';
import 'palette.dart';

/// Pressable wrapper: subtle scale + haptic tick. Used instead of bare InkWell so every tap feels the same.
class Tap extends StatefulWidget {
  const Tap({
    super.key,
    required this.child,
    this.onTap,
    this.radius = Radii.md,
    this.haptic = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final bool haptic;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        if (widget.haptic) HapticFeedback.selectionClick();
        widget.onTap!();
      },
      child: AnimatedScale(
        scale: _down ? 0.975 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Flat surface with a hairline, the product's basic container (no shadows, no gradient fills).
class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = Radii.lg,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tap(
      onTap: onTap,
      radius: radius,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? p.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor ?? p.line),
        ),
        child: child,
      ),
    );
  }
}

/// Section label with an optional trailing action, left-aligned and quiet.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.count,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: p.ink,
              height: 1.4,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(color: p.muted, fontWeight: FontWeight.w600),
            ),
          ],
          const Spacer(),
          if (action != null)
            Tap(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  action!,
                  style: TextStyle(color: p.teal, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small label. `tone` picks a semantic colour pair.
enum Tone { neutral, teal, blue, green, amber, red }

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = Tone.neutral, this.icon});
  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (bg, fg) = switch (tone) {
      Tone.teal => (p.tealSoft, p.tealDeep),
      Tone.blue => (p.blue.withValues(alpha: 0.12), p.blue),
      Tone.green => (p.greenSoft, p.green),
      Tone.amber => (p.amberSoft, p.amber),
      Tone.red => (p.redSoft, p.red),
      Tone.neutral => (p.sand, p.inkSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.busy = false,
    this.danger = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final enabled = onPressed != null && !busy;
    return Tap(
      onTap: enabled ? onPressed : null,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? (danger ? p.red : p.ink) : p.line,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tap(
      onTap: onPressed,
      child: Container(
        height: compact ? 42 : 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: p.line, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: p.ink),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 14 : 15,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmering placeholder block for loading states (replaces centred spinners).
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 8});
  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + 3 * _c.value, 0),
            end: Alignment(-0.5 + 3 * _c.value, 0),
            colors: [p.sand, Color.lerp(p.sand, p.surface, 0.8)!, p.sand],
          ),
        ),
      ),
    );
  }
}

/// A list of card-shaped skeletons.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.itemHeight = 92});
  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(Gap.page),
    physics: const NeverScrollableScrollPhysics(),
    itemCount: count,
    separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
    itemBuilder: (_, _) => Skeleton(height: itemHeight, radius: Radii.lg),
  );
}

enum Art { calendar, folder, bell, search, pulse, pill, shield, cloud }

/// Hand-drawn line illustrations (no stock art) used by empty and error states.
class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind, this.ink, this.accent, this.soft);
  final Art kind;
  final Color ink;
  final Color accent;
  final Color soft;

  @override
  void paint(Canvas canvas, Size s) {
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = soft;
    final acc = Paint()..color = accent;
    final w = s.width, h = s.height;
    canvas.drawCircle(Offset(w / 2, h / 2), math.min(w, h) * 0.46, fill);
    switch (kind) {
      case Art.calendar:
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * .28, h * .30, w * .44, h * .42),
          const Radius.circular(10),
        );
        canvas.drawRRect(
          r,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawRRect(r, stroke);
        canvas.drawLine(
          Offset(w * .28, h * .43),
          Offset(w * .72, h * .43),
          stroke,
        );
        canvas.drawLine(
          Offset(w * .40, h * .24),
          Offset(w * .40, h * .34),
          stroke,
        );
        canvas.drawLine(
          Offset(w * .60, h * .24),
          Offset(w * .60, h * .34),
          stroke,
        );
        canvas.drawCircle(Offset(w * .50, h * .58), 7, acc);
      case Art.folder:
        final p = Path()
          ..moveTo(w * .26, h * .36)
          ..lineTo(w * .43, h * .36)
          ..lineTo(w * .48, h * .42)
          ..lineTo(w * .74, h * .42)
          ..lineTo(w * .74, h * .68)
          ..lineTo(w * .26, h * .68)
          ..close();
        canvas.drawPath(
          p,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawPath(p, stroke);
        canvas.drawCircle(Offset(w * .50, h * .55), 6, acc);
      case Art.bell:
        final p = Path()
          ..moveTo(w * .32, h * .62)
          ..quadraticBezierTo(w * .36, h * .56, w * .36, h * .45)
          ..quadraticBezierTo(w * .36, h * .30, w * .50, h * .30)
          ..quadraticBezierTo(w * .64, h * .30, w * .64, h * .45)
          ..quadraticBezierTo(w * .64, h * .56, w * .68, h * .62)
          ..close();
        canvas.drawPath(
          p,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawPath(p, stroke);
        canvas.drawCircle(Offset(w * .50, h * .70), 6, acc);
      case Art.search:
        canvas.drawCircle(
          Offset(w * .46, h * .46),
          w * .15,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawCircle(Offset(w * .46, h * .46), w * .15, stroke);
        canvas.drawLine(
          Offset(w * .57, h * .57),
          Offset(w * .70, h * .70),
          stroke..strokeWidth = 5,
        );
      case Art.pulse:
        final p = Path()
          ..moveTo(w * .22, h * .52)
          ..lineTo(w * .40, h * .52)
          ..lineTo(w * .46, h * .36)
          ..lineTo(w * .54, h * .68)
          ..lineTo(w * .60, h * .52)
          ..lineTo(w * .78, h * .52);
        canvas.drawPath(
          p,
          stroke
            ..color = accent
            ..strokeWidth = 4,
        );
      case Art.pill:
        canvas.save();
        canvas.translate(w / 2, h / 2);
        canvas.rotate(-0.6);
        final r = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: w * .40, height: h * .20),
          const Radius.circular(40),
        );
        canvas.drawRRect(
          r,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawRRect(r, stroke);
        canvas.drawLine(const Offset(0, -20), const Offset(0, 20), stroke);
        canvas.restore();
      case Art.shield:
        final p = Path()
          ..moveTo(w * .50, h * .28)
          ..lineTo(w * .70, h * .36)
          ..lineTo(w * .68, h * .58)
          ..quadraticBezierTo(w * .66, h * .70, w * .50, h * .76)
          ..quadraticBezierTo(w * .34, h * .70, w * .32, h * .58)
          ..lineTo(w * .30, h * .36)
          ..close();
        canvas.drawPath(
          p,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawPath(p, stroke);
        canvas.drawCircle(Offset(w * .50, h * .52), 6, acc);
      case Art.cloud:
        final p = Path()
          ..moveTo(w * .32, h * .62)
          ..quadraticBezierTo(w * .24, h * .62, w * .26, h * .52)
          ..quadraticBezierTo(w * .28, h * .44, w * .38, h * .46)
          ..quadraticBezierTo(w * .42, h * .34, w * .54, h * .36)
          ..quadraticBezierTo(w * .66, h * .38, w * .66, h * .50)
          ..quadraticBezierTo(w * .76, h * .52, w * .72, h * .62)
          ..close();
        canvas.drawPath(
          p,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
        canvas.drawPath(p, stroke);
        canvas.drawLine(
          Offset(w * .36, h * .74),
          Offset(w * .64, h * .52),
          stroke..color = accent,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) =>
      old.kind != kind || old.ink != ink || old.accent != accent;
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.art,
    required this.title,
    this.message,
    this.action,
    this.onAction,
  });
  final Art art;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: CustomPaint(
                painter: _ArtPainter(art, p.ink, p.teal, p.tealSoft),
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: p.ink,
                height: 1.4,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.muted, height: 1.5),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: Gap.lg),
              SizedBox(
                width: 220,
                child: PrimaryButton(label: action!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with retry; wording adapts to the failure kind.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline =
        error is AppException &&
        (error as AppException).kind == ErrorKind.offline;
    return EmptyState(
      art: offline ? Art.cloud : Art.pulse,
      title: offline
          ? context.t('មិនមានអ៊ីនធឺណិត', 'You seem to be offline')
          : context.t('មានបញ្ហាបន្តិច', 'Something went wrong'),
      message: error is AppException
          ? (error as AppException).message
          : context.t('សូមព្យាយាមម្តងទៀត។', 'Please try again.'),
      action: onRetry == null ? null : context.t('ព្យាយាមម្តងទៀត', 'Try again'),
      onAction: onRetry,
    );
  }
}

/// Inline notice. Used for AI disclaimers, sample-data notices and warnings.
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.tone = Tone.neutral, this.icon});
  final String text;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final (bg, fg, ic) = switch (tone) {
      Tone.red => (p.redSoft, p.red, Icons.error_outline_rounded),
      Tone.amber => (p.amberSoft, p.amber, Icons.info_outline_rounded),
      Tone.green => (p.greenSoft, p.green, Icons.check_circle_outline_rounded),
      Tone.teal => (p.tealSoft, p.tealDeep, Icons.info_outline_rounded),
      _ => (p.sand, p.inkSoft, Icons.info_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? ic, size: 19, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: fg, height: 1.5, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Key/value row used in detail screens.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: p.tealSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: p.tealDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: p.muted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      style: TextStyle(
                        color: p.ink,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      ),
    );
  }
}

/// Wraps content so it never stretches edge to edge on tablets and desktop browsers.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.max = 640});
  final Widget child;
  final double max;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: max),
      child: child,
    ),
  );
}

/// The line illustration on its own (onboarding and headers).
class ArtImage extends StatelessWidget {
  const ArtImage(this.art, {super.key, this.size = 140});
  final Art art;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ArtPainter(art, p.ink, p.teal, p.tealSoft)),
    );
  }
}
