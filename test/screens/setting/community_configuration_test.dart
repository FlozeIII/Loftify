import 'dart:io';

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loftify/Screens/Setting/about_setting_screen.dart';
import 'package:loftify/Screens/Setting/image_setting_screen.dart';
import 'package:loftify/Screens/main_screen.dart';
import 'package:loftify/Utils/app_provider.dart';
import 'package:loftify/Utils/cloud_control_provider.dart';
import 'package:loftify/Utils/hive_util.dart';
import 'package:loftify/Utils/enums.dart';
import 'package:loftify/Utils/utils.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:loftify/Widgets/loftify_icons.dart';
import 'package:loftify/l10n/l10n.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
}

class _OfflineClient implements HttpClient {
  _OfflineClient(this.requests);
  final List<Uri> requests;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests.add(url);
    throw const SocketException('Test-only offline configuration endpoint');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

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
    await initializeDateFormatting();
    await ChewieHiveUtil.put(ChewieHiveUtil.fontFamilyKey, '');
    PathProviderPlatform.instance = _TestPaths('${directory.path}/support');
    await ChewieHiveUtil.put(ChewieHiveUtil.inappWebviewKey, false);
    PackageInfo.setMockInitialValues(
      appName: 'Loftify Community',
      packageName: 'io.github.flozeiii.loftify.community',
      version: '2.5.3',
      buildNumber: '2503',
      buildSignature: '',
    );
  });

  test('startup makes no configuration request with historical overrides',
      () async {
    await ChewieHiveUtil.put(HiveUtil.autoCheckUpdateKey, false);
    await ChewieHiveUtil.put(HiveUtil.overrideCloudControlKey, true);
    await ChewieHiveUtil.put('cloudControl', {
      'enableApp': false,
      'features': {'showDress': false},
      'contacts': {'issueUrl': 'https://example.invalid/upstream'},
    });
    appProvider.token = '';
    final requests = <Uri>[];
    await HttpOverrides.runZoned(() async {
      MainScreenState().fetchBasicData();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }, createHttpClient: (_) => _OfflineClient(requests));

    expect(requests, isEmpty);
    expect(controlProvider.globalControl.enableAppNotNull, isTrue);
    expect(controlProvider.globalControl.showDress, isTrue);
    expect(controlProvider.globalControl.issueUrl,
        'https://github.com/FlozeIII/Loftify/issues');
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

  Future<void> mount(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    appProvider.locale = const Locale('en');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appProvider),
          ChangeNotifierProvider.value(value: controlProvider),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          navigatorKey: chewieProvider.globalNavigatorKey,
          theme: ChewieThemeColorData.defaultLightThemes.first.toThemeData(),
          localizationsDelegates: const [
            ChewieLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            chewieProvider.setRootContext(context);
            return screen;
          }),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final entry in [
    ('feedback', LoftifyIcons.bug, 'https://github.com/FlozeIII/Loftify/issues'),
    ('contact', LoftifyIcons.support, 'https://github.com/FlozeIII/Loftify/issues'),
    ('repository', LoftifyIcons.commit, 'https://github.com/FlozeIII/Loftify'),
    ('community page', LoftifyIcons.language, 'https://github.com/FlozeIII/Loftify'),
  ]) {
    testWidgets('about ${entry.$1} opens the Community destination', (tester) async {
      await mount(tester, const AboutSettingScreen(showTitleBar: false));
      final action = find.byWidgetPredicate(
        (widget) => widget is EntryItem && widget.leading == entry.$2,
      );
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();
      expect(launched, [entry.$3]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('about has no upstream group invitations', (tester) async {
    await mount(tester, const AboutSettingScreen(showTitleBar: false));
    final groupEntries = find.byWidgetPredicate(
      (widget) => widget is EntryItem &&
          (widget.leading == LoftifyIcons.group || widget.leading == LoftifyIcons.send),
    );
    expect(groupEntries, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  for (final key in [TrayKey.officialWebsite, TrayKey.githubRepository]) {
    testWidgets('tray ${key.name} opens the Community repository', (tester) async {
      await mount(tester, const AboutSettingScreen(showTitleBar: false));
      await Utils.processTrayMenuItemClick(
        chewieProvider.rootContext, MenuItem(key: key.key, label: 'test'),
      );
      await tester.pump();
      expect(launched, ['https://github.com/FlozeIII/Loftify']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets('local configuration keeps image settings and downloads available',
      (tester) async {
    await mount(tester, const ImageSettingScreen(showTitleBar: false));
    expect(find.text('Image quality'), findsOneWidget);
    expect(find.text('Large Image Settings'), findsOneWidget);
    expect(find.text('Download Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
