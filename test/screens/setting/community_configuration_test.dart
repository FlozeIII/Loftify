import 'dart:io';

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:loftify/Screens/Setting/about_setting_screen.dart';
import 'package:loftify/Screens/main_screen.dart';
import 'package:loftify/Utils/app_provider.dart';
import 'package:loftify/Utils/cloud_control_provider.dart';
import 'package:loftify/Utils/hive_util.dart';
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

  testWidgets('about feedback opens the Community issue tracker',
      (tester) async {
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
            return const AboutSettingScreen(showTitleBar: false);
          }),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final feedback = find.byWidgetPredicate(
      (widget) => widget is EntryItem && widget.leading == LoftifyIcons.bug,
    );
    expect(feedback, findsOneWidget);
    await tester.ensureVisible(feedback);
    await tester.tap(feedback);
    await tester.pump();

    expect(launched, ['https://github.com/FlozeIII/Loftify/issues']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
