import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bing_wallpaper_setter/consts.dart';
import 'package:bing_wallpaper_setter/extensions/file.dart';
import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:collection/collection.dart';

import '../consts.dart' as consts;
import '../util/util.dart';

// DateTime _dayFromString(String day){
//
// }

String _toFormattedWallpaperName(DateTime day) {
  return "wallpaper_${Util.formatDay(day)}.jpg";
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

  Future<bool> get isDownloaded async => (await file).exists();

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
  static const _maxWallpapers = 50;
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
    if (await wallpaperInfo.isDownloaded) {
      _logger.d("${wallpaperInfo.mobileUrl} already downloaded");
      return;
    }
    _logger.d("Downloading ${wallpaperInfo.mobileUrl}");
    await Util.downloadFile(
        wallpaperInfo.mobileUrl, await ConfigService.wallpaperCacheDir,
        filename: _toFormattedWallpaperName(wallpaperInfo.day));
  }

  /// Gets a list of wallpapers from bing where [n] is the number of wp to fetch
  static Future<List<WallpaperInfo>> getWallpapersFromBing(
      {String? local, int n = 1, DateTime? startDate}) async {
    startDate ??= DateTime.now();
    startDate = Util.normalizeDate(startDate);
    local ??= ConfigService.region;
    var now = Util.normalizeDate(DateTime.now());
    List<WallpaperInfo> images = [];

    var idx = startDate.difference(now).inDays;

    List<DateTime> usedDays = [];

    while (n > 0) {
      String url = "$BASE_URL$local&n=${min(8, n)}&idx=$idx";

      _logger.d("Requesting $url");

      Response response =
          await get(Uri.parse(url), headers: {"Accept": "application/json"});

      var resJson = json.decode(response.body) as Map<String, dynamic>;
      List rawImages = resJson["images"] as List;

      DateTime? lastDay;

      int newWallpapers = 0;
      for (var data in rawImages) {
        lastDay = DateTime.parse(data["enddate"]);

        if (usedDays.contains(lastDay)) {
          continue;
        }

        images.add(WallpaperInfo(
            urlBase: data["urlbase"],
            title: data["title"],
            copyright: data["copyright"],
            copyrightLink: data["copyrightlink"],
            day: lastDay));
        usedDays.add(lastDay);
        newWallpapers++;
      }

      if (newWallpapers <= 0) {
        // This means we're getting repeated results, so stop fetching more
        break;
      }

      n -= 8;
      idx += 9;
    }

    return images;
  }

  /// Gets the current wallpaper info
  static Future<WallpaperInfo> getWallpaper({String? local}) async {
    return (await getWallpapersFromBing(local: local, n: 1)).first;
  }

  /// Sets the devices wallpaper from an [url]
  static Future<void> setWallpaper(WallpaperInfo wallpaper, int screen) async {
    await ensureDownloaded(wallpaper);

    File file = await wallpaper.file;

    // Because setting wallpaper for both screens doesn't work for some reason (tested on Huawei Mate 10 Pro)
    if (screen == WallpaperManagerFlutter.BOTH_SCREENS) {
      WallpaperManagerFlutter()
          .setwallpaperfromFile(file, WallpaperManagerFlutter.HOME_SCREEN);
      WallpaperManagerFlutter()
          .setwallpaperfromFile(file, WallpaperManagerFlutter.LOCK_SCREEN);
    } else {
      WallpaperManagerFlutter().setwallpaperfromFile(file, screen);
    }

    ConfigService.currentWallpaperDay = Util.formatDay(wallpaper.day);

    var newest = ConfigService.newestWallpaperDay;
    var newestDate = DateTime.tryParse(newest) ?? DateTime(1800);
    newestDate = Util.normalizeDate(newestDate);
    var current = Util.normalizeDate(wallpaper.day);

    if (current.millisecondsSinceEpoch > newestDate.millisecondsSinceEpoch) {
      ConfigService.newestWallpaperDay = Util.formatDay(current);
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
      // constraints: Constraints(networkType: NetworkType.connected),
      frequency: const Duration(hours: consts.BG_TASK_RECURRING_TIME),
      backoffPolicy: BackoffPolicy.linear,
      tag: consts.BG_WALLPAPER_TASK_ID,
    );
    _logger.d("Started background task");
  }

  /// Checks if a background task should run and starts or stops it if necessary
  static Future<void> checkAndSetBackgroundTaskState() async {
    bool enabled = ConfigService.dailyModeEnabled;

    await _stopBackgroundTask();
    if (enabled) {
      // await _stopBackgroundTask();
      await _startBackgroundTask();
    }
  }

  /// Checks if todays wallpaper is downloaded and if so returns its wallpaper info (with about blank)
  static Future<WallpaperInfo?> getTodaysWallpaperOffline() async {
    var now = DateTime.now();
    var file = await _getWallpaperFile(now);
    if (await file.exists()) {
      return WallpaperInfo(
          urlBase: "", title: "", copyright: "", copyrightLink: "", day: now);
    }
    return null;
  }

  /// Returns a list of WallpaperInfo's with the downloaded (on-device) wallpapers
  static Future<List<WallpaperInfo>> _getOfflineWallpapers() async {
    var dir = await ConfigService.wallpaperCacheDir;
    var existing = Util.listDir(dir);
    var dates = existing
        .map((e) => e.date)
        .whereType<String>()
        .map((e) => DateTime.tryParse(e))
        .whereNotNull()
        .toList();
    dates.sort((a, b) => b.compareTo(a)); // descending order
    return dates
        .map((date) => WallpaperInfo(
            urlBase: "",
            title: "",
            copyright: "",
            copyrightLink: "",
            day: date))
        .toList();
  }

  /// Tries to set the wallpaper from a given day
  static Future<void> setWallpaperOfDay(DateTime day) async {
    day = Util.normalizeDate(day);
    var now = Util.normalizeDate(DateTime.now());
    List<WallpaperInfo?> offlineWallpapers = await _getOfflineWallpapers();

    WallpaperInfo? wallpaper = offlineWallpapers.firstWhereOrNull((wp) => wp?.day==day);

    if(wallpaper == null){
      var pastDays = now.difference(day).inDays + 1;
      List<WallpaperInfo?> wallpapers = await getWallpapersFromBing(n: pastDays);
      wallpaper = wallpapers.firstWhereOrNull((w) => w?.day == day);
    }else{
      _logger.d("Found image for ${Util.formatDay(day)} on the device, using it.");
    }

    if(wallpaper == null){
      _logger.v("Couldn't get matching wallpaper for day ${Util.formatDay(day)}");
      return;
    }
    await setWallpaper(wallpaper, ConfigService.wallpaperScreen);
  }

  /// Tries to update the wallpaper to the newest one. Fails if there is no connection and todays wallpaper isn't downloaded
  static Future<void> tryUpdateWallpaper() async {
    var logger = getLogger();

    WallpaperInfo? todaysWallpaper =
    await WallpaperService.getTodaysWallpaperOffline();
    var connectivity = await Connectivity().checkConnectivity();

    if(todaysWallpaper == null){
      if (![
        ConnectivityResult.mobile,
        ConnectivityResult.wifi,
        ConnectivityResult.ethernet
      ].contains(connectivity)) {
        logger.d("No internet connection. Skipping...");
        return;
      }

      todaysWallpaper = await WallpaperService.getWallpaper();
      await WallpaperService.ensureDownloaded(todaysWallpaper);
    }else{
      logger.d("Using cached wallpaper today");
    }

    await WallpaperService.setWallpaper(todaysWallpaper, ConfigService.wallpaperScreen);

    logger.d("Wallpaper updated!");
  }

  /// Update the wallpaper. If todays wallpaper was never applied, it will be, else the day before current will be used
  static Future<void> updateWallpaperOnWidgetIntent() async{
    var now = Util.normalizeDate(DateTime.now());
    var currentWallpaperDay =
        DateTime.tryParse(ConfigService.currentWallpaperDay) ?? DateTime(1800);
    var newestWallpaperDay =
        DateTime.tryParse(ConfigService.newestWallpaperDay) ?? DateTime(1800);

    if (now.millisecondsSinceEpoch >
        newestWallpaperDay.millisecondsSinceEpoch) {
      // The newest wallpaper was never applied yet -> update
      _logger.d("Trying to update to newest wallpaper");
      await tryUpdateWallpaper();
    } else {
      _logger.d("Current wallpaper: ${Util.formatDay(currentWallpaperDay)}");
      var theDayBeforeCurrent =
      currentWallpaperDay.subtract(const Duration(days: 1));
      await setWallpaperOfDay(theDayBeforeCurrent);

      _logger.d("Set wallpaper for day $theDayBeforeCurrent");
    }
  }
}
