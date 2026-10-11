import 'dart:ffi';
import 'dart:io';

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/open.dart';
import 'package:loftify/Database/database_manager.dart';
import 'package:loftify/Utils/hive_util.dart';
import 'package:hive/hive.dart';
import 'package:loftify/Utils/community_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:loftify/Utils/request_util.dart';

class _StoragePaths extends PathProviderPlatform {
  _StoragePaths(this.support);
  final String support;

  @override
  Future<String?> getApplicationSupportPath() async => support;

  @override
  Future<String?> getApplicationCachePath() async => p.join(support, 'Local');

  @override
  Future<String?> getTemporaryPath() async => p.join(support, 'SystemTemp');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('desktop database is created inside the application data directory',
      () async {
    final fixture = await Directory.systemTemp.createTemp('community-storage-');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance =
        _StoragePaths(p.join(fixture.path, 'FlozeIII', 'Loftify Community'));
    if (Platform.isWindows) {
      open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(
          p.join(Directory.current.path, 'tools', 'windows_dll', 'sqlite3.dll')));
    }
    try {
      final db = await DatabaseManager.getDataBase();
      try {
        expect(db.path,
            p.join(await FileUtil.getDatabaseDir(), 'loftify.db'));
        expect(await DatabaseManager.isTableExist('rssItems'), isTrue);
      } finally {
        await db.close();
      }
    } finally {
      PathProviderPlatform.instance = original;
      await fixture.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);

  test('first launch defaults preserve explicit preferences on restart',
      () async {
    final fixture = await Directory.systemTemp.createTemp('community-defaults-');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _StoragePaths(fixture.path);
    try {
      await HiveUtil.initBox();
      await ChewieHiveUtil.put(HiveUtil.showRecommendVideoKey, true);
      await ChewieHiveUtil.put(HiveUtil.showSearchHistoryKey, false);
      await HiveUtil.initConfig();
      await Hive.close();
      await HiveUtil.initBox();
      expect(ChewieHiveUtil.getBool(HiveUtil.showRecommendVideoKey), isTrue);
      expect(ChewieHiveUtil.getBool(HiveUtil.showSearchHistoryKey), isFalse);
      expect(ChewieHiveUtil.getBool(HiveUtil.showRecommendArticleKey), isTrue);
    } finally {
      await Hive.close();
      PathProviderPlatform.instance = original;
      await fixture.delete(recursive: true);
    }
  });

  test('clearing Community cache leaves shared temporary files untouched',
      () async {
    final fixture = await Directory.systemTemp.createTemp('community-cache-');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _StoragePaths(fixture.path);
    final shared = Directory(p.join(fixture.path, 'SystemTemp'));
    await shared.create();
    final sentinel = File(p.join(shared.path, 'other-app.txt'));
    await sentinel.writeAsString('must remain');
    try {
      await initializeCommunityStorage();
      final temp = await getTemporaryDirectory();
      expect(temp.path, p.join(fixture.path, 'Local', 'Cache'));
      await File(p.join(temp.path, 'community.txt')).writeAsString('cache');
      await CacheUtil.delDir(temp);
      expect(await sentinel.readAsString(), 'must remain');
      expect(await (await getTemporaryDirectory()).exists(), isTrue);
    } finally {
      PathProviderPlatform.instance = original;
      await fixture.delete(recursive: true);
    }
  }, skip: !Platform.isWindows);

  test('Community preferences and cookies persist without importing old auth',
      () async {
    final fixture = await Directory.systemTemp.createTemp('community-isolation-');
    final original = PathProviderPlatform.instance;
    final source = p.join(fixture.path, 'upstream');
    final target = p.join(fixture.path, 'community');
    final download = File(p.join(fixture.path, 'chosen-download', 'saved.txt'));
    await download.parent.create(recursive: true);
    await download.writeAsString('user content');
    await Hive.openBox(HiveUtil.settingsBox, path: source);
    await ChewieHiveUtil.put(HiveUtil.tokenKey, 'upstream-fixture-only');
    await ChewieHiveUtil.put(HiveUtil.showSearchHistoryKey, false);
    await Hive.close();
    PathProviderPlatform.instance = _StoragePaths(target);
    try {
      await initializeCommunityStorage();
      await HiveUtil.initBox();
      expect(Hive.box(HiveUtil.settingsBox).containsKey(HiveUtil.tokenKey),
          isFalse);
      expect(ChewieHiveUtil.getBool(HiveUtil.showSearchHistoryKey), isTrue);
      await ChewieHiveUtil.put(HiveUtil.showSearchHistoryKey, false);
      await ChewieHiveUtil.put(ChewieHiveUtil.savePathKey, download.parent.path);
      await RequestUtil.init();
      final uri = Uri.parse('https://fixture.invalid');
      await RequestUtil.cookieJar!
          .saveFromResponse(uri, [Cookie('fixture', 'community')]);
      await Hive.close();
      await HiveUtil.initBox();
      await RequestUtil.init();
      expect(ChewieHiveUtil.getBool(HiveUtil.showSearchHistoryKey), isFalse);
      expect(ChewieHiveUtil.getString(ChewieHiveUtil.savePathKey),
          download.parent.path);
      expect((await RequestUtil.cookieJar!.loadForRequest(uri)).single.value,
          'community');
      expect(await download.readAsString(), 'user content');
      await Hive.close();
      await Hive.openBox(HiveUtil.settingsBox, path: source);
      expect(ChewieHiveUtil.getString(HiveUtil.tokenKey), 'upstream-fixture-only');
      expect(ChewieHiveUtil.getBool(HiveUtil.showSearchHistoryKey), isFalse);
      final emptySourceJar = PersistCookieJar(
          storage: FileStorage(p.join(source, 'Cookies')));
      expect(await emptySourceJar.loadForRequest(uri), isEmpty);
    } finally {
      await Hive.close();
      RequestUtil.cookieJar = null;
      RequestUtil.cookieManager = null;
      PathProviderPlatform.instance = original;
      await fixture.delete(recursive: true);
    }
  });
}
