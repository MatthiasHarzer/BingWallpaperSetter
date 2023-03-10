import 'package:bing_wallpaper_setter/extensions/datetime.dart';

/// An exception when the given day is too far in the past and can't be fetched by the bing api.
class WallpaperOutOfDateException implements Exception {
  late DateTime day;

  WallpaperOutOfDateException(this.day);

  @override
  String toString() {
    return "${day.formatted} is too far in the past and can't be fetched.";
  }
}
