import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// Resolves a server-relative media path (for example `/media/doctors/d01.jpg`) to a full URL.
String? mediaUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return '${AppConfig.apiBaseUrl}$path';
}

/// First letter(s) of a name, safe for Khmer text (no case folding).
String initialsOf(String name) {
  final cleaned = name.replaceAll(RegExp(r'^(វេជ្ជ\.|Dr\.?)\s*'), '').trim();
  if (cleaned.isEmpty) return '?';
  final parts = cleaned.split(RegExp(r'\s+'));
  final first = String.fromCharCodes([parts.first.runes.first]);
  if (parts.length == 1) return first;
  final second = String.fromCharCodes([parts.last.runes.first]);
  return '$first$second';
}

/// Round portrait with a graceful fallback to initials while loading or when the image is missing.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 56,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl(photoUrl);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDCEFEF),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: AppColors.teal,
        ),
      ),
    );
    if (url == null) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }
}

/// Wide image for hospitals with an icon fallback.
class BannerImage extends StatelessWidget {
  const BannerImage({
    super.key,
    this.photoUrl,
    this.height = 120,
    this.radius = 16,
  });

  final String? photoUrl;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl(photoUrl);
    final placeholder = Container(
      height: height,
      alignment: Alignment.center,
      color: const Color(0xFFE3F1F1),
      child: const Icon(
        Icons.local_hospital_outlined,
        size: 40,
        color: AppColors.teal,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}

/// Small rounded label used for specialties, status and "sample" markers.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
