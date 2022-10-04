// ignore_for_file: constant_identifier_names

import 'dart:io';

import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:devicelocale/devicelocale.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_android/shared_preferences_android.dart';

const _WALLPAPER_SCREEN = "wallpaper_screen";
const _DAILY_MODE_ENABLED = "daily_mode_enabled";
const _WALLPAPER_RESOLUTION = "wallpaper_resolution";
const _REGION = "region";
const _BG_WALLPAPER_TASK_LAST_RUN = "bg_wallpaper_task_last_run";
const _CURRENT_WALLPAPER_DAY = "current_wallpaper_day";
const _NEWEST_WALLPAPER_DAY = "newest_wallpaper_day";
const _SAVE_WALLPAPER_TO_GALLERY = "save_wallpaper_to_gallery";
const _SHOW_DEBUG_VALUES = "show_debug_values";

/// Provides key-val-storage like functionalities with device storage and configurations
class ConfigService {
  static late SharedPreferences _prefs;

  static late int _wallpaperScreen;
  static late bool _dailyModeEnabled;
  static late String _wallpaperResolution;
  static late String _region;
  static late String _autoRegionLocale;
  static late PackageInfo _packageInfo;
  static late int _bgWallpaperTaskLastRun;
  static late String _currentWallpaperDay;
  static late String _newestWallpaperDay;
  static late bool _saveWallpaperToGallery;
  static late bool _showDebugValues;

  /// A private directory to store data in. Not visible in the filesystem
  static late Directory localDirectory;

  /// A directory to store data, visible in the filesystem. Only available on android.
  /// Falls back to [localDirectory] when on other platforms.
  static late Directory publicDirectory;

  /// The directory to store wallpapers in
  static late Directory wallpaperCacheDir;

  static Future<void> ensureInitialized() async {
    if (Platform.isAndroid) {
      SharedPreferencesAndroid.registerWith();
      PathProviderAndroid.registerWith();
    }

    _prefs = await SharedPreferences.getInstance();
    await _prefs.reload();
    await _load();
  }

  static Future<void> _load() async {
    _wallpaperScreen =
        _prefs.getInt(_WALLPAPER_SCREEN) ?? availableScreens.keys.first;
    _dailyModeEnabled = _prefs.getBool(_DAILY_MODE_ENABLED) ?? false;
    // _dailyModeEnabled = false; // For now
    _wallpaperResolution =
        _prefs.getString(_WALLPAPER_RESOLUTION) ?? availableResolutions.first;
    _region = _prefs.getString(_REGION) ?? availableRegions.keys.first;
    _autoRegionLocale = (await Devicelocale.currentLocale).toString();
    _bgWallpaperTaskLastRun = _prefs.getInt(_BG_WALLPAPER_TASK_LAST_RUN) ?? 0;
    _currentWallpaperDay = _prefs.getString(_CURRENT_WALLPAPER_DAY) ?? "";
    _newestWallpaperDay = _prefs.getString(_NEWEST_WALLPAPER_DAY) ?? "";
    _saveWallpaperToGallery = _prefs.getBool(_SAVE_WALLPAPER_TO_GALLERY) ?? false;
    _showDebugValues = _prefs.getBool(_SHOW_DEBUG_VALUES) ?? false;

    _packageInfo = await PackageInfo.fromPlatform();
    localDirectory = await getApplicationDocumentsDirectory();
    publicDirectory = (await getExternalStorageDirectory())!; // Requires android platform
    wallpaperCacheDir = publicDirectory;
  }

  static Future<void> reload() async{
    await _prefs.reload();
    await _load();
  }


  /// The directory to store wallpaper in gallery
  static Directory get galleryDir {
    return Directory("/storage/emulated/0/Pictures/Bing Wallpapers");
  }

  static PackageInfo get packageInfo => _packageInfo;

  /// Available WallpaperScreens
  static final Map<int, String> availableScreens = {
    AsyncWallpaper.HOME_SCREEN: "Homescreen",
    AsyncWallpaper.LOCK_SCREEN: "Lockscreen",
    AsyncWallpaper.BOTH_SCREENS: "Both"
  };
  // static final Map<int, String> availableScreens = {
  //   WallpaperManagerFlutter.HOME_SCREEN: "Homescreen",
  //   WallpaperManagerFlutter.LOCK_SCREEN: "Lockscreen",
  //   WallpaperManagerFlutter.BOTH_SCREENS: "Both"
  // };

  /// Resolutions for downloading the wallpaper
  static final List<String> availableResolutions = [
    "1920x1080",
    "1080x1920",
    "1280x720",
    "720x1280",
    "800x480",
    "480x800",
    "UHD",
  ];

  static final Map<String, String> availableRegions = {
    "auto": "Auto",
    "en-us": "USA",
    "en-gb": "UK",
    "de-de": "Germany",
    "fr-fr": "France",
    "it-it": "Italy",
    "ja-jp": "Japan",
    "es-es": "Spain",
  };

  /// The screens to apply wallpapers to
  static int get wallpaperScreen => _wallpaperScreen;

  static set wallpaperScreen(int screen) {
    _prefs.setInt(_WALLPAPER_SCREEN, screen);
    _wallpaperScreen = screen;
  }

  /// If set to true, wallpapers should update once a day
  static bool get dailyModeEnabled => _dailyModeEnabled;

  static set dailyModeEnabled(bool enabled) {
    _prefs.setBool(_DAILY_MODE_ENABLED, enabled);
    _dailyModeEnabled = enabled;
  }

  /// The resolution to download the wallpaper in
  static String get wallpaperResolution => _wallpaperResolution;

  static double get wallpaperResolutionAsDouble{
    if(_wallpaperResolution == "UHD") return 16/9;
    final splits = _wallpaperResolution.split("x");
    if(splits.length < 2) return 0;
    return (double.tryParse(splits[0]) ?? 0) / (double.tryParse(splits[1]) ?? 1);
  }

  static set wallpaperResolution(String resolution) {
    _prefs.setString(_WALLPAPER_RESOLUTION, resolution);
    _wallpaperResolution = resolution;
  }

  /// The regions wallpaper locale
  static String get region => _region;

  static set region(String r){
    _prefs.setString(_REGION, r);
    _region = r;
  }

  /// The regions locale defined by the device locale
  static String get autoRegionLocale => _autoRegionLocale;


  /// The day of the last applied wallpaper
  static String get currentWallpaperDay => _currentWallpaperDay;

  static set currentWallpaperDay(String day) {
    _prefs.setString(_CURRENT_WALLPAPER_DAY, day);
    _currentWallpaperDay = day;
  }

  /// The day of the newest ever applied wallpaper
  static String get newestWallpaperDay => _newestWallpaperDay;

  static set newestWallpaperDay(String day) {
    _prefs.setString(_NEWEST_WALLPAPER_DAY, day);
    _newestWallpaperDay = day;
  }

  /// The time in ms when the bg task was executed last
  static int get bgWallpaperTaskLastRun => _bgWallpaperTaskLastRun;

  static set bgWallpaperTaskLastRun(int last) {
    _prefs.setInt(_BG_WALLPAPER_TASK_LAST_RUN, last);
    _bgWallpaperTaskLastRun = last;
  }

  /// Whether to save new wallpapers to the devices gallery or not
  static bool get saveWallpaperToGallery => _saveWallpaperToGallery;

  static set saveWallpaperToGallery(bool enabled) {
    _prefs.setBool(_SAVE_WALLPAPER_TO_GALLERY, enabled);
    _saveWallpaperToGallery = enabled;
  }

  /// Whether to show or hide debug values
  static bool get showDebugValues => _showDebugValues;

  static set showDebugValues(bool enabled) {
    _prefs.setBool(_SHOW_DEBUG_VALUES, enabled);
    _showDebugValues = enabled;
  }
}
