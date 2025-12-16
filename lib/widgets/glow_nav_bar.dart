import 'package:flutter/material.dart';

class GlowNavItem {
  final IconData icon;
  final String label;
  const GlowNavItem({required this.icon, required this.label});
}

class GlowNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final List<GlowNavItem> items;
  const GlowNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: items
          .map((i) =>
              BottomNavigationBarItem(icon: Icon(i.icon), label: i.label))
          .toList(),
    );
  }
}
