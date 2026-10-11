import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:win32_registry/win32_registry.dart';

/// Upgrade only our argument-free legacy Run command. In particular, leave
/// StartupApproved untouched so a Windows-disabled entry stays disabled.
void normalizeCommunityStartupCommand(String appName, String executable) {
  if (!Platform.isWindows) return;
  final key = Registry.openPath(
    RegistryHive.currentUser,
    path: r'Software\Microsoft\Windows\CurrentVersion\Run',
    desiredAccessRights: AccessRights.allAccess,
  );
  try {
    final command = key.getValueAsString(appName);
    if (command == null || command.startsWith('"')) return;
    if (path.windows.normalize(command).toLowerCase() !=
        path.windows.normalize(executable).toLowerCase()) {
      return;
    }
    key.createValue(RegistryValue(
      appName,
      RegistryValueType.string,
      '"$executable"',
    ));
  } finally {
    key.close();
  }
}
