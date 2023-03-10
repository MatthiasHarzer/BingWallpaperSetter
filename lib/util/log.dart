import 'dart:io';

import 'package:bing_wallpaper_setter/consts.dart' as consts;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:open_file/open_file.dart';

import '../services/config_service.dart';

/// Uses [Util.logToFile] to log all events
class FileLogOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    var ansiColorString = PrettyPrinter.levelColors[event.level].toString();
    for (var line in event.lines) {
      String cleanedLine = line.replaceAll(ansiColorString,
          ""); // Remove ansi color string before writing to file
      _logToFileSync(cleanedLine);
    }
  }
}

/// Add-on to [PrettyPrinter]. Adds [<LevelName>] in front of log messages
class BetterPrettyPrinter extends PrettyPrinter {
  BetterPrettyPrinter({
    int stackTraceBeginIndex = 0,
    int methodCount = 2,
    int errorMethodCount = 8,
    int lineLength = 120,
    bool colors = true,
    bool printEmojis = true,
    bool printTime = false,
    Map<Level, bool> excludeBox = const {},
    bool noBoxingByDefault = true,
  }) : super(
            colors: colors,
            stackTraceBeginIndex: stackTraceBeginIndex,
            printEmojis: printEmojis,
            printTime: printTime,
            methodCount: methodCount,
            noBoxingByDefault: noBoxingByDefault,
            errorMethodCount: errorMethodCount,
            excludeBox: excludeBox,
            lineLength: lineLength);

  @override
  List<String> log(LogEvent event) {
    List<String> retval = super.log(event);
    return retval.map((r) => "[${event.level.name.toUpperCase()}] $r").toList();
  }
}

String _formatMessage(String msg) {
  var date = DateTime.now();
  DateFormat format = DateFormat("yyyy-MM-dd @ HH:mm:ss");
  return "[${format.format(date)}] $msg";
}

/// Logs the message to a local file in [ConfigService.publicDirectory]
Future<void> _logToFile(String message) async {
  File file = ConfigService.logFile;

  message = _formatMessage(message);

  await file.writeAsString("$message\n", mode: FileMode.append);
}

/// Like [_logToFile], but sync
void _logToFileSync(String message) {
  File file = ConfigService.logFile;
  message = _formatMessage(message);
  file.writeAsStringSync("$message\n", mode: FileMode.append);
}

/// Checks if the log file is too large an deletes line if so
Future<void> checkLogFileSize() async {
  File file = ConfigService.logFile;
  var lines = await file.readAsLines();
  int diff = lines.length - consts.LOG_FILE_LINES_LIMIT;
  if (diff <= 0) return;

  lines.removeRange(0, diff);

  await file.writeAsString(lines.join("\n"), mode: FileMode.write);

  getLogger().i("Deleted $diff lines from the log file");
}

/// Opens the log file in the explorer
Future<void> openLogFile() async {
  String path = ConfigService.publicDirectory.path;

  if (!(await File("$path/log.txt").exists())) {
    await _logToFile("This is the beginning of the log file.");
  }

  await OpenFile.open("$path/log.txt");
}

Logger getLogger() {
  return Logger(
    printer: BetterPrettyPrinter(
        colors: true,
        noBoxingByDefault: true,
        methodCount: 0,
        printEmojis: false),
    level: Level.debug,
    output: MultiOutput([FileLogOutput(), ConsoleOutput()]),
    filter: ProductionFilter(), // For now
  );
}
