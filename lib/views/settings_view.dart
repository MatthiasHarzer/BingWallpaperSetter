import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:flutter/material.dart';

import '../services/wallpaper_service.dart';

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

  Widget _buildSwitchItem(
      {required String title,
      required bool value,
      required Function(bool) onChanged,
      String? subtitle}) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : Container(),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
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
    if(!options.keys.contains(value)){
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
      body: Column(
        children: [
          Column(
            children: [
              _buildHeader(text: "Customize"),
              Visibility(
                visible: true,
                child: _buildSwitchItem(
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
              _buildSwitchItem(
                  title: "Save Wallpapers To Gallery",
                  subtitle: "Newly downloaded wallpapers will be saved to the gallery",
                  value: ConfigService.saveWallpaperToGallery,
                  onChanged: (v) => setState((){
                    ConfigService.saveWallpaperToGallery = v;
                  }),
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }
}
