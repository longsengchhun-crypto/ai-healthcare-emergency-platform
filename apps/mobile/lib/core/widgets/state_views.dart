import 'package:flutter/material.dart';

import '../errors/app_exception.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        if (label != null) ...[const SizedBox(height: 12), Text(label!)],
      ],
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline =
        error is AppException &&
        (error as AppException).kind == ErrorKind.offline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              describeError(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });
  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center),
          ],
        ],
      ),
    ),
  );
}

/// Banner used wherever AI or demonstration data is shown, so it is never mistaken for clinical truth.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? const Color(0xFFB54708)
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
        ],
      ),
    );
  }
}
