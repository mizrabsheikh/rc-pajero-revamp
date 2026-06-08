import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

// The callback function should be a top-level function or a static function.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[BackgroundService] Task started');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This is called periodically based on interval.
    // We don't necessarily need to do anything here if our main logic
    // is already running in the UI isolate and we just want to keep the process alive.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isUserStep) async {
    debugPrint('[BackgroundService] Task destroyed');
  }
}

class ForegroundServiceController {
  static final ForegroundServiceController _instance =
      ForegroundServiceController._internal();
  factory ForegroundServiceController() => _instance;
  ForegroundServiceController._internal();

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<ServiceRequestResult> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        notificationTitle: 'RC Car Active',
        notificationText: 'App is running in the background',
        notificationIcon: null,
        callback: startCallback,
      );
    }
  }

  Future<ServiceRequestResult> stopService() async {
    return FlutterForegroundTask.stopService();
  }

  Future<void> requestPermissions() async {
    // Android 13+ requires notification permission
    if (Platform.isAndroid) {
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }

      // Foreground service special use permission for Android 14+
      // Actually flutter_foreground_task handles most of this but we ensure permissions are requested.
    }
  }
}
