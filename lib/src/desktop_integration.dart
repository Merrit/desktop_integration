import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:xdg_directories/xdg_directories.dart';

class DesktopIntegration {
  /// The path to the desktop file. On Linux this should be a `.desktop` file.
  /// https://wiki.archlinux.org/title/desktop_entries
  ///
  /// On Windows this should be ...
  final String desktopFilePath;

  /// The full path to the icon file to install.
  ///
  /// Currently only SVG supported.
  final String iconPath;

  /// The unique app name, usually a reverse domain identifier:
  /// `com.example.appName`
  final String packageName;

  // TODO: Add file properties here.

  const DesktopIntegration({
    required this.desktopFilePath,
    required this.iconPath,
    required this.packageName,
  });

  /// Integrate app into the operating system's applications menu.
  Future<void> addToApplicationsMenu() async {
    await _installIcon();
    await _installDesktopFile();
  }

  /// Install icon.
  Future<void> _installIcon() async {
    final iconFile = File(iconPath);
    if (!await iconFile.exists()) {
      throw Exception('Icon file at $iconPath does not exist.');
    }

    switch (Platform.operatingSystem) {
      case 'linux':
        // https://wiki.archlinux.org/title/icons
        final pathWithName =
            '${dataHome.path}/icons/hicolor/scalable/apps/$packageName.svg';
        await iconFile.copy(pathWithName);
        // await iconFile.rename(pathWithName);
        break;
      case 'windows':
        break;
    }
  }

  /// Install menu item.
  Future<void> _installDesktopFile() async {
    final desktopFile = File(desktopFilePath);
    if (!await desktopFile.exists()) {
      throw Exception('Desktop file at $desktopFilePath does not exist.');
    }

    final String desktopFileName = desktopFilePath.split('/').last;

    late File installedDesktopFile;
    switch (Platform.operatingSystem) {
      case 'linux':
        // https://wiki.archlinux.org/title/desktop_entries
        await Process.run(
          'desktop-file-install',
          ['--dir=${dataHome.path}/applications', desktopFilePath],
        );
        // TODO: Cleanup this rename / get new path mess.
        installedDesktopFile = await File(
          '${dataHome.path}/applications/$desktopFileName',
        ).rename('${dataHome.path}/applications/$packageName.desktop');
        break;
      case 'windows':
        break;
    }

    await _updateDesktopFile(installedDesktopFile);
    await _validateDesktopFile();
  }

  Future<void> _updateDesktopFile(File desktopFile) async {
    // TODO: Add windows implementation.
    String desktopFileContents = await desktopFile.readAsString();
    desktopFileContents = desktopFileContents.replaceAll(
      RegExp(r'Icon=.*'),
      'Icon=$packageName',
    );
    desktopFileContents = desktopFileContents.replaceAll(
      RegExp(r'Exec=.*'),
      'Exec=${Platform.resolvedExecutable}',
    );
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    desktopFileContents = desktopFileContents.replaceAll(
      RegExp(r'StartupWMClass=.*'),
      'StartupWMClass=${packageInfo.packageName}',
    );

    await desktopFile.writeAsString(desktopFileContents);
  }

  /// Validate desktop file is properly formatted.
  Future<void> _validateDesktopFile() async {
    switch (Platform.operatingSystem) {
      case 'linux':
        final result = await Process.run(
          'desktop-file-validate',
          [desktopFilePath],
        );
        if (result.stderr != '' || result.stdout != '') {
          print('''
Desktop file failed validation:
${result.stdout}
${result.stderr}''');
        }
        break;
      case 'windows':
        break;
    }
  }
}
