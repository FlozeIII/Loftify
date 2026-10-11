import 'dart:ffi';
import 'dart:io';

import 'package:awesome_chewie/awesome_chewie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/open.dart';
import 'package:loftify/Database/database_manager.dart';

class _StoragePaths extends PathProviderPlatform {
  _StoragePaths(this.support);
  final String support;

  @override
  Future<String?> getApplicationSupportPath() async => support;
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
  });
}
