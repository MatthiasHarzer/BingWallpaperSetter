import 'dart:io';

import 'package:bing_wallpaper_setter/services/config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart' as web;

class FileLogOutput extends LogOutput{
  @override
  void output(OutputEvent event){
    for(var line in event.lines){
      Util.logToFile(line);
    }
  }
}

class Printer extends LogPrinter{
  @override
  List<String> log(LogEvent event){
    return [event.message];
  }
}

Logger getLogger(){
  return Logger(
    printer: Printer(),
    level: Level.debug,
    output: MultiOutput([FileLogOutput(), ConsoleOutput()]),
    filter: ProductionFilter(), // For now
  );
}

class Util{
  /// Downloads a file from an [url] to a given [directory]. Returns the files path.
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

    await file.writeAsString("$message\n", mode: FileMode.append);
  }

  /// Opens the given [url] in a browser window.
  static void openUrl(String url){
    web.launchUrl(Uri.parse(url), mode: web.LaunchMode.externalApplication);
  }

  /// Opens the log file in the explorer
  static Future<void> openLogFile() async{
    String path = (await ConfigService.publicDirectory).path;

    if(!(await File("$path/log.txt").exists())){
      await logToFile("This is the beginning of the log file.");
    }

    await OpenFile.open("$path/log.txt");
  }

  /// Hides the current snackbar
  static void hideSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Shows a snackbar
  static void showSnackBar(BuildContext context, {required Widget content, SnackBarAction? action, int seconds = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        action: action,
        content: content,
        duration: Duration(seconds: seconds),
      ),

    );
  }

  /// Returns a list of files contained in the [directory] matching the [regExp]
  static List<FileSystemEntity> listDir(Directory directory, {RegExp? regExp}){
    final entities = directory.listSync();
    return (regExp == null ? entities : entities.where((element) => regExp.hasMatch(element.uri.pathSegments.last))).toList();

  }

  static String tsToFormattedTime(int ts){
    DateTime date = DateTime.fromMillisecondsSinceEpoch(ts);
    final DateFormat formatter = DateFormat('dd.MM.yyyy hh:mm:ss');
    return formatter.format(date);
  }

  static String formatDay(DateTime day){
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    return formatter.format(day);
  }

  static DateTime normalizeDate(DateTime day){
    var string = formatDay(day);
    return DateTime.parse(string);
  }

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