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
    final height = 76 + 28 * scale;
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
                                  margin: EdgeInsets.only(
                                      top: i == selectedIndex ? 2 : 16),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
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
    final x = center.clamp(32.0, size.width - 32);
    final path = Path()
      ..moveTo(24, 18)
      ..lineTo(x - 32, 18)
      ..cubicTo(x - 23, 18, x - 28, 57, x, 57)
      ..cubicTo(x + 28, 57, x + 23, 18, x + 32, 18)
      ..lineTo(size.width - 24, 18)
      ..quadraticBezierTo(size.width, 18, size.width, 42)
      ..lineTo(size.width, size.height - 24)
      ..quadraticBezierTo(size.width, size.height, size.width - 24, size.height)
      ..lineTo(24, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 24)
      ..lineTo(0, 42)
      ..quadraticBezierTo(0, 18, 24, 18)
      ..close();
    canvas.drawShadow(path, AppColors.primary.withValues(alpha: .15), 5, true);
    canvas.drawPath(path, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) => oldDelegate.center != center;
}
