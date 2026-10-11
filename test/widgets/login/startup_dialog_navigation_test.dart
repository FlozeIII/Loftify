import 'dart:io';

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:loftify/main.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  setUpAll(() async {
    final directory = Directory(
      '${Directory.current.path}/build/test_hive/startup_dialog_navigation',
    );
    await directory.create(recursive: true);
    Hive.init(directory.path);
    await Hive.openBox(ChewieHiveUtil.settingsBox);
  });

  tearDownAll(() async => Hive.close());

  testWidgets('fresh startup login dialog closes back to the guest screen',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp(home: _GuestScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Open login'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Login probe'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Login probe'), findsNothing);
    expect(find.text('Open login'), findsOneWidget);
  });
}

class _GuestScreen extends StatefulWidget {
  const _GuestScreen();

  @override
  State<_GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<_GuestScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => DialogBuilder.showPageDialog(
              context,
              child: const Center(child: Text('Login probe')),
            ),
            child: const Text('Open login'),
          ),
        ),
      );
}
