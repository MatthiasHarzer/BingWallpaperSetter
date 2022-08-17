import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:bing_wallpaper_setter/services/wallpaper_service.dart';
import 'package:bing_wallpaper_setter/util/util.dart';
import 'package:bing_wallpaper_setter/views/about_view.dart';
import 'package:bing_wallpaper_setter/views/old_wallpapers_view.dart';
import 'package:bing_wallpaper_setter/views/settings_view.dart';
import 'package:bing_wallpaper_setter/views/wallpaper_view.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:optimize_battery/optimize_battery.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:workmanager/workmanager.dart';

import 'consts.dart' as consts;
import 'drawer.dart';



/// The callback dispatcher for the workmanager background isolate
void workManagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    var logger = getLogger();
    logger.d("Running background task");
    try {
      await ConfigService.ensureInitialized();

      switch (task) {
        case consts.BG_WALLPAPER_TASK_ID:
          if (!ConfigService.dailyModeEnabled) break;

          await WallpaperService.tryUpdateWallpaper();

          ConfigService.bgWallpaperTaskLastRun =
              DateTime.now().millisecondsSinceEpoch;
      }
    } catch (error) {
      logger.e(error.toString());
    }

    return true;
  });
}

/// The callback, when the widget was clicked
Future<void> widgetBackgroundCallback(Uri? uri) async {
  await ConfigService.ensureInitialized();

  if (uri?.host == "updatewallpaper") {
    await WallpaperService.updateWallpaperOnWidgetIntent();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConfigService.ensureInitialized();
  await WallpaperService.ensureMaxCacheWallpapers();

  await Workmanager()
      .initialize(workManagerCallbackDispatcher, isInDebugMode: true);
  await WallpaperService.checkAndSetBackgroundTaskState();

  HomeWidget.registerBackgroundCallback(widgetBackgroundCallback);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bing Daily Wallpaper',
      theme: ThemeData(
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.deepPurpleAccent
                  : null),
          trackColor: MaterialStateProperty.resolveWith((states) =>
              states.contains(MaterialState.selected)
                  ? Colors.deepPurple[500]
                  : null),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Colors.grey.shade900,
          contentTextStyle: const TextStyle(color: Colors.white),
          actionTextColor: Colors.deepPurpleAccent,
        ),
        primarySwatch: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WallpaperInfo? wallpaper;
  var logger = getLogger();

  @override
  void initState() {
    super.initState();

    _updateWallpaper();
    _checkPermission();
  }

  /// Checks for required permission
  void _checkPermission() async {
    bool storagePermissionGranted = await _requestStoragePermission();
    bool ignoreBatteryOptimizationGranted =
        await _requestIgnoreBatteryOptimization();

    if (!mounted) return;

    if (!storagePermissionGranted) {
      Util.showSnackBar(
        context,
        seconds: 30,
        content: const Text(
            "Storage permission denied. The app might not work correctly."),
        action: SnackBarAction(
          label: "OPEN APP SETTINGS",
          onPressed: () => openAppSettings(),
        ),
      );
    }

    if (!ignoreBatteryOptimizationGranted) {
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

  /// Requests storage permission. Returns whether permission is granted or not
  Future<bool> _requestStoragePermission() async {
    final PermissionStatus permission = await Permission.storage.status;
    if (permission != PermissionStatus.granted) {
      if (await Permission.storage.request() != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
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

  /// Checks for wallpaper updates and sets the wallpaper variable. Returns true if updated or false if now update is present
  Future<bool> _updateWallpaper() async {
    WallpaperInfo newWallpaper =
        await WallpaperService.getWallpaper(local: ConfigService.region);
    await WallpaperService.ensureDownloaded(newWallpaper);

    bool update = newWallpaper.mobileUrl != wallpaper?.mobileUrl;

    setState(() {
      wallpaper = newWallpaper;
    });

    if (update) {
      logger.d("Updated wallpaper: $wallpaper");
    }

    return update;
  }




  /// Opens the settings window
  void _openSettingsView() {
    Navigator.pop(context);
    Navigator.push(
      context,
      Util.createScaffoldRoute(view: const SettingsView()),
    );
  }

  void _openAboutView() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => const AboutView(),
    );
  }

  void _openOldWallpapersView() {
    Navigator.pop(context);
    Navigator.push(
      context,
      Util.createScaffoldRoute(view: const OldWallpapersView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WallpaperView(
      wallpaper: wallpaper,
      onUpdateWallpaper: _updateWallpaper,
      drawer: MainPageDrawer(
        header: wallpaper?.copyright ?? "A Bing Image",
        onSettingsTap: _openSettingsView,
        onAboutTap: _openAboutView,
        onOldWallpapersTab: _openOldWallpapersView,
      ),
    );
  }
}
