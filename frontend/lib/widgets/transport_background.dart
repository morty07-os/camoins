import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

/// Abstract illustration only; no position, map or tracking data is used.
class TransportBackground extends StatefulWidget {
  const TransportBackground(
      {super.key, required this.child, required this.route});
  final Widget child;
  final String route;

  @override
  State<TransportBackground> createState() => _TransportBackgroundState();
}

class _TransportBackgroundState extends State<TransportBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _travel =
      AnimationController(vsync: this, duration: const Duration(seconds: 42));
  late final AnimationController _ripple = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  final ValueNotifier<double> _scroll = ValueNotifier(0);
  GoRouter? _router;
  Offset? _tap;
  bool _reduced = false;
  bool _visible = true;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _visible = TickerMode.valuesOf(context).enabled;
    final router = GoRouter.maybeOf(context);
    if (router != _router) {
      _router?.routerDelegate.removeListener(_syncMotion);
      _router = router;
      _router?.routerDelegate.addListener(_syncMotion);
    }
    _syncMotion();
  }

  void _syncMotion() {
    final onDashboard = _router == null ||
        _router!.routerDelegate.currentConfiguration.uri.path == widget.route;
    if (!_reduced && _visible && _resumed && onDashboard) {
      if (!_travel.isAnimating) _travel.repeat();
    } else {
      _travel.stop();
      _ripple.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_syncMotion);
    _travel.dispose();
    _ripple.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (!_reduced && notification.depth == 0) {
              _scroll.value = notification.metrics.pixels.clamp(0, 1000) * .035;
            }
            return false;
          },
          // Only a tap recognizer: child controls and scroll gestures win normally.
          child: GestureDetector(
            excludeFromSemantics: true,
            onTapUp: _reduced
                ? null
                : (details) {
                    _tap = details.localPosition;
                    _ripple.forward(from: 0);
                  },
            child: Stack(fit: StackFit.expand, children: [
              Positioned.fill(
                  child: ExcludeSemantics(
                      child: IgnorePointer(
                child: RepaintBoundary(
                    child: CustomPaint(
                  painter: _TransportPainter(
                      _travel, _ripple, _scroll, () => _tap, _reduced),
                )),
              ))),
              RepaintBoundary(child: widget.child),
            ]),
          ),
        ),
      );
}

class _TransportPainter extends CustomPainter {
  _TransportPainter(
      this.travel, this.ripple, this.scroll, this.tap, this.reduced)
      : super(repaint: Listenable.merge([travel, ripple, scroll]));
  final Animation<double> travel;
  final Animation<double> ripple;
  final ValueNotifier<double> scroll;
  final Offset? Function() tap;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(AppColors.background, BlendMode.src);
    canvas.save();
    canvas.translate(0, reduced ? 0 : -scroll.value);
    final route = Path()
      ..moveTo(-20, 32)
      ..cubicTo(
          size.width * .8, -16, size.width * .1, 100, size.width + 30, 38);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.primary.withValues(alpha: .09);
    canvas.drawPath(route, paint);
    canvas.drawPath(
        Path()
          ..moveTo(size.width * .8, -30)
          ..cubicTo(-100, size.height * .45, size.width * 1.4,
              size.height * .65, size.width * .15, size.height + 80),
        paint..color = AppColors.accent.withValues(alpha: .12));
    final metric = route.computeMetrics().first;
    for (final t in [.19, .73]) {
      final point = metric.getTangentForOffset(metric.length * t)!.position;
      canvas.save();
      canvas.translate(point.dx, point.dy);
      final pin = Path()
        ..moveTo(0, 8)
        ..cubicTo(-15, -5, -5, -16, 0, -12)
        ..cubicTo(5, -16, 15, -5, 0, 8)
        ..close();
      canvas.drawPath(
          pin, Paint()..color = AppColors.accent.withValues(alpha: .18));
      canvas.drawCircle(
          const Offset(0, -5), 2.5, Paint()..color = AppColors.background);
      canvas.restore();
    }
    final truck = metric
        .getTangentForOffset(metric.length * (reduced ? .45 : travel.value))!;
    canvas.save();
    canvas.translate(truck.position.dx, truck.position.dy);
    canvas.rotate(math.atan2(truck.vector.dy, truck.vector.dx));
    final ink = Paint()..color = AppColors.primary.withValues(alpha: .22);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-12, -8, 16, 12), const Radius.circular(2)),
        ink);
    canvas.drawPath(
        Path()
          ..moveTo(5, -5)
          ..lineTo(10, -5)
          ..lineTo(14, 0)
          ..lineTo(14, 4)
          ..lineTo(5, 4)
          ..close(),
        ink);
    canvas.drawCircle(const Offset(-7, 5), 3, ink);
    canvas.drawCircle(const Offset(9, 5), 3, ink);
    canvas.restore();
    canvas.restore();
    if (!reduced && tap() != null && ripple.value > 0 && ripple.value < 1) {
      canvas.drawCircle(
          tap()!,
          8 + 26 * ripple.value,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color =
                AppColors.accent.withValues(alpha: .22 * (1 - ripple.value)));
    }
  }

  @override
  bool shouldRepaint(_TransportPainter oldDelegate) =>
      oldDelegate.reduced != reduced;
}
