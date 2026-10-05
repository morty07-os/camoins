import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Use the fonts shipped with the running Flutter SDK for readable snapshots.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final fonts = Directory('${artifacts.path}/material_fonts');
  for (final family in ['Roboto']) {
    final loader = FontLoader(family);
    for (final weight in ['regular', 'medium', 'bold', 'black']) {
      loader.addFont(Future.value(ByteData.sublistView(
          File('${fonts.path}/roboto-$weight.ttf').readAsBytesSync())));
    }
    await loader.load();
  }
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
  await testMain();
}
