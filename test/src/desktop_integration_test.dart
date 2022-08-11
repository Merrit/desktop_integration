import 'dart:io';

import 'package:desktop_integration/src/desktop_integration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xdg_directories/xdg_directories.dart';

Future<void> main() async {
  // Be sure to add this line if `PackageInfo.fromPlatform()` is called before runApp()
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPackageName = 'com.example.ricecooker';

  final iconFile = File(
    '${dataHome.path}/icons/hicolor/scalable/apps/$testPackageName.svg',
  );

  final desktopFile = File(
    '${dataHome.path}/applications/$testPackageName.desktop',
  );

  group('DesktopIntegration:', () {
    tearDown(() async {
      try {
        await iconFile.delete();
      } catch (e) {
        debugPrint('tearDown: No icon to clean up.');
      }

      try {
        await desktopFile.delete();
      } catch (e) {
        debugPrint('tearDown: No desktop file to clean up.');
      }
    });

    test('updating desktop file works', () async {
      final desktopIntegration = DesktopIntegration(
        desktopFilePath: 'assets/com.example.ricecooker.desktop',
        iconPath: 'assets/icon.svg',
        packageName: 'com.example.ricecooker',
      );

      await desktopIntegration.addToApplicationsMenu();

      expect(iconFile.existsSync(), true);
      expect(desktopFile.existsSync(), true);

      final desktopFileContents = await desktopFile.readAsString();

      final iconEntry = RegExp(r'Icon=.*') //
          .firstMatch(desktopFileContents)
          ?.group(0);
      expect(iconEntry, 'Icon=com.example.ricecooker');

      final execEntry = RegExp(r'Exec=.*') //
          .firstMatch(desktopFileContents)
          ?.group(0);
      expect(execEntry!.split('/').last, 'flutter_tester"');

      final startupWMClassEntry = RegExp(r'StartupWMClass=.*') //
          .firstMatch(desktopFileContents)
          ?.group(0);
      // Only real Flutter apps seem to have this set, so test will be empty
      // unless we can figure out a better way to check here.
      expect(startupWMClassEntry, 'StartupWMClass=');
    });
  });
}
