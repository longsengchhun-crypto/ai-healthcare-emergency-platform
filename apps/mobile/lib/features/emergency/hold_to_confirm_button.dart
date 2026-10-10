import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/palette.dart';
import '../../core/i18n/language.dart';

/// Emergency activation control. Accidental taps are prevented by requiring a sustained press.
/// Assistive technologies get an equivalent single-activation path that opens an explicit confirmation dialog,
/// because a timed press-and-hold is not operable for every user.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1800),
    this.enabled = true,
    this.label,
  });

  final VoidCallback onConfirmed;
  final Duration holdDuration;
  final bool enabled;
  final String? label;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: widget.holdDuration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            HapticFeedback.heavyImpact();
            widget.onConfirmed();
            _progress.reset();
          }
        });

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    HapticFeedback.selectionClick();
    _progress.forward();
  }

  void _cancel() {
    if (_progress.status != AnimationStatus.completed) _progress.reverse();
  }

  Future<void> _confirmViaDialog() async {
    if (!widget.enabled) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('ស្នើសុំជំនួយបន្ទាន់?', 'Request emergency help?')),
        content: Text(
          ctx.t(
            'សំណើនេះនឹងផ្ញើទីតាំងរបស់អ្នកទៅបញ្ជីរង់ចាំរបស់មន្ទីរពេទ្យ។',
            'This sends your location to the hospital response queue.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('បោះបង់', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ctx.t('ផ្ញើសំណើ', 'Send request'),
              style: TextStyle(
                color: Palette.of(ctx).red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = widget.enabled ? p.red : p.muted;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: context.t(
        'ស្នើសុំជំនួយបន្ទាន់។ ចុចពីរដងដើម្បីបើកការបញ្ជាក់។',
        'Request emergency help. Double tap to open confirmation.',
      ),
      onTap: _confirmViaDialog,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            return SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.10),
                    ),
                  ),
                  SizedBox(
                    width: 204,
                    height: 204,
                    child: CircularProgressIndicator(
                      value: _progress.value,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.16),
                    ),
                  ),
                  AnimatedScale(
                    scale: 1 - 0.05 * _progress.value,
                    duration: const Duration(milliseconds: 60),
                    child: Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color,
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emergency_rounded,
                            color: Colors.white,
                            size: 46,
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Text(
                              widget.label ??
                                  context.t(
                                    'សង្កត់ដើម្បីស្នើសុំជំនួយ',
                                    'Hold to ask for help',
                                  ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
