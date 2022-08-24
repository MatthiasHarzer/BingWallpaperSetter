import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bing_wallpaper_setter/consts.dart';
import 'package:bing_wallpaper_setter/extensions/file.dart';
import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../consts.dart' as consts;
import '../util/util.dart';

/// An exception when the given day is too far in the past and can't be fetched by the bing api.
class WallpaperOutOfDateException implements Exception {
  late DateTime day;

  WallpaperOutOfDateException(this.day);

  @override
  String toString() {
    return "${Util.formatDay(day)} is too far in the past and can't be fetched.";
  }
}
final _logger = getLogger();

class WallpaperInfo {

  final String _bingEndpoint = "https://bing.com";

  final String urlBase;
  final String copyright;
  final String copyrightLink;
  final String title;
  final String hsh;
  final DateTime day;

  String get repr => "${Util.formatDay(day)} @ ${ConfigService.wallpaperResolution} (hsh=$hsh)";

  String get mobileUrl =>
      "$_bingEndpoint${urlBase}_${ConfigService.wallpaperResolution}.jpg";

  String get fullSizeUrl => "$_bingEndpoint${urlBase}_UHD.jpg";

  String get id =>
      "${Util.formatDay(day)}_${hsh}_${ConfigService.wallpaperResolution}";


  /// The file where the wallpaper image is saved on the device
  Future<File> get file => _getFile();

  Future<bool> get isDownloaded async => (await file).exists();

  WallpaperInfo({
    this.urlBase = "" ,
    this.title = "",
    this.copyright = "",
    this.copyrightLink = "",
    required this.day,
    required this.hsh,
  });



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

  Future<File> _getFile() async {
    var dir = await ConfigService.wallpaperCacheDir;
    String name = "wallpaper_$id.jpg";
    return File("${dir.path}/$name");
  }

  /// Checks if the wallpaper is downloaded and downloads it if necessary
  Future<void> ensureDownloaded() async {
    if (await isDownloaded) {
      _logger.d("$mobileUrl already downloaded");
      return;
    }
    _logger.i("Downloading $mobileUrl");
    await Util.downloadWallpaper(this);
  }
}

class WallpaperService {
  static const platform = MethodChannel('dev.taptwice.bing_wallpaper_app/pictures');
  static const _maxWallpapers = 50;


  /// Deletes old wallpapers
  static Future<void> ensureMaxCacheWallpapers() async {
    var dir = await ConfigService.wallpaperCacheDir;

    var existing = Util.listDir(dir, regExp: consts.WALLPAPER_REGEX);

    if (existing.length < _maxWallpapers) return;

    var walls = existing
        .where((f) => f.date != null && f.hsh != null)
        .map((f) => WallpaperInfo(day: f.date!, hsh: f.hsh!))
        .toList();
    walls.sort((a, b) => b.day.compareTo(a.day)); // descending order

    int len = walls.length;
    for (var wall in walls) {
      if (len < _maxWallpapers) {
        break;
      }
      var file = await wall.file;

      if (file.existsSync()) {
        file.delete();
      }

      len--;
    }
  }

  ///Saves the given [wallpaper] to the gallery on the device
  static Future<bool> saveToGallery(WallpaperInfo wallpaper)async{
    await wallpaper.ensureDownloaded();
    File file = await wallpaper.file;

    // _logger.d("Saving ${file.name} to gallery");

    var directory = ConfigService.galleryDir;
    await directory.create();

    File? galleryFile = await Util.copyFile(from: await wallpaper.file, to: directory);

    bool success = galleryFile != null;

    if(success){
      _logger.i("Saved ${file.name} to gallery ${directory.path}");

      DateTime day = wallpaper.day.add(const Duration(hours: 6));
      await galleryFile.setLastModified(day);
    }
    return success;
  }


  /// Gets a wallpaper for the given [day]. Returns [null] if the wallpaper couldn't be fetched.
  /// Throws a [WallpaperOutOfDateException] when the day is too far in the past.
  static Future<WallpaperInfo?> getWallpaperFromBingByDay(DateTime day,
      {String? local}) async {
    local ??= ConfigService.region;
    day = Util.normalizeDate(day);
    var now = Util.normalizeDate(DateTime.now());

    int diff = now.difference(day).inDays.abs();

    // _logger.d("Difference $diff");

    if ((diff + 1) >= WALLPAPER_HISTORY_LIMIT) {
      throw WallpaperOutOfDateException(day);
    }
    return (await _getWallpapersFromBing(local: local, n: 8, idx: min(8, diff)))
        .firstWhereOrNull((w) => w.day == day);
  }

  /// Makes a signle request to the bing endpoint an returns the fetched wallpapers.
  static Future<Iterable<WallpaperInfo>> _getWallpapersFromBing(
      {required String local, required int n, int idx = 0}) async {
    if(local == "auto"){
      local = ConfigService.autoRegionLocale;
    }
    String url = "$BASE_URL&mkt=$local&n=$n&idx=$idx";
    _logger.d("Requesting $url");
    late Response response;
    try {
      response =
          await get(Uri.parse(url), headers: {"Accept": "application/json"});
    } catch (e) {
      _logger.e(e.toString());
      return List.empty();
    }

    var resJson = json.decode(response.body) as Map<String, dynamic>;
    List rawImages = resJson["images"] as List;

    return rawImages.map((data) => WallpaperInfo(
        urlBase: data["urlbase"],
        title: data["title"],
        copyright: data["copyright"],
        copyrightLink: data["copyrightlink"],
        day: DateTime.parse(data["enddate"]),
        hsh: data["hsh"]));
  }

  /// Returns as much wallpapers as possible
  static Future<List<WallpaperInfo>> getWallpaperHistory() async {
    List<WallpaperInfo> wallpapers = [];

    const int step = 8;

    for (int idx = 0; idx < WALLPAPER_HISTORY_LIMIT; idx += step) {
      var walls = await _getWallpapersFromBing(
          local: ConfigService.region, n: step, idx: idx);
      wallpapers.addAll(walls);
    }

    return wallpapers.toSet().toList(); // Remove duplicates
  }

  /// Gets the current wallpaper info
  static Future<WallpaperInfo> getLatestWallpaper({String? local}) async {
    local ??= ConfigService.region;
    return (await _getWallpapersFromBing(n: 1, local: local, idx: 0)).first;
  }

  /// Sets the devices wallpaper
  static Future<void> setWallpaper(WallpaperInfo wallpaper, int screen) async {
    await wallpaper.ensureDownloaded();

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

    if(ConfigService.saveWallpaperToGallery){
      await saveToGallery(wallpaper);
    }

    // await WallpaperManager.setWallpaperFromFile(file, screen);
  }

  /// Stops the background wallpaper update task
  static Future<void> _stopBackgroundTask() async {
    await Workmanager().cancelByTag(consts.BG_WALLPAPER_TASK_ID);
    _logger.i("Stopped background task");
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
    _logger.i("Started background task");
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

  /// Returns a list of WallpaperInfo's with the downloaded (on-device) wallpapers
  static Future<List<WallpaperInfo>> _getOfflineWallpapers() async {
    var dir = await ConfigService.wallpaperCacheDir;
    var existing = Util.listDir(dir);
    var walls = existing
        .where((f) => f.date != null && f.hsh != null)
        .map((f) => WallpaperInfo(day: f.date!, hsh: f.hsh!))
        .toList();
    walls.sort((a, b) => b.day.compareTo(a.day)); // descending order
    return walls;
  }

  /// Tries to set the wallpaper from a given day
  static Future<void> setWallpaperOf({required DateTime day}) async {
    day = Util.normalizeDate(day);

    List<WallpaperInfo?> offlineWallpapers = await _getOfflineWallpapers();
    WallpaperInfo? wallpaper =
        offlineWallpapers.firstWhereOrNull((wp) => wp?.day == day);

    if (wallpaper == null) {
      wallpaper = await getWallpaperFromBingByDay(day);
    } else {
      _logger
          .d("Found image for ${Util.formatDay(day)} on the device, using it.");
    }

    if (wallpaper == null) {
      _logger
          .e("Couldn't get matching wallpaper for day ${Util.formatDay(day)}");
      return;
    }
    await setWallpaper(wallpaper, ConfigService.wallpaperScreen);
  }

  /// Tries to update the wallpaper to the newest one. Fails if there is no connection and todays wallpaper isn't downloaded
  static Future<void> tryUpdateWallpaper() async {
    var logger = getLogger();

    WallpaperInfo? todaysWallpaper =
        (await WallpaperService._getOfflineWallpapers()).firstWhereOrNull(
            (w) => w.day == Util.normalizeDate(DateTime.now()));

    var connectivity = await Connectivity().checkConnectivity();

    if (todaysWallpaper == null) {
      if (![
        ConnectivityResult.mobile,
        ConnectivityResult.wifi,
        ConnectivityResult.ethernet
      ].contains(connectivity)) {
        logger.d("No internet connection. Skipping...");
        return;
      }

      todaysWallpaper = await WallpaperService.getLatestWallpaper();
      await todaysWallpaper.ensureDownloaded();
    } else {
      logger.d("Using cached wallpaper today");
    }

    await WallpaperService.setWallpaper(
        todaysWallpaper, ConfigService.wallpaperScreen);

    logger.d("Wallpaper updated!");
  }

  /// Update the wallpaper. If todays wallpaper was never applied, it will be, else the day before current will be used
  static Future<void> updateWallpaperOnWidgetIntent() async {
    var now = Util.normalizeDate(DateTime.now());
    var currentWallpaperDay =
        DateTime.tryParse(ConfigService.currentWallpaperDay) ?? DateTime(1800);
    var newestWallpaperDay =
        DateTime.tryParse(ConfigService.newestWallpaperDay) ?? DateTime(1800);

    if (now.millisecondsSinceEpoch >
        newestWallpaperDay.millisecondsSinceEpoch) {
      // The newest wallpaper was never applied yet -> update
      _logger.i("Trying to update to newest wallpaper");
      await tryUpdateWallpaper();
    } else {
      _logger.d("Current wallpaper: ${Util.formatDay(currentWallpaperDay)}");
      var theDayBeforeCurrent =
          currentWallpaperDay.subtract(const Duration(days: 1));

      try {
        _logger.d("Setting wallpaper for day ${Util.formatDay(theDayBeforeCurrent)}");
        await setWallpaperOf(day: theDayBeforeCurrent);
      } on WallpaperOutOfDateException catch (e) {
        _logger.e(e.toString());
        await tryUpdateWallpaper();
      }catch(e){
        _logger.e("An error occurred: $e");
      }
    }
  }
}
