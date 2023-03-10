import 'dart:io';

import 'package:bing_wallpaper_setter/extensions/datetime.dart';
import 'package:bing_wallpaper_setter/extensions/file.dart';
import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:url_launcher/url_launcher.dart' as web;

import '../services/wallpaper_info.dart';
import 'log.dart';

class Util {
  /// Downloads a file from an [url] to a given [directory]. Returns the files path.
  static Future<String> _downloadFile(String url, Directory directory,
      {String filename = "snapshot.png"}) async {
    // WidgetsFlutterBinding.ensureInitialized();

    var httpClient = HttpClient();
    var request = await httpClient.getUrl(Uri.parse(url));
    var response = await request.close();
    var bytes = await consolidateHttpClientResponseBytes(response);
    File file = File('${directory.path}/$filename');

    // print("downloaded to ${file.path}");

    await file.writeAsBytes(bytes);
    return file.uri.path;
  }

  /// Copies a file [from] a file [to] a directory. Returns the new file, or null if an error occurred
  static Future<File?> copyFile(
      {required File from, required Directory to}) async {
    String path = "${to.path}/${from.name}";
    try {
      await from.copy(path);
    } catch (e) {
      getLogger().e("Error copying file ${e.toString()}");
      return null;
    }
    await MediaScanner.loadMedia(path: path);
    return File(path);
  }

  static Future<void> downloadWallpaper(WallpaperInfo wallpaper) async {
    File file = wallpaper.file;
    await _downloadFile(wallpaper.mobileUrl, ConfigService.wallpaperCacheDir,
        filename: file.name);
  }

  /// Opens the given [url] in a browser window.
  static void openUrl(String url) {
    web.launchUrl(Uri.parse(url), mode: web.LaunchMode.externalApplication);
  }

  /// Hides the current snackbar
  static void hideSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Shows a snackbar
  static void showSnackBar(BuildContext context,
      {required Widget content, SnackBarAction? action, int seconds = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        action: action,
        content: content,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  /// Returns a list of files contained in the [directory] matching the [regExp]
  static Future<List<FileSystemEntity>> listDir(Directory directory,
      {RegExp? regExp}) async {
    final entities = await directory.list().toList();
    return (regExp == null
            ? entities
            : entities.where(
                (element) => regExp.hasMatch(element.uri.pathSegments.last)))
        .toList();
  }

  static String tsToFormattedTime(int ts) {
    return DateTime.fromMillisecondsSinceEpoch(ts).formattedWithTime;
  }

  static String formatDay(DateTime day, {String format = "yyyy-MM-dd"}) {
    final DateFormat formatter = DateFormat(format);
    return formatter.format(day);
  }

  //
  // static DateTime normalizeDate(DateTime day) {
  //   var string = formatDay(day);
  //   return DateTime.parse(string);
  // }

  /// Creates a scaffold route with transition to the given scaffold view
  static Route createScaffoldRoute({required Widget view}) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => view,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.ease;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}
