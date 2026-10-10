import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Emergency activation control. Accidental taps are prevented by requiring a sustained press.
/// Assistive technologies get an equivalent single-activation path that opens an explicit confirmation dialog,
/// because a timed press-and-hold is not operable for every user.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.onConfirmed,
    this.holdDuration = const Duration(milliseconds: 1800),
    this.enabled = true,
    this.label = 'Hold to request emergency help',
  });

  final VoidCallback onConfirmed;
  final Duration holdDuration;
  final bool enabled;
  final String label;

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
        title: const Text('Request emergency help?'),
        content: const Text(
          'This sends an emergency request with your location to the response queue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergency,
              minimumSize: const Size(120, 48),
            ),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (ok == true) widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Request emergency help. Double tap to open confirmation.',
      onTap: _confirmViaDialog,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _cancel(),
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final color = widget.enabled ? AppColors.emergency : Colors.grey;
            return SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: _progress.value,
                      strokeWidth: 10,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                  ),
                  Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 24,
                          spreadRadius: 2 + 6 * _progress.value,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emergency_share_rounded,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Text(
                            widget.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
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
