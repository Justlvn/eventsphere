import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

/// Barre de navigation flottante : verre dépoli, ombre douce, pill animée par onglet.
class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  static const _items = <_NavSpec>[
    _NavSpec(
      label: 'Accueil',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavSpec(
      label: 'Planning',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
    ),
    _NavSpec(
      label: 'Assos',
      icon: Icons.apartment_outlined,
      selectedIcon: Icons.apartment_rounded,
    ),
    _NavSpec(
      label: 'Profil',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final accent = isDark ? cs.primary : AppColors.primary;

    final fill = Color.lerp(
      cs.surface,
      isDark ? const Color(0xFF1A2235) : const Color(0xFFFAFAFC),
      isDark ? 0.35 : 0.25,
    )!;

    final tintOpacity = isDark ? 0.88 : 0.86;
    final borderColor =
        Color.lerp(cs.outlineVariant, accent, isDark ? 0.12 : 0.08)!
            .withValues(alpha: isDark ? 0.55 : 0.7);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset > 0 ? 10 : 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor, width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    fill.withValues(alpha: tintOpacity + 0.04),
                    fill.withValues(alpha: tintOpacity),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.10),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                    spreadRadius: -8,
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.14 : 0.07),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Row(
                    children: List.generate(_items.length, (i) {
                      return Expanded(
                        child: _NavItem(
                          spec: _items[i],
                          selected: i == currentIndex,
                          accent: accent,
                          muted: cs.onSurfaceVariant,
                          onTap: () {
                            if (i == currentIndex) return;
                            HapticFeedback.lightImpact();
                            onDestinationSelected(i);
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _NavItem extends StatelessWidget {
  final _NavSpec spec;
  final bool selected;
  final Color accent;
  final Color muted;
  final VoidCallback onTap;

  const _NavItem({
    required this.spec,
    required this.selected,
    required this.accent,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: selected ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    selected ? spec.selectedIcon : spec.icon,
                    size: 24,
                    color: selected ? accent : muted,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: selected ? 0.15 : 0.05,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? accent : muted,
                    height: 1.1,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      spec.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
