import 'dart:ui';

import 'package:flutter/material.dart';

import 'explore_screen.dart';
import '../theme/gundua_theme.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Floating, glass-like navigation inspired by iOS 26.
/// Flutter approximation; not Apple's native UIKit Liquid Glass material.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  int _homeRefreshToken = 0;
  int _favoritesRefreshToken = 0;
  int _exploreRefreshToken = 0;
  String? _homeSearchQuery;
  int _searchRequestToken = 0;

  void _select(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      if (index == 0) _homeRefreshToken++;
      if (index == 2) _favoritesRefreshToken++;
      if (index == 1) _exploreRefreshToken++;
    });
  }

  void _search(String query) {
    setState(() {
      _homeSearchQuery = query;
      _searchRequestToken++;
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        refreshToken: _homeRefreshToken,
        onGoExplore: () => _select(1),
        onSearch: _search,
      ),
      ExploreScreen(
        initialQuery: _homeSearchQuery,
        initialQueryToken: _searchRequestToken,
        refreshToken: _exploreRefreshToken,
      ),
      FavoritesScreen(refreshToken: _favoritesRefreshToken),
      const ProfileScreen(),
    ];
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      backgroundColor: GunduaTheme.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _selectedIndex, children: pages),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: bottom + 12,
            child: _GlassNavigationBar(
              currentIndex: _selectedIndex,
              onSelected: _select,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassNavigationBar extends StatelessWidget {
  const _GlassNavigationBar({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const _icons = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.favorite_border,
    Icons.person_outline_rounded,
  ];
  static const _activeIcons = [
    Icons.home_rounded,
    Icons.explore_rounded,
    Icons.favorite_rounded,
    Icons.person_rounded,
  ];
  static const _labels = ['Início', 'Explorar', 'Favoritos', 'Perfil'];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : GunduaTheme.ink;
    final surface = dark ? Colors.black : Colors.white;
    final reduceTransparency = MediaQuery.disableAnimationsOf(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: reduceTransparency ? 0 : 23,
          sigmaY: reduceTransparency ? 0 : 23,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            color: surface.withValues(alpha: dark ? .82 : .88),
            border: Border.all(color: Colors.white.withValues(alpha: dark ? .27 : .78)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Row(
              children: List.generate(_labels.length, (index) {
                final selected = index == currentIndex;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: _labels[index],
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelected(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        height: 57,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          color: selected
                              ? foreground.withValues(alpha: dark ? .27 : .10)
                              : Colors.transparent,
                          border: selected
                              ? Border.all(color: Colors.white.withValues(alpha: .42))
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(selected ? _activeIcons[index] : _icons[index],
                                color: foreground.withValues(alpha: selected ? 1 : .60), size: 23),
                            const SizedBox(height: 3),
                            Text(
                              _labels[index],
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: foreground.withValues(alpha: selected ? 1 : .60),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
