import 'dart:convert';
import 'dart:io';

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loftify/Screens/Login/login_by_captcha_screen.dart';
import 'package:loftify/Screens/Navigation/home_screen.dart';
import 'package:loftify/Screens/Navigation/search_screen.dart';
import 'package:loftify/Screens/Post/post_detail_screen.dart';
import 'package:loftify/Screens/main_screen.dart';
import 'package:loftify/Utils/app_provider.dart';
import 'package:loftify/Utils/enums.dart';
import 'package:loftify/Utils/hive_util.dart';
import 'package:loftify/Utils/request_util.dart';
import 'package:loftify/Widgets/PostDetail/post_download_action_icon.dart';
import 'package:loftify/Widgets/loftify_icons.dart';
import 'package:loftify/main.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Cookies extends Fake implements CookieManager {}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
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
    throw const SocketException('Test-only unavailable external endpoint');
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <RequestOptions>[];
  final externalRequests = <Uri>[];
  final pixel = File('assets/logo.png').readAsBytesSync();

  setUpAll(() async {
    final root = Directory('build/test_hive/community_startup').absolute;
    await root.create(recursive: true);
    Hive.init(root.path);
    await Hive.openBox(ChewieHiveUtil.settingsBox);
    PathProviderPlatform.instance = _Paths('${root.path}/support');
    await initializeDateFormatting();
    PackageInfo.setMockInitialValues(
      appName: 'Loftify Community',
      packageName: 'io.github.flozeiii.loftify.community',
      version: '2.5.3', buildNumber: '2503', buildSignature: '',
    );
    RequestUtil.cookieManager = _Cookies();
    for (final name in [
      'window_manager', 'hotkey_manager', 'tray_manager',
      'com.llfbandit.app_links/messages', 'com.llfbandit.app_links/events',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (call.method == 'isAlwaysOnTop' || call.method == 'isMaximized') {
          return false;
        }
        if (call.method == 'getSize') {
          return {'width': 1280.0, 'height': 1000.0};
        }
        if (call.method == 'getBounds') {
          return {'x': 0.0, 'y': 0.0, 'width': 1280.0, 'height': 1000.0};
        }
        return null;
      });
    }
  });

  setUp(() async {
    requests.clear();
    externalRequests.clear();
    await ChewieHiveUtil.put(ChewieHiveUtil.fontFamilyKey, '');
    await ChewieHiveUtil.put(HiveUtil.autoCheckUpdateKey, false);
    await ChewieHiveUtil.put(HiveUtil.showTrayKey, false);
    await ChewieHiveUtil.put(HiveUtil.showDownloadKey, true);
    await ChewieHiveUtil.put(HiveUtil.overrideCloudControlKey, true);
    await ChewieHiveUtil.put('cloudControl', {
      'enableApp': false,
      'disableReasonTitle': 'Historical forced exit',
      'contacts': {'issueUrl': 'https://example.invalid/upstream'},
      'features': {'showDress': false, 'image': {'showDownloadButton': false}},
    });
    appProvider.token = '';
    appProvider.locale = const Locale('en');
    appProvider.sidebarChoice = SideBarChoice.Home;
    for (final client in [RequestUtil.instance, RequestUtil.wwwInstance, RequestUtil.daInstance]) {
      client.dio.interceptors.clear();
      client.dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        requests.add(options);
        final dynamic data;
        if (options.path.endsWith('getPhotoCaptcha.do')) {
          data = pixel;
        } else if (options.path == '/datacollect/v1/upload') {
          data = {'code': 200};
        } else if (options.path == '/v1.1/trade/gift/post/newSupportInfo') {
          // This optional enrichment is absent; the readable post stays valid.
          data = null;
        } else if (options.path == '/oldapi/post/detail.api') {
          data = {
            'meta': {'status': 200},
            'response': {'posts': [{
              'liked': false,
              'post': {
                'id': 42, 'blogId': 7, 'type': 1,
                'title': 'Community readable article',
                'content': '<p>Community article body</p><img src="data:image/png;base64,${base64Encode(pixel)}">',
                'blogInfo': {'blogId': 7, 'blogName': 'fixture', 'blogNickName': 'Fixture'},
                'postCount': {'favoriteCount': 0, 'responseCount': 0},
              },
            }]},
          };
        } else {
          data = {
            'meta': {'status': 200}, 'response': {}, 'code': 0,
            'data': {'list': [], 'items': [], 'offset': 0, 'hotList': [], 'hotTotal': 0},
          };
        }
        handler.resolve(Response(requestOptions: options, data: data));
      }));
    }
  });

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('mounted startup reaches login, guest browsing and search with no remote configuration',
      (tester) async {
    viewport(tester);
    await ChewieHiveUtil.put(ChewieHiveUtil.firstLoginKey, true);
    await ChewieHiveUtil.delete(HiveUtil.tokenKey);
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(MyApp(home: MainScreen(key: mainScreenKey)));
      await frames(tester);
      expect(find.byType(LoginByCaptchaScreen), findsOneWidget);
      expect(find.text('Historical forced exit'), findsNothing);
      expect(requests.map((r) => r.path), containsAll([
        '/v2.0/uploadNewDevice.api', '/v2.0/autoLogin.api', '/v1.1/configs.api',
        '/lpt/photoCaptcha/getPhotoCaptcha.do',
      ]));
      await tester.tap(find.byIcon(LucideIcons.x));
      await frames(tester);
      expect(find.byType(LoginByCaptchaScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      final search = find.byWidgetPredicate(
        (w) => w is ToolButton && w.icon == LoftifyIcons.search,
      );
      await tester.tap(search.first);
      await frames(tester);
      expect(find.byType(SearchScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'community');
      await frames(tester);
      expect(requests.map((r) => r.path), contains('/newsearch/sug.json'));
      final home = find.byWidgetPredicate(
        (w) => w is ToolButton && w.icon == LoftifyIcons.home,
      );
      await tester.tap(home.first);
      await frames(tester);
      expect(requests.map((r) => r.path), contains('/recommend/exploreRecom.json'));
      expect(requests.every((r) => r.uri.host.endsWith('lofter.com')), isTrue);
      expect(externalRequests.where((u) => u.path.endsWith('/control.json')), isEmpty);
      expect(find.text('Historical forced exit'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
    }, createHttpClient: (_) => _OfflineClient(externalRequests));
  });

  testWidgets('article content request and usable download action survive historical disabled features',
      (tester) async {
    viewport(tester);
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(const MyApp(home: PostDetailScreen(
        isArticle: true,
        meta: {'postId': '2a', 'blogId': '7', 'blogName': 'fixture'},
      )));
      await frames(tester);
      expect(requests.map((r) => r.path), contains('/oldapi/post/detail.api'));
      expect(find.text('Community readable article'), findsWidgets);
      final download = find.byType(PostDownloadActionIcon);
      expect(download, findsOneWidget);
      final button = find.ancestor(of: download, matching: find.byType(CircleIconButton));
      expect(tester.widget<CircleIconButton>(button).onTap, isNotNull);
      expect(externalRequests.where((u) => u.path.endsWith('/control.json')), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
    }, createHttpClient: (_) => _OfflineClient(externalRequests));
  });
}
