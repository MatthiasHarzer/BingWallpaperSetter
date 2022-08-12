import 'dart:convert';
import 'dart:io';

import 'package:bing_wallpaper_setter/consts.dart';
import 'package:bing_wallpaper_setter/extensions/file.dart';
import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:devicelocale/devicelocale.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../consts.dart' as consts;
import '../util/util.dart';

String _toFormattedWallpaperName(DateTime day) {
  final DateFormat formatter = DateFormat('yyyy-MM-dd');
  return "wallpaper_${formatter.format(day)}.jpg";
}

/// Returns the wallpaper save file
Future<File> _getWallpaperFile(DateTime day) async {
  var dir = await ConfigService.wallpaperCacheDir;
  String name = _toFormattedWallpaperName(day);
  return File("${dir.path}/$name");
}

class WallpaperInfo {
  final String _bingEndpoint = "https://bing.com";

  final String urlBase;
  final String copyright;
  final String copyrightLink;
  final String title;
  final DateTime day;

  String get mobileUrl =>
      "$_bingEndpoint${urlBase}_${ConfigService.wallpaperResolution}.jpg";

  String get fullSizeUrl => "$_bingEndpoint${urlBase}_UHD.jpg";

  String get id => urlBase;

  /// The file where the wallpaper image is saved on the device
  Future<File> get file => _getWallpaperFile(day);

  WallpaperInfo(
      {required this.urlBase,
      required this.title,
      required this.copyright,
      required this.copyrightLink,
      required this.day});

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

  @override
  String toString() {
    return "WallpaperInfo(id=$id, title=$title, mobileUrl=$mobileUrl)";
  }
}

class WallpaperService {
  static const _maxWallpapers = 10;
  static final _logger = getLogger();

  /// Deletes old wallpapers
  static Future<void> ensureMaxCacheWallpapers() async {
    var dir = await ConfigService.wallpaperCacheDir;

    var existing = Util.listDir(dir, regExp: consts.WALLPAPER_REGEX);

    if (existing.length < _maxWallpapers) return;

    var dates = existing
        .map((e) => e.date)
        .whereType<String>()
        .map((e) => DateTime.parse(e))
        .toList();
    dates.sort((a, b) => b.compareTo(a)); // descending order

    int len = dates.length;
    for (var date in dates) {
      if (len < _maxWallpapers) {
        break;
      }
      var file = await _getWallpaperFile(date);

      if (file.existsSync()) {
        file.delete();
      }

      len--;
    }
  }

  /// Ensures the given wallpaper is downloaded to the device
  static Future<void> ensureDownloaded(WallpaperInfo wallpaperInfo) async {
    if ((await wallpaperInfo.file).existsSync()) {
      _logger.d("${wallpaperInfo.mobileUrl} already downloaded");
      return;
    }
    _logger.d("Downloading ${wallpaperInfo.mobileUrl}");
      await Util.downloadFile(
          wallpaperInfo.mobileUrl, await ConfigService.wallpaperCacheDir,
          filename: _toFormattedWallpaperName(wallpaperInfo.day));

  }

  /// Gets the current wallpaper info
  static Future<WallpaperInfo> getWallpaper({String local = "auto"}) async {
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
      day: DateTime.now(),
    );
  }

  /// Sets the devices wallpaper from an [url]
  static Future<void> setWallpaper(WallpaperInfo wallpaper, int screen) async {
    await ensureDownloaded(wallpaper);

    File file = await wallpaper.file;

    // Because setting wallpaper for both screens doesn't work for some reason (tested on Huawei Mate 10 Pro)
    if (screen == WallpaperManagerFlutter.BOTH_SCREENS) {
      WallpaperManagerFlutter().setwallpaperfromFile(
          file, WallpaperManagerFlutter.HOME_SCREEN);
      WallpaperManagerFlutter().setwallpaperfromFile(
          file, WallpaperManagerFlutter.LOCK_SCREEN);
    } else {
      WallpaperManagerFlutter().setwallpaperfromFile(file, screen);
    }

    ConfigService.currentWallpaperId = wallpaper.id;

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
      constraints: Constraints(networkType: NetworkType.connected),
      frequency: const Duration(hours: consts.BG_TASK_RECURRING_TIME),
      backoffPolicy: BackoffPolicy.linear,
      tag: consts.BG_WALLPAPER_TASK_ID,
    );
    _logger.d("Started background task");
  }

  /// Checks if a background task should run and starts or stops it if necessary
  static Future<void> checkAndSetBackgroundTaskState() async {
    bool enabled = ConfigService.dailyModeEnabled;

    int now = DateTime.now().millisecondsSinceEpoch;

    int lastRun = ConfigService.bgWallpaperTaskLastRun;

    await _stopBackgroundTask();
    if (enabled) {
      // await _stopBackgroundTask();
      await _startBackgroundTask();
    }
  }
}
