import 'dart:io';

import 'package:bing_wallpaper_setter/extensions/datetime.dart';
import 'package:bing_wallpaper_setter/services/background_service.dart';
import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:optimize_battery/optimize_battery.dart';
import 'package:permission_handler/permission_handler.dart';
import '../consts.dart' as consts;

import '../services/wallpaper_service.dart';
import '../util/util.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  ThemeData get theme => Theme.of(context);

  void _toggleDailyMode(bool enabled) async {
    ConfigService.dailyModeEnabled = enabled;

    if (enabled) {
      bool ignoreBatteryOptimizationGranted =
          await _requestIgnoreBatteryOptimization();

      if (!ignoreBatteryOptimizationGranted && mounted) {
        Util.showSnackBar(
          context,
          seconds: 30,
          content: const Text(
              "Battery optimization might negatively influence the behavior of the app."),
          action: SnackBarAction(
            label: "OPEN SETTINGS",
            onPressed: () => OptimizeBattery.openBatteryOptimizationSettings(),
          ),
        );
      }
    }

    await BackgroundService.checkAndScheduleTask();

    /// Update the wallpaper instant
    if (enabled) {
      await WallpaperService.updateWallpaperOnBackgroundTaskIntent();
    }
  }

  Future<bool> _requestIgnoreBatteryOptimization() async {
    final PermissionStatus status =
        await Permission.ignoreBatteryOptimizations.status;

    if (status != PermissionStatus.granted) {
      if (await Permission.ignoreBatteryOptimizations.request() !=
          PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  // Widget _buildInfoitem({required String title, required String subtitle}) {
  //   return ListTile(
  //     title: Text(title),
  //     subtitle: ,
  //   )
  // }

  /// Build an item with a single icon button
  Widget _buildIconButton({
    required String title,
    required VoidCallback onClick,
    required IconData icon,
    bool enabled = true,
    String? subtitle,
    String? tooltip,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: IconButton(
        onPressed: !enabled ? null : onClick,
        icon: Icon(icon),
        color: Colors.grey[300],
        splashRadius: 25,
        tooltip: tooltip,
      ),
    );
  }

  /// Builds a switch option
  Widget _buildSwitch({
    required String title,
    required bool value,
    required Function(bool) onChanged,
    String? subtitle,
    Widget? enabledAction,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : Container(),
      trailing: FittedBox(
        fit: BoxFit.fill,
        child: Row(
          children: [
            Visibility(
              visible: value && enabledAction != null,
              child: enabledAction ?? Container(),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
      onTap: () => onChanged(!value),
    );
  }

  /// Builds a dropdown select menu option
  Widget _buildSelect<T>(
      {required String title,
      String? subtitle,
      required T? value,
      required Function(T) onChanged,
      required Map<T, String> options}) {
    List<DropdownMenuItem<T>> dropDownItems = options
        .map((locale, name) => MapEntry(
            locale,
            DropdownMenuItem<T>(
              value: locale,
              child: Text(name),
            )))
        .values
        .toList();
    final GlobalKey dropDownKey = GlobalKey();
    if (!options.keys.contains(value)) {
      value = null;
    }
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: DropdownButton(
        key: dropDownKey,
        value: value,
        items: dropDownItems,
        onChanged: (T? newValue) {
          if (newValue == null) {
            return;
          }

          onChanged(newValue);
        },
      ),
    );
  }

  /// Builds a directory select option
  Widget _buildDirectorySelect({
    required String title,
    required String directory,
    required Function(String) onChanged,
    String? defaultDirectory,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(directory),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () async {
              final String? newDirectory =
                  await FilePicker.platform.getDirectoryPath();
              if (newDirectory != null) {
                onChanged(newDirectory);
              }
            },
            icon: const Icon(Icons.folder),
            tooltip: "Select directory",
            color: Colors.grey[300],
            splashRadius: 25,
          ),
          Visibility(
            visible: defaultDirectory != null && defaultDirectory != directory,
            child: IconButton(
              onPressed: () {
                onChanged(defaultDirectory!);
              },
              icon: const Icon(Icons.restore),
              tooltip: "Restore default directory",
              color: Colors.red[500],
              splashRadius: 25,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a header for a group of options
  Widget _buildHeader({required String text}) {
    return ListTile(
      title: Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.deepPurpleAccent,
            fontSize: 15,
            fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView(
        children: [
          Column(
            children: [
              _buildHeader(text: "Customize"),
              Visibility(
                visible: true,
                child: _buildSwitch(
                  title: "Daily Mode",
                  subtitle: "Update the wallpaper once a day",
                  value: ConfigService.dailyModeEnabled,
                  onChanged: (v) => setState(() {
                    _toggleDailyMode(v);
                  }),
                ),
              ),
              _buildSelect(
                title: "Select Region",
                value: ConfigService.region,
                options: ConfigService.availableRegions,
                onChanged: (String v) =>
                    setState(() => ConfigService.region = v),
              ),
              _buildSelect(
                title: "Wallpaper Screen",
                value: ConfigService.wallpaperScreen,
                options: ConfigService.availableScreens,
                onChanged: (int v) =>
                    setState(() => ConfigService.wallpaperScreen = v),
              ),
              _buildSelect(
                title: "Wallpaper Resolution",
                value: ConfigService.wallpaperResolution,
                options: {
                  for (var r in ConfigService.availableResolutions) r: r
                },
                onChanged: (String v) =>
                    setState(() => ConfigService.wallpaperResolution = v),
              ),
              _buildSwitch(
                title: "Save Wallpapers To Gallery",
                subtitle:
                    "Newly downloaded wallpapers will be saved to the gallery",
                value: ConfigService.saveWallpaperToGallery,
                onChanged: (v) => setState(() {
                  ConfigService.saveWallpaperToGallery = v;
                }),
              ),
              _buildDirectorySelect(
                title: "Gallery Directory",
                directory: ConfigService.galleryDir.path,
                defaultDirectory: consts.DEFAULT_GALLERY_DIR,
                onChanged: (v) => setState(() {
                  ConfigService.galleryDir = Directory(v);
                }),
              ),
            ],
          ),
          const Divider(),
          _buildHeader(text: "DEBUG"),
          _buildSwitch(
            title: "Show Debug Values",
            subtitle: "Only enable when needed",
            value: ConfigService.showDebugValues,
            onChanged: (bool v) async {
              await ConfigService.reload();
              setState(() => ConfigService.showDebugValues = v);
            },
            enabledAction: IconButton(
              splashRadius: 25,
              onPressed: () async {
                await ConfigService.reload();
                setState(() {});
              },
              icon: const Icon(Icons.sync),
              tooltip: "Reload",
            ),
          ),
          Visibility(
            visible: ConfigService.showDebugValues,
            child: Column(
              children: [
                _buildIconButton(
                    title: "Current Wallpaper Day",
                    subtitle: ConfigService.currentWallpaperDay,
                    onClick: () {
                      setState(() {
                        ConfigService.currentWallpaperDay = "";
                      });
                    },
                    icon: Icons.delete,
                    tooltip: "Delete Data",
                    enabled: ConfigService.currentWallpaperDay.isNotEmpty),
                _buildIconButton(
                    title: "Newest Wallpaper Day",
                    subtitle: ConfigService.newestWallpaperDay,
                    onClick: () {
                      setState(() {
                        ConfigService.newestWallpaperDay = "";
                      });
                    },
                    icon: Icons.delete,
                    tooltip: "Delete Data",
                    enabled: ConfigService.newestWallpaperDay.isNotEmpty),
                ListTile(
                  title: const Text("Auto Region Locale"),
                  subtitle: Text(ConfigService.autoRegionLocale),
                ),
                ListTile(
                  title: const Text("Background Task Last Run"),
                  subtitle: Text(Util.tsToFormattedTime(
                      ConfigService.bgWallpaperTaskLastRun)),
                ),
                Visibility(
                  visible: ConfigService.dailyModeEnabled,
                  child: ListTile(
                    title: const Text("Background Task Next Target Run"),
                    subtitle: Text(
                      DateTime(DateTime.now().year, DateTime.now().month,
                              DateTime.now().day + 1)
                          .formattedWithTime,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
