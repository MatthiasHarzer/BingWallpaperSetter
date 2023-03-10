import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bing_wallpaper_setter/consts.dart';
import 'package:bing_wallpaper_setter/extensions/datetime.dart';
import 'package:bing_wallpaper_setter/extensions/file.dart';
import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:bing_wallpaper_setter/services/wallpaper_info.dart';
import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:http/http.dart';

import '../consts.dart' as consts;
import '../exeptions/wallpaper_out_of_date_exception.dart';
import '../util/log.dart';
import '../util/util.dart';

final _logger = getLogger();

class WallpaperService {
  static const platform =
      MethodChannel('dev.taptwice.bing_wallpaper_app/pictures');
  static const _maxWallpapers = 50;

  /// Deletes old wallpapers
  static void ensureMaxCacheWallpapers() async {
    var dir = ConfigService.wallpaperCacheDir;

    var existing = await Util.listDir(dir, regExp: consts.WALLPAPER_REGEX);

    if (existing.length < _maxWallpapers) return;

    var walls = existing
        .where((f) => f.date != null && f.hsh != null)
        .map((f) =>
            WallpaperInfo(day: f.date!, hsh: f.hsh!, resolution: f.resolution!))
        .toList();
    walls.sort((a, b) => b.day.compareTo(a.day)); // descending order

    int len = walls.length;
    for (var wall in walls) {
      if (len < _maxWallpapers) {
        break;
      }
      var file = wall.file;

      if (file.existsSync()) {
        file.delete();
      }

      len--;
    }
  }

  ///Saves the given [wallpaper] to the gallery on the device
  static Future<bool> saveToGallery(WallpaperInfo wallpaper) async {
    await wallpaper.ensureDownloaded();
    File file = wallpaper.file;

    // _logger.d("Saving ${file.name} to gallery");

    var directory = ConfigService.galleryDir;
    await directory.create();

    File? galleryFile = await Util.copyFile(from: file, to: directory);

    bool success = galleryFile != null;

    if (success) {
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
    day = day.normalized;
    var now = DateTime.now().normalized;

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
    if (local == "auto") {
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
        hsh: data["hsh"],
        resolution: ConfigService.wallpaperResolution));
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
    _logger.d("Fetching latest wallpaper from bing");
    return (await _getWallpapersFromBing(n: 1, local: local, idx: 0)).first;
  }

  /// Sets the devices wallpaper
  static Future<void> setWallpaper(WallpaperInfo wallpaper, int screen) async {
    await wallpaper.ensureDownloaded();

    File file = wallpaper.file;

    _logger.i("W1 Updating wallpaper to ${wallpaper.repr} on screen = $screen");

    // Because setting wallpaper for both screens doesn't work for some reason (tested on Huawei Mate 10 Pro)

    if (screen == WallpaperManager.BOTH_SCREEN) {
      await Future.wait([
        WallpaperManager.setWallpaperFromFile(
            file.path, WallpaperManager.HOME_SCREEN),
        WallpaperManager.setWallpaperFromFile(
            file.path, WallpaperManager.LOCK_SCREEN)
      ]);
    } else {
      await WallpaperManager.setWallpaperFromFile(file.path, screen);
    }

    ConfigService.currentWallpaperDay = wallpaper.day.formatted;

    var newest = ConfigService.newestWallpaperDay;
    var newestDate = DateTime.tryParse(newest) ?? DateTime(1800);
    newestDate = newestDate.normalized;
    var current = wallpaper.day.normalized;

    if (current.millisecondsSinceEpoch > newestDate.millisecondsSinceEpoch) {
      ConfigService.newestWallpaperDay = current.formatted;
    }

    if (ConfigService.saveWallpaperToGallery) {
      await saveToGallery(wallpaper);
    }

    _logger.d("W2 Wallpaper updated!");

    // await WallpaperManager.setWallpaperFromFile(file, screen);
  }

  /// Returns a list of WallpaperInfo's with the downloaded (on-device) wallpapers.
  /// Takes wallpaper resolution into account and returning only wallpaper which match the [ConfigService.wallpaperResolution]
  static Future<List<WallpaperInfo>> _getOfflineWallpapers() async {
    var dir = ConfigService.wallpaperCacheDir;
    var existing = await Util.listDir(dir);
    var walls = existing
        .where((f) =>
            f.date != null &&
            f.hsh != null &&
            f.resolution == ConfigService.wallpaperResolution)
        .map((f) =>
            WallpaperInfo(day: f.date!, hsh: f.hsh!, resolution: f.resolution!))
        .toList();
    walls.sort((a, b) => b.day.compareTo(a.day)); // descending order
    return walls;
  }

  /// Tries to set the wallpaper from a given day
  static Future<void> setWallpaperOf({required DateTime day}) async {
    day = day.normalized;

    List<WallpaperInfo?> offlineWallpapers = await _getOfflineWallpapers();
    WallpaperInfo? wallpaper =
        offlineWallpapers.firstWhereOrNull((wp) => wp?.day == day);

    if (wallpaper == null) {
      wallpaper = await getWallpaperFromBingByDay(day);
    } else {
      _logger.d("Found image for ${day.formatted} on the device, using it.");
    }

    if (wallpaper == null) {
      _logger.e("Couldn't get matching wallpaper for day ${day.formatted}");
      return;
    }
    await setWallpaper(wallpaper, ConfigService.wallpaperScreen);
  }

  /// Tries to update the wallpaper to the newest one. Fails if there is no connection and todays wallpaper isn't downloaded
  static Future<void> _tryUpdateWallpaper() async {
    var nowNormalized = DateTime.now().normalized;
    WallpaperInfo? todaysWallpaper =
        (await WallpaperService._getOfflineWallpapers()).firstWhereOrNull((w) =>
            w.day == nowNormalized &&
            w.resolution == ConfigService.wallpaperResolution);

    _logger
        .i("Trying to update to newest wallpaper (${nowNormalized.formatted})");
    // _logger.d("Checking for wallpaper of day ${nowNormalized.formatted}");

    if (todaysWallpaper == null) {
      var connectivity = await Connectivity().checkConnectivity();
      if (![
        ConnectivityResult.mobile,
        ConnectivityResult.wifi,
        ConnectivityResult.ethernet
      ].contains(connectivity)) {
        _logger.i("No internet connection. Skipping...");
        return;
      }
      todaysWallpaper = await getLatestWallpaper();
      await todaysWallpaper.ensureDownloaded();
    } else {
      _logger.d("Using offline wallpaper");
    }

    await setWallpaper(todaysWallpaper, ConfigService.wallpaperScreen);
  }

  /// Update the wallpaper. If todays wallpaper was never applied, it will be, else the day before current will be used
  static Future<void> updateWallpaperOnWidgetIntent() async {
    var now = DateTime.now().normalized;
    var currentWallpaperDay =
        DateTime.tryParse(ConfigService.currentWallpaperDay) ?? DateTime(1800);
    var newestWallpaperDay =
        DateTime.tryParse(ConfigService.newestWallpaperDay) ?? DateTime(1800);

    if (now.millisecondsSinceEpoch >
        newestWallpaperDay.millisecondsSinceEpoch) {
      // The newest wallpaper was never applied yet -> update
      _logger.i("Trying to update to newest wallpaper");
      await _tryUpdateWallpaper();
    } else {
      _logger.d("Current wallpaper: ${currentWallpaperDay.formatted}");
      var theDayBeforeCurrent =
          currentWallpaperDay.subtract(const Duration(days: 1));

      try {
        _logger.d("Setting wallpaper for day ${theDayBeforeCurrent.formatted}");
        await setWallpaperOf(day: theDayBeforeCurrent);
      } on WallpaperOutOfDateException catch (e) {
        _logger.e(e.toString());
        await _tryUpdateWallpaper();
      } catch (e) {
        _logger.e("An error occurred: $e");
      }
    }
  }

  /// Updates the wallpaper to the newest, if it was never applied. Else nothing
  static Future<void> updateWallpaperOnBackgroundTaskIntent() async {
    var today = DateTime.now().normalized;
    var newestWallpaperDay =
        DateTime.tryParse(ConfigService.newestWallpaperDay) ?? DateTime(1800);

    if (newestWallpaperDay == today) {
      // Newest wallpaper was applied today -> don't update wallpaper
      _logger.d("Newest wallpaper has already been set today -> skipping....");
      return;
    }

    // update the wallpaper to the newest one
    await _tryUpdateWallpaper();
  }
}
