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
  final String baseUrl;
  final String copyright;
  final String copyrightlink;
  final String title;

  String get mobileUrl => "${baseUrl}_${ConfigService.wallpaperResolution}.jpg";

  String get fullSizeUrl => "${baseUrl}_UHD.jpg";

  WallpaperInfo({required this.baseUrl,
    required this.title,
    required this.copyright,
    required this.copyrightlink});
}

class WallpaperService {
  static final _logger = getLogger();

  /// Gets the current wallpaper info
  static Future<WallpaperInfo> getWallpaper(String local) async {
    if (local == "auto") {
      local = (await Devicelocale.currentLocale).toString();
    }

    String url = BASE_URL + local;

    Response response = await get(
        Uri.parse(url), headers: {"Accept": "application/json"});

    var resJson = json.decode(response.body) as Map<String, dynamic>;
    var imageData = resJson["images"][0] as Map<String, dynamic>;

    String baseUrl = "https://bing.com${imageData['urlbase']}";
    String imageTitle = imageData["title"];
    String imageCopyright = imageData["copyright"];
    String imageCopyrightlink = imageData["copyrightlink"];

    return WallpaperInfo(
      baseUrl: baseUrl,
      title: imageTitle,
      copyright: imageCopyright,
      copyrightlink: imageCopyrightlink,
    );
  }

  /// Sets the devices wallpaper from an [url]
  static Future<void> setWallpaperFromUrl(String url, int screen) async {
    String file = await Util.downloadFile(
        url, await ConfigService.publicDirectory, filename: "wallpaper.png");

    // Because setting wallpaper for both screens doesn't work for some reason (tested on Huawei Mate 10 Pro)
    if (screen == WallpaperManagerFlutter.BOTH_SCREENS) {
      WallpaperManagerFlutter().setwallpaperfromFile(
          File(file), WallpaperManagerFlutter.HOME_SCREEN);
      WallpaperManagerFlutter().setwallpaperfromFile(
          File(file), WallpaperManagerFlutter.LOCK_SCREEN);
    } else {
      WallpaperManagerFlutter().setwallpaperfromFile(File(file), screen);
    }


    // await WallpaperManager.setWallpaperFromFile(file, screen);
  }

  /// Stops the background wallpaper update task
  static Future<void> _stopBackgroundTask() async {
    await Workmanager().cancelByTag(consts.BG_WALLPAPER_TASK_ID);
    _logger.d("Stopped background task");
  }

  /// Starts the background wallpaper update task
  static Future<void> _startBackgroundTask() async {
    await Workmanager().registerPeriodicTask(
      consts.BG_WALLPAPER_TASK_ID,
      consts.BG_WALLPAPER_TASK_ID,
      constraints: Constraints(
          networkType: NetworkType.connected
      ),
      frequency: const Duration(hours: consts.BG_TASK_RECURRING_TIME),
      backoffPolicy: BackoffPolicy.linear,
      tag: consts.BG_WALLPAPER_TASK_ID,
    );
    _logger.d("Started background task");
  }

  /// Checks if a background task should run and starts or stops it if necessary
  static Future<void> checkAndSetBackgroundTaskState() async {
    bool enabled = ConfigService.dailyModeEnabled;

    int now = DateTime
        .now()
        .millisecondsSinceEpoch;

    int lastRun = ConfigService.bgWallpaperTaskLastRun;

    // This isn't a reliable method, cause when you disable daily mode for 2h and re-enable it and a
    // bg task is started, and than this methods gets called, it thinks no task is running, but nvm.
    bool taskRunning = (now - lastRun) <
        consts.BG_TASK_RECURRING_TIMEOUT * 60 * 60 * 1000;

    if (!enabled) {
      await _stopBackgroundTask();
      return;
    }

    if (!taskRunning && enabled) {
      await _stopBackgroundTask(); // Just to be safe
      await _startBackgroundTask();
    }
  }


}


