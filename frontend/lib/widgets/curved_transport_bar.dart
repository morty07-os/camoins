import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Router-owned selection: this widget never keeps a second tab index.
class CurvedTransportBar extends StatefulWidget {
  const CurvedTransportBar(
      {super.key,
      required this.selectedIndex,
      required this.onDestinationSelected,
      required this.destinations});

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  State<CurvedTransportBar> createState() => _CurvedTransportBarState();
}

class _CurvedTransportBarState extends State<CurvedTransportBar> {
  final _scroll = ScrollController();
  int get selectedIndex => widget.selectedIndex;
  List<NavigationDestination> get destinations => widget.destinations;
  ValueChanged<int> get onDestinationSelected => widget.onDestinationSelected;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    // A scrollable rail at large text sizes keeps every label and 48px target.
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final height = 64 + 28 * scale;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = math.max(constraints.maxWidth,
              destinations.length * math.max(48.0, 48 * scale));
          final itemWidth = width / destinations.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scroll.hasClients) return;
            final offset =
                ((selectedIndex + .5) * itemWidth - constraints.maxWidth / 2)
                    .clamp(0.0, _scroll.position.maxScrollExtent);
            if ((_scroll.offset - offset).abs() > 1) {
              _scroll.jumpTo(offset);
            }
          });
          return SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width.toDouble(),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: selectedIndex.toDouble()),
                duration: duration,
                curve: Curves.easeInOutCubic,
                builder: (context, position, child) => CustomPaint(
                  painter: _BarPainter((position + .5) * itemWidth),
                  child: child,
                ),
                child: Row(children: [
                  for (var i = 0; i < destinations.length; i++)
                    SizedBox(
                      width: itemWidth,
                      child: Semantics(
                        selected: i == selectedIndex,
                        button: true,
                        label: destinations[i].label,
                        child: Tooltip(
                          message: destinations[i].label,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => onDestinationSelected(i),
                            child: ExcludeSemantics(
                              child: Column(children: [
                                AnimatedContainer(
                                  duration: duration,
                                  curve: Curves.easeInOutCubic,
                                  margin: EdgeInsets.only(top: 8),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    color: i == selectedIndex
                                        ? AppColors.accent
                                        : Colors.transparent,
                                  ),
                                  child: IconTheme(
                                    data: IconThemeData(
                                        color: i == selectedIndex
                                            ? AppColors.primaryDark
                                            : AppColors.textSecondary),
                                    child: i == selectedIndex
                                        ? destinations[i].selectedIcon ??
                                            destinations[i].icon
                                        : destinations[i].icon,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(destinations[i].label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        height: 1.15,
                                        fontWeight: i == selectedIndex
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: AppColors.primary)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.center);
  final double center;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(20)));
    canvas.drawPath(path, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) => oldDelegate.center != center;
}
