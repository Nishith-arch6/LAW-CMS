import 'package:flutter/material.dart';

enum ScreenType { mobile, tablet, desktop }

ScreenType getScreenType(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w < 600) return ScreenType.mobile;
  if (w < 1024) return ScreenType.tablet;
  return ScreenType.desktop;
}

bool isMobile(BuildContext context) => getScreenType(context) == ScreenType.mobile;
bool isTablet(BuildContext context) => getScreenType(context) == ScreenType.tablet;
bool isDesktop(BuildContext context) => getScreenType(context) == ScreenType.desktop;

class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final type = getScreenType(context);
    if (type == ScreenType.desktop && desktop != null) return desktop!;
    if (type == ScreenType.tablet && tablet != null) return tablet!;
    return mobile;
  }
}

class AdaptiveGridView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(T, int) itemBuilder;
  final int Function(double)? crossAxisCount;

  const AdaptiveGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = crossAxisCount != null ? crossAxisCount!(w) : (w < 600 ? 1 : w < 1024 ? 2 : 3);

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: cols > 1 ? 1.4 : 3.2,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => itemBuilder(items[i], i),
    );
  }
}
