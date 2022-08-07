import 'dart:io';

import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:flutter/foundation.dart';

class Util{
  /// Downloads a file from an [url] to a given [directory].
  static Future<String> downloadFile(String url, Directory directory,
      {String filename = "snapshot.png"}) async {
    // WidgetsFlutterBinding.ensureInitialized();

    var httpClient = HttpClient();
    var request = await httpClient.getUrl(Uri.parse(url));
    var response = await request.close();
    var bytes = await consolidateHttpClientResponseBytes(response);
    File file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.uri.path;

  }

  static String _formatMessage(String msg){
    var date = DateTime.now();
    return "[${date.year}-${date.month}-${date.day} @ ${date.hour}:${date.minute}:${date.second}] $msg";
  }

  /// Logs the message to a local file in [ConfigService.publicDirectory]
  static Future<void> logToFile(String message) async{
    var dir = await ConfigService.publicDirectory;
    File file = File("${dir.path}/log.txt");

    message = _formatMessage(message);

    print("logging $message");
    await file.writeAsString("$message\n", mode: FileMode.append);
    print("logged");
  }
}