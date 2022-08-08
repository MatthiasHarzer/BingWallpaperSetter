import 'dart:convert';
import 'dart:io';

import 'package:bing_wallpaper_setter/consts.dart';
import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:devicelocale/devicelocale.dart';
import 'package:http/http.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../consts.dart' as consts;
import '../util/util.dart';

class WallpaperInfo {
  final String _bingEndpoint = "https//bing.com";

  final String urlBase;
  final String copyright;
  final String copyrightLink;
  final String title;

  String get mobileUrl =>
      "$_bingEndpoint${urlBase}_${ConfigService.wallpaperResolution}.jpg";

  String get fullSizeUrl => "$_bingEndpoint${urlBase}_UHD.jpg";

  String get id => urlBase;

  WallpaperInfo(
      {required this.urlBase,
      required this.title,
      required this.copyright,
      required this.copyrightLink});

  @override
  bool operator ==(other) {
    if (other is! WallpaperInfo) {
      return false;
    }
    return id == other.id;
  }

  int? _hashCode;

  @override
  int get hashCode {
    _hashCode ??= id.hashCode;
    return _hashCode!;
  }
}

class WallpaperService {
  static final _logger = getLogger();

  /// Gets the current wallpaper info
  static Future<WallpaperInfo> getWallpaper(String local) async {
    if (local == "auto") {
      local = (await Devicelocale.currentLocale).toString();
    }

    String url = BASE_URL + local;

    Response response =
        await get(Uri.parse(url), headers: {"Accept": "application/json"});

    var resJson = json.decode(response.body) as Map<String, dynamic>;
    var imageData = resJson["images"][0] as Map<String, dynamic>;

    String urlBase = imageData['urlbase'];
    String imageTitle = imageData["title"];
    String imageCopyright = imageData["copyright"];
    String imageCopyrightlink = imageData["copyrightlink"];

    return WallpaperInfo(
      urlBase: urlBase,
      title: imageTitle,
      copyright: imageCopyright,
      copyrightLink: imageCopyrightlink,
    );
  }

  /// Sets the devices wallpaper from an [url]
  static Future<void> setWallpaper(WallpaperInfo wallpaper, int screen) async {
    String url = wallpaper.mobileUrl;

    String file = await Util.downloadFile(
        url, await ConfigService.publicDirectory,
        filename: "wallpaper.png");

    // Because setting wallpaper for both screens doesn't work for some reason (tested on Huawei Mate 10 Pro)
    if (screen == WallpaperManagerFlutter.BOTH_SCREENS) {
      WallpaperManagerFlutter().setwallpaperfromFile(
          File(file), WallpaperManagerFlutter.HOME_SCREEN);
      WallpaperManagerFlutter().setwallpaperfromFile(
          File(file), WallpaperManagerFlutter.LOCK_SCREEN);
    } else {
      WallpaperManagerFlutter().setwallpaperfromFile(File(file), screen);
    }

    ConfigService.currentWallpaperId = wallpaper.id;

    // await WallpaperManager.setWallpaperFromFile(file, screen);
  }

  /// Stops the background wallpaper update task
  static Future<void> _stopBackgroundTask() async {
    await Workmanager().cancelByTag(consts.BG_WALLPAPER_TASK_ID);
    _logger.d("Stopped background task");
    Util.logToFile("Stopped background task");
  }

  /// Starts the background wallpaper update task
  static Future<void> _startBackgroundTask() async {
    await Workmanager().registerPeriodicTask(
      consts.BG_WALLPAPER_TASK_ID,
      consts.BG_WALLPAPER_TASK_ID,
      constraints: Constraints(networkType: NetworkType.connected),
      frequency: const Duration(hours: consts.BG_TASK_RECURRING_TIME),
      backoffPolicy: BackoffPolicy.linear,
      tag: consts.BG_WALLPAPER_TASK_ID,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    _logger.d("Started background task");
    Util.logToFile("Started background task");
  }

  /// Checks if a background task should run and starts or stops it if necessary
  static Future<void> checkAndSetBackgroundTaskState() async {
    bool enabled = ConfigService.dailyModeEnabled;

    int now = DateTime.now().millisecondsSinceEpoch;

    int lastRun = ConfigService.bgWallpaperTaskLastRun;

    bool taskRunning =
        (now - lastRun) < consts.BG_TASK_RECURRING_TIMEOUT * 60 * 60 * 1000;

    if (!enabled) {
      await _stopBackgroundTask();
      return;
    }

    if (!taskRunning && enabled) {
      await _startBackgroundTask();
    }
  }
}
