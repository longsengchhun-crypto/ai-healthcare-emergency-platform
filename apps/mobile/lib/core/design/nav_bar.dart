import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/language.dart';
import 'kit.dart';
import 'palette.dart';

class NavItem {
  const NavItem(this.icon, this.activeIcon, this.km, this.en);
  final IconData icon;
  final IconData activeIcon;
  final String km;
  final String en;
}

/// Bottom bar with a raised centre action for Emergency. The emergency item is the only red element in the bar,
/// reachable with the thumb at any time (brief: prominent, but activation itself still needs a deliberate hold).
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onSelect,
    required this.emergencyIndex,
  });
  final List<NavItem> items;
  final int index;
  final int emergencyIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        height: 70,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(Radii.lg + 4),
          border: dark ? Border.all(color: p.line) : null,
          boxShadow: softShadow(context, strength: 1.6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.lg + 4),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: i == emergencyIndex
                      ? _EmergencyItem(
                          item: items[i],
                          selected: i == index,
                          onTap: () => onSelect(i),
                        )
                      : _Item(
                          item: items[i],
                          selected: i == index,
                          onTap: () => onSelect(i),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final color = selected ? p.brand : p.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: context.t(item.km, item.en),
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 52 : 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? p.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                size: 21,
                color: selected ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              context.t(item.km, item.en),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyItem extends StatelessWidget {
  const _EmergencyItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: context.t(item.km, item.en),
      child: InkResponse(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? p.red : p.redSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.emergency_rounded,
                size: 21,
                color: selected ? Colors.white : p.red,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              context.t(item.km, item.en),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w800,
                color: p.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
