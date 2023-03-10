import 'package:bing_wallpaper_setter/services/wallpaper_service.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import '../consts.dart' as consts;
import '../util/log.dart';
import 'config_service.dart';

final _logger = getLogger();

@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask(BackgroundService.onTask);
}

/// The callback, when the widget was clicked
Future<void> widgetBackgroundCallback(Uri? uri) async {
  await ConfigService.ensureInitialized();

  if (uri?.host == consts.WIDGET_HOST) {
    await WallpaperService.updateWallpaperOnWidgetIntent();
  }
}

/// Handles background task running
class BackgroundService {
  /// Initializes the background service (workamanger/home widget)
  static void ensureInitialized() {
    Workmanager().initialize(workmanagerCallbackDispatcher,
        // The top level function, aka callbackDispatcher
        isInDebugMode:
            kDebugMode // If enabled it will post a notification whenever the task is running. Handy for debugging tasks
        );

    HomeWidget.registerBackgroundCallback(widgetBackgroundCallback);
  }

  /// The callback function for the background task
  static Future<bool> onTask(String task, Map<String, dynamic>? data) async {
    await ConfigService.ensureInitialized();

    try {
      _logger.i("---- Running background task $task ----");
      switch (task) {
        case consts.BG_WALLPAPER_TASK_ID:
          if (!ConfigService.dailyModeEnabled) break;

          await WallpaperService.updateWallpaperOnBackgroundTaskIntent();

          ConfigService.bgWallpaperTaskLastRun =
              DateTime.now().millisecondsSinceEpoch;
        // scheduleTask(); // Schedule next task
      }
    } catch (error) {
      _logger.e(error.toString());
      return false;
    }
    _logger.i("---- Finished background task successfully -----");

    return true;
  }

  /// Calculates the delay until the next day
  static Duration _getDelayUntilNextDay() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  /// Schedules the background task
  static void scheduleTask() {
    Workmanager().registerPeriodicTask(
        consts.BG_WALLPAPER_TASK_ID, consts.BG_WALLPAPER_TASK_ID,
        frequency: consts.BG_TASK_FREQUENCY,
        initialDelay: _getDelayUntilNextDay(),
        existingWorkPolicy: ExistingWorkPolicy.replace);
    _logger.i("Scheduled task. Next run in ${_getDelayUntilNextDay()}");
  }

  /// Stops the background task
  static Future<void> stopTask() async {
    await Workmanager().cancelByUniqueName(consts.BG_WALLPAPER_TASK_ID);
    _logger.i("Stopped background task");
  }

  /// Checks if the background task should be running and starts/stops it
  static Future<void> checkAndScheduleTask() async {
    if (ConfigService.dailyModeEnabled) {
      scheduleTask();
      await WallpaperService.updateWallpaperOnBackgroundTaskIntent();
    } else {
      await stopTask();
    }
  }
}
