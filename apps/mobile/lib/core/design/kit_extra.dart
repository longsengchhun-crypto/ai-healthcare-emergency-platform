import 'package:flutter/material.dart';

import '../widgets/media.dart';
import 'kit.dart';
import 'palette.dart';

/// Two-to-four way segmented switch with a sliding thumb (replaces default TabBar for in-page toggles).
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.sand,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: index * w,
                width: w,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(Radii.sm + 2),
                    border: Border.all(color: p.line),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Tap(
                        onTap: () => onChanged(i),
                        child: Center(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: i == index
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: i == index ? p.ink : p.muted,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rectangular portrait (taller than wide) used for doctors in lists and carousels.
class Portrait extends StatelessWidget {
  const Portrait({
    super.key,
    required this.name,
    this.photoUrl,
    this.width = 76,
    this.height = 92,
    this.radius = 18,
  });
  final String name;
  final String? photoUrl;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final url = mediaUrl(photoUrl);
    final fallback = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      color: p.tealSoft,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: width * .3,
          fontWeight: FontWeight.w800,
          color: p.tealDeep,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (c, child, prog) =>
                    prog == null ? child : fallback,
              ),
      ),
    );
  }
}

/// Calendar-leaf style date block: day number over month abbreviation.
class DateBlock extends StatelessWidget {
  const DateBlock({
    super.key,
    required this.day,
    required this.month,
    this.highlight = false,
  });
  final String day;
  final String month;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? p.ink : p.sand,
        borderRadius: BorderRadius.circular(Radii.md - 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: highlight ? p.paper : p.ink,
            ),
          ),
          Text(
            month,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.3,
              color: highlight ? p.paper.withValues(alpha: 0.75) : p.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable time tile for the booking grid.
class TimeTile extends StatelessWidget {
  const TimeTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 82,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? p.ink : p.surface,
          borderRadius: BorderRadius.circular(Radii.md - 2),
          border: Border.all(color: selected ? p.ink : p.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? p.paper : p.ink,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

/// Small stat with a value and a caption, separated by hairlines in a row.
class Stat extends StatelessWidget {
  const Stat({super.key, required this.value, required this.caption});
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: p.ink,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: p.muted, height: 1.4),
        ),
      ],
    );
  }
}

/// Language switch used in headers: two quiet letters, no icon.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.isKhmer,
    required this.onChanged,
  });
  final bool isKhmer;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget opt(String code, String label, bool on) => Tap(
      onTap: () => onChanged(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? p.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            height: 1.3,
            color: on ? p.paper : p.muted,
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [opt('km', 'ខ្មែរ', isKhmer), opt('en', 'EN', !isKhmer)],
      ),
    );
  }
}

/// Title + subtitle + switch row that is safe inside a decorated [Surface] (unlike SwitchListTile).
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                  child: title,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: p.muted,
                        fontSize: 13,
                        height: 1.45,
                      ),
                      child: subtitle!,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
