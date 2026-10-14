import 'dart:io';

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:loftify/Screens/Setting/about_setting_screen.dart';
import 'package:loftify/Utils/app_provider.dart';
import 'package:loftify/main.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final launched = <String>[];

  setUpAll(() async {
    final directory = Directory(
      '${Directory.current.path}/build/test_hive/community_configuration',
    );
    await directory.create(recursive: true);
    Hive.init(directory.path);
    await Hive.openBox(ChewieHiveUtil.settingsBox);
    await ChewieHiveUtil.put(ChewieHiveUtil.inappWebviewKey, false);
    PackageInfo.setMockInitialValues(
      appName: 'Loftify Community',
      packageName: 'io.github.flozeiii.loftify.community',
      version: '2.5.3',
      buildNumber: '2503',
      buildSignature: '',
    );
  });

  setUp(() {
    launched.clear();
    for (final name in [
      'plugins.flutter.io/url_launcher',
      'plugins.flutter.io/url_launcher_windows',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (call.method == 'launch' || call.method == 'launchUrl') {
          launched.add((call.arguments as Map)['url'] as String);
        }
        return true;
      });
    }
  });

  testWidgets('about feedback opens the Community issue tracker',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appProvider.locale = const Locale('en');

    await tester.pumpWidget(
      const MyApp(home: AboutSettingScreen(showTitleBar: false)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('Report a Bug'));
    await tester.tap(find.text('Report a Bug'));
    await tester.pump();

    expect(launched, ['https://github.com/FlozeIII/Loftify/issues']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
