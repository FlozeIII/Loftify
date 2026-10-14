import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
import 'package:loftify/Utils/download_task_manager.dart';
import 'package:loftify/Utils/request_util.dart';
import 'package:loftify/Widgets/PostDetail/post_download_action_icon.dart';
import 'package:loftify/Widgets/loftify_icons.dart';
import 'package:loftify/main.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const fixtureImageUrl = 'https://images.example.invalid/fixture.png';

class _Cookies extends Fake implements CookieManager {}

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => '$root/cache';
  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';
}

class _NetworkBoundary extends HttpOverrides {
  _NetworkBoundary(this.requests);
  final List<Uri> requests;
  @override
  HttpClient createHttpClient(SecurityContext? context) => _OfflineClient(requests);
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
    await Hive.openBox(ChewieHiveUtil.settingsBox, bytes: Uint8List(0));
    PathProviderPlatform.instance = _Paths('${root.path}/support');
    await initializeDateFormatting();
    await ChewieHiveUtil.put(ChewieHiveUtil.savePathKey, '${root.path}/downloads');
    await DefaultCacheManager().putFile(fixtureImageUrl, pixel, fileExtension: 'png');
    PackageInfo.setMockInitialValues(
      appName: 'Loftify Community',
      packageName: 'io.github.flozeiii.loftify.community',
      version: '2.5.3', buildNumber: '2503', buildSignature: '',
    );
    RequestUtil.cookieManager = _Cookies();
    for (final name in [
      'window_manager', 'hotkey_manager', 'tray_manager',
      'com.llfbandit.app_links/messages', 'com.llfbandit.app_links/events',
      'dev.fluttercommunity.plus/connectivity', 'dev.fluttercommunity.plus/connectivity_status',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (call) async {
        if (call.method == 'check') return ['wifi'];
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
    await DownloadTaskManager.instance.initialize();
  });

  setUp(() async {
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = _NetworkBoundary(externalRequests);
    addTearDown(() { HttpOverrides.global = previousHttpOverrides; });
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
                'content': '<p>Community article body</p><img src="$fixtureImageUrl">',
                'blogInfo': {
                  'blogId': 7, 'blogName': 'fixture', 'blogNickName': 'Fixture',
                  'bigAvaImg': '', 'homePageUrl': '', 'imageDigitStamp': false,
                  'imageProtected': false, 'imageStamp': false,
                  'isOriginalAuthor': false,
                },
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
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
    });
  }

  testWidgets('mounted startup reaches login, guest browsing and search with no remote configuration',
      (tester) async {
    viewport(tester);
    await ChewieHiveUtil.put(ChewieHiveUtil.firstLoginKey, true);
    await ChewieHiveUtil.delete(HiveUtil.tokenKey);
      await tester.pumpWidget(MyApp(home: MainScreen(key: mainScreenKey)));
      await frames(tester);
      expect(find.byType(LoginByCaptchaScreen), findsOneWidget);
      expect(find.text('Historical forced exit'), findsNothing);
      expect(requests.map((r) => r.path), containsAll([
        '/v2.0/uploadNewDevice.api', '/v2.0/autoLogin.api', '/v1.1/configs.api',
        '/lpt/photoCaptcha/getPhotoCaptcha.do',
      ]));
      final close = find.widgetWithIcon(ToolButton, LucideIcons.x);
      expect(close, findsOneWidget);
      await tester.tap(close);
      await frames(tester);
      expect(find.byType(LoginByCaptchaScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      final search = find.widgetWithIcon(ToolButton, LoftifyIcons.search);
      await tester.tap(search.first);
      await frames(tester);
      expect(find.byType(SearchScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField).hitTestable().first, 'community');
      await frames(tester);
      expect(requests.map((r) => r.path), contains('/newsearch/sug.json'));
      final home = find.widgetWithIcon(ToolButton, LoftifyIcons.home);
      await tester.tap(home.first);
      await frames(tester);
      expect(requests.map((r) => r.path), contains('/recommend/exploreRecom.json'));
      expect(requests.every((r) => r.uri.host.endsWith('lofter.com')), isTrue);
      expect(externalRequests.where((u) => u.path.endsWith('/control.json')), isEmpty);
      expect(find.text('Historical forced exit'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('article content request and usable download action survive historical disabled features',
      (tester) async {
    viewport(tester);
      await tester.pumpWidget(const MyApp(home: PostDetailScreen(
        isArticle: true,
        meta: {'postId': '2a', 'blogId': '7', 'blogName': 'fixture'},
      )));
      await frames(tester);
      expect(requests.map((r) => r.path), contains('/oldapi/post/detail.api'));
      final title = find.textContaining('Community readable article', findRichText: true);
      for (var i = 0; i < 20 && title.evaluate().isEmpty; i++) {
        // HTML and the cached image finish at the real codec/file boundary.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump();
      }
      expect(title, findsWidgets);
      final download = find.byType(PostDownloadActionIcon);
      expect(download, findsOneWidget);
      final button = find.ancestor(of: download, matching: find.byType(CircleIconButton));
      final transfer = Completer<bool>();
      var observingTask = false;
      void changed() {
        if (DownloadTaskManager.instance.tasks.any((task) => task.url == fixtureImageUrl) &&
            !observingTask) {
          observingTask = true;
          final task = DownloadTaskManager.instance.tasks.firstWhere(
              (task) => task.url == fixtureImageUrl);
          DownloadTaskManager.instance.waitForCompletion(task.id).then(transfer.complete);
        }
      }
      DownloadTaskManager.instance.addListener(changed);
      addTearDown(() => DownloadTaskManager.instance.removeListener(changed));
      final before = externalRequests.where((u) => u.toString() == fixtureImageUrl).length;
      await tester.tap(button);
      // Task listeners and widget callbacks belong to the test's fake async
      // zone. Drain that zone between real file/HTTP work instead of waiting
      // for their completion inside runAsync, which cannot pump those callbacks.
      for (var i = 0; i < 100 && !transfer.isCompleted; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(transfer.isCompleted, isTrue,
          reason: 'The download action must reach a terminal task state');
      final outcome = await transfer.future;
      await tester.pump(const Duration(milliseconds: 200));
      DownloadTaskManager.instance.removeListener(changed);
      // The isolated HTTP transport is deliberately offline; the real action
      // must create a task, attempt the transfer and render the retryable error.
      expect(outcome, isFalse);
      expect(externalRequests.where((u) => u.toString() == fixtureImageUrl).length,
          greaterThan(before));
      expect(find.byKey(const ValueKey('post-download-failed')), findsOneWidget);
      expect(externalRequests.where((u) => u.path.endsWith('/control.json')), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await frames(tester);
  }, timeout: const Timeout(Duration(seconds: 60)));

  tearDownAll(() async {
    DownloadTaskManager.instance.dispose();
    await DefaultCacheManager().dispose();
  });
}
