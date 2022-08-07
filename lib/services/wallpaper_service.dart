import 'dart:convert';
import 'dart:io';

import 'package:bing_wallpaper_setter/consts.dart';
import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:devicelocale/devicelocale.dart';
import 'package:http/http.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';


import '../util/util.dart';

class WallpaperInfo {
  final String baseUrl;
  final String copyright;
  final String copyrightlink;
  final String title;

  String get mobileUrl => "${baseUrl}_${ConfigService.wallpaperResolution}.jpg";
  String get fullSizeUrl => "${baseUrl}_1920x1080.jpg";

  WallpaperInfo(
      {required this.baseUrl,
      required this.title,
      required this.copyright,
      required this.copyrightlink});
}

class WallpaperService {
  /// Gets the current wallpaper info
  static Future<WallpaperInfo> getWallpaper(String local) async {

    if(local == "auto"){
      local = (await Devicelocale.currentLocale).toString();
    }

    String url = BASE_URL + local;

    Response response = await get(Uri.parse(url), headers: {"Accept": "application/json"});

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
        copyrightlink: imageCopyrightlink);
  }

  /// Sets the devices wallpaper from an [url]
  static Future setWallpaperFromUrl(String url, int screen) async{
    String file = await Util.downloadFile(url, await ConfigService.localDirectory);


    WallpaperManagerFlutter().setwallpaperfromFile(File(file), screen);
    // await WallpaperManager.setWallpaperFromFile(file, screen);
  }


}


