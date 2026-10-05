import 'package:backhaul_frontend/widgets/curved_transport_bar.dart';
import 'package:backhaul_frontend/widgets/transport_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const destinations = [
    NavigationDestination(icon: Icon(Icons.home), label: 'Accueil'),
    NavigationDestination(icon: Icon(Icons.local_shipping), label: 'Camions'),
    NavigationDestination(icon: Icon(Icons.route), label: 'Retours'),
    NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
    NavigationDestination(icon: Icon(Icons.message), label: 'Messages'),
    NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
  ];

  testWidgets(
      'bar fits a small screen, exposes selection and hides for keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 0;
    Future<void> pump({double scale = 1, double keyboard = 0}) async {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard)),
        child: Scaffold(
            bottomNavigationBar: CurvedTransportBar(
          selectedIndex: selected,
          onDestinationSelected: (value) => selected = value,
          destinations: destinations,
        )),
      )));
      await tester.pumpAndSettle();
    }

    await pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Profil'));
    expect(selected, 5);
    await pump(scale: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Profil').hitTestable(), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(
        tester.getSemantics(find.byType(InkWell).last).getSemanticsData().label,
        contains('Profil'));
    semantics.dispose();
    await pump(keyboard: 280);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets(
      'background pauses for reduced motion, inactive tabs and app lifecycle',
      (tester) async {
    Future<void> pump({bool reduced = false, bool active = true}) async {
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(
            enabled: active,
            child: const TransportBackground(
              route: '/customer-home',
              child: SizedBox.expand(),
            )),
      )));
      await tester.pump(const Duration(milliseconds: 100));
    }

    await pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await pump(active: false);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await pump(reduced: true);
    await tester.tapAt(const Offset(100, 100));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('decoration does not consume buttons or scrolling',
      (tester) async {
    var taps = 0;
    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: TransportBackground(
      route: '/customer-home',
      child: SingleChildScrollView(
          controller: scroll,
          child: Column(children: [
            ElevatedButton(
                onPressed: () => taps++, child: const Text('Action')),
            const SizedBox(height: 2000),
          ])),
    )));
    await tester.tap(find.text('Action'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(scroll.offset, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
    expect(tester.takeException(), isNull);
  });
}
