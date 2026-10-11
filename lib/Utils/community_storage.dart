import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Configures the Windows storage boundary before any store or cache opens.
/// Windows support/cache roots already include the executable's Community
/// CompanyName/ProductName. Its default temporary root, however, is shared.
Future<void> initializeCommunityStorage() async {
  if (!Platform.isWindows) return;
  final current = PathProviderPlatform.instance;
  if (current is! _CommunityPaths) {
    PathProviderPlatform.instance = _CommunityPaths(current);
  }
}

class _CommunityPaths extends PathProviderPlatform {
  _CommunityPaths(this.platform);

  final PathProviderPlatform platform;

  @override
  Future<String?> getTemporaryPath() async {
    final cache = await platform.getApplicationCachePath();
    if (cache == null) {
      throw const FileSystemException('Community cache directory is unavailable');
    }
    final directory = Directory(p.join(cache, 'Cache'));
    await directory.create(recursive: true);
    return directory.path;
  }

  @override
  Future<String?> getApplicationSupportPath() =>
      platform.getApplicationSupportPath();

  @override
  Future<String?> getApplicationCachePath() => platform.getApplicationCachePath();

  @override
  Future<String?> getApplicationDocumentsPath() =>
      platform.getApplicationDocumentsPath();

  @override
  Future<String?> getDownloadsPath() => platform.getDownloadsPath();
}
