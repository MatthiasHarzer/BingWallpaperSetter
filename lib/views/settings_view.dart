import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:flutter/material.dart';

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

    await WallpaperService.checkAndSetBackgroundTaskState();
  }

  // Widget _buildInfoitem({required String title, required String subtitle}) {
  //   return ListTile(
  //     title: Text(title),
  //     subtitle: ,
  //   )
  // }

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
                ListTile(
                  title: const Text("Current Wallpaper Day"),
                  subtitle: Text(ConfigService.currentWallpaperDay),
                ),
                ListTile(
                  title: const Text("Newest Wallpaper Day"),
                  subtitle: Text(ConfigService.newestWallpaperDay),
                ),
                ListTile(
                  title: const Text("Auto Region Locale"),
                  subtitle: Text(ConfigService.autoRegionLocale),
                ),
                ListTile(
                  title: const Text("Background Task Last Run"),
                  subtitle: Text(Util.tsToFormattedTime(
                      ConfigService.bgWallpaperTaskLastRun)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
