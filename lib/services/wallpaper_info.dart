import 'dart:io';

import 'package:bing_wallpaper_setter/extensions/datetime.dart';
import 'package:bing_wallpaper_setter/util/log.dart';

import '../util/util.dart';
import 'config_service.dart';

final _logger = getLogger();

class WallpaperInfo {
  final String _bingEndpoint = "https://bing.com";

  final String urlBase;
  final String copyright;
  final String copyrightLink;
  final String title;
  final String hsh;
  final String resolution;
  final DateTime day;

  String get repr => "${day.formatted} @ $resolution (file=${file.path})";

  String get mobileUrl => "$_bingEndpoint${urlBase}_$resolution.jpg";

  String get fullSizeUrl => "$_bingEndpoint${urlBase}_UHD.jpg";

  String get id => "${day.formatted}_${hsh}_$resolution";

  String get formattedFileName => "${title.replaceAll(" ", "_")}_${day.formatted}_$resolution";

  /// The file where the wallpaper image is saved on the device
  File get file => _getFile();

  Future<bool> get isDownloaded async => file.exists();

  WallpaperInfo({
    this.urlBase = "",
    this.title = "",
    this.copyright = "",
    this.copyrightLink = "",
    required this.day,
    required this.hsh,
    required this.resolution,
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

  File _getFile() {
    var dir = ConfigService.wallpaperCacheDir;
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
