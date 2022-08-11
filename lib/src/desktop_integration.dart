import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xdg_directories/xdg_directories.dart';

final String _linuxAppsMenuDestination = '${dataHome.path}/applications';
final String _linuxAutostartDestination = '${configHome.path}/autostart';

final String _windowsAppsMenuDestination =
    '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs';
final String _windowsAutostartDestination =
    '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs\\Startup';

enum MenuEntryLocation {
  appsMenu,
  autostart,
}

class DesktopIntegration {
  /// The path to the desktop file for Linux, should be a `.desktop` file.
  /// https://wiki.archlinux.org/title/desktop_entries
  final String desktopFilePath;

  final File _originalDesktopFile;

  /// The full path to the icon file to install.
  ///
  /// Currently only SVG supported.
  final String iconPath;

  /// The unique app name, usually a reverse domain identifier:
  /// `com.example.appName`
  final String packageName;

  /// The name of the `.lnk` file for Windows.
  final String linkFileName;

  DesktopIntegration._(
    this._originalDesktopFile, {
    required this.desktopFilePath,
    required this.iconPath,
    required this.packageName,
    required this.linkFileName,
  });

  factory DesktopIntegration({
    String desktopFilePath = '',
    required String iconPath,
    String packageName = '',
    String linkFileName = '',
  }) {
    // Validate inputs.
    switch (Platform.operatingSystem) {
      case 'linux':
        if (desktopFilePath == '' || packageName == '') {
          throw Exception('Both desktopFilePath and packageName required.');
        }
        break;
      case 'windows':
        if (linkFileName == '') {
          throw Exception('linkFileName is required.');
        }
    }

    return DesktopIntegration._(
      File(desktopFilePath),
      desktopFilePath: desktopFilePath,
      iconPath: iconPath,
      packageName: packageName,
      linkFileName: linkFileName,
    );
  }

  /// Integrate app into the operating system's applications menu.
  Future<void> addToApplicationsMenu() async {
    await _installIcon();
    await _installMenuEntry(MenuEntryLocation.appsMenu);
  }

  Future<void> enableAutostart() async {
    await _installIcon();
    await _installMenuEntry(MenuEntryLocation.autostart);
  }

  Future<void> disableAutostart() async {
    switch (Platform.operatingSystem) {
      case 'linux':
        await File('$_linuxAutostartDestination/$packageName.desktop').delete();
        break;
      case 'windows':
        await File('$_windowsAutostartDestination\\$linkFileName.lnk').delete();
        break;
    }
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
        // Windows doesn't need to move the icon anywhere special.
        break;
    }
  }

  /// Install menu item.
  Future<void> _installMenuEntry(MenuEntryLocation menuEntryLocation) async {
    switch (Platform.operatingSystem) {
      case 'linux':
        final String destination =
            (menuEntryLocation == MenuEntryLocation.appsMenu)
                ? _linuxAppsMenuDestination
                : _linuxAutostartDestination;
        // https://wiki.archlinux.org/title/desktop_entries
        if (!await _originalDesktopFile.exists()) {
          throw Exception('Desktop file at $desktopFilePath does not exist.');
        }
        final String desktopFileName = desktopFilePath.split('/').last;
        await Process.run(
          'desktop-file-install',
          ['--dir=$destination', desktopFilePath],
        );
        File installedDesktopFile = await File('$destination/$desktopFileName')
            .rename('$destination/$packageName.desktop');
        await _updateDesktopFile(installedDesktopFile);
        await _validateDesktopFile();
        break;
      case 'windows':
        final String destination =
            (menuEntryLocation == MenuEntryLocation.appsMenu)
                ? _windowsAppsMenuDestination
                : _windowsAutostartDestination;
        // https://docs.microsoft.com/en-us/troubleshoot/windows-client/admin-development/create-desktop-shortcut-with-wsh
        final result = await Process.run('powershell', [
          '-NoProfile',
          '\$wShell = New-Object -comObject WScript.Shell',
          ';',
          '\$shortcut = \$wShell.CreateShortcut("$destination\\$linkFileName.lnk")',
          ';',
          '\$shortcut.TargetPath = "${Platform.resolvedExecutable}"',
          ';',
          '\$shortcut.IconLocation = "$iconPath"',
          ';',
          '\$shortcut.Save()',
        ]);
        if (result.stderr != '') {
          debugPrint('Unable to create app shortcut: ${result.stderr}');
        }
        break;
    }
  }

  Future<void> _updateDesktopFile(File desktopFile) async {
    String desktopFileContents = await desktopFile.readAsString();
    desktopFileContents = desktopFileContents.replaceAll(
      RegExp(r'Icon=.*'),
      'Icon=$packageName',
    );
    desktopFileContents = desktopFileContents.replaceAll(
      RegExp(r'Exec=.*'),
      'Exec="${Platform.resolvedExecutable}"',
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
          debugPrint('''
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
