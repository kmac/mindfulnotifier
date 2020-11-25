import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
// import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
// import 'package:device_info/device_info.dart';

const String appName = 'Remindful Bell';
const bool testing = false;

// The name associated with the UI isolate's [SendPort].
const String isolateName = 'alarmIsolate';

// A port used to communicate from a background isolate to the UI isolate.
final ReceivePort port = ReceivePort();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Streams are created so that app can respond to notification-related events
// since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String> selectNotificationSubject =
    BehaviorSubject<String>();

// const MethodChannel platform = MethodChannel('kmsd.ca/remindfulbell');

class ReceivedNotification {
  ReceivedNotification({
    @required this.id,
    @required this.title,
    @required this.body,
    @required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String payload;
}

void main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  await _configureLocalTimeZone();

  // Register the UI isolate's SendPort to allow for communication from the
  // background isolate.
  IsolateNameServer.registerPortWithName(
    port.sendPort,
    isolateName,
  );

  final NotificationAppLaunchDetails notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');

  /// Note: permissions aren't requested here just to demonstrate that can be
  /// done later
  final IOSInitializationSettings initializationSettingsIOS =
      IOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          onDidReceiveLocalNotification:
              (int id, String title, String body, String payload) async {
            didReceiveLocalNotificationSubject.add(ReceivedNotification(
                id: id, title: title, body: body, payload: payload));
          });

  const MacOSInitializationSettings initializationSettingsMacOS =
      MacOSInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false);

  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsMacOS);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String payload) async {
    if (payload != null) {
      debugPrint('notification payload: $payload');
    }
    selectNotificationSubject.add(payload);
  });

  runApp(RemindfulApp());
}

Future<void> _configureLocalTimeZone() async {
  tz.initializeTimeZones();
  final String currentTimeZone = await FlutterNativeTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(currentTimeZone));
}

class RemindfulApp extends StatelessWidget {
  static const String _title = 'ReMindful Bell';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      home: RemindfulHomePage(title: _title),
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class RemindfulHomePage extends StatefulWidget {
  RemindfulHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _RemindfulHomePageState createState() => _RemindfulHomePageState();
}

class _RemindfulHomePageState extends State<RemindfulHomePage> {
  String _message = 'Not Running';
  bool _enabled = false;
  bool _mute = false;
  Scheduler scheduler;
  TimeOfDay quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = TimeOfDay(hour: 10, minute: 0);

  _RemindfulHomePageState() {
    scheduler =
        new PeriodicScheduler(0, 15, new QuietHours(quietStart, quietEnd));
  }

  void _setEnabled(bool enabled) {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _enabled = enabled;
      if (_enabled) {
        scheduler.enable();
        _setMessage('Running');
      } else {
        scheduler.disable();
        _setMessage('Disabled');
      }
    });
  }

  void _setMute(bool mute) {
    setState(() {
      _mute = mute;
    });
  }

  void _setMessage(String msg) {
    setState(() {
      _message = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Text(
              '$_message',
              style: Theme.of(context).textTheme.headline4,
            ),
            // Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Text('Enabled'),
                    Switch(
                      value: _enabled,
                      onChanged: _setEnabled,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text('Mute'),
                    Switch(
                      value: _mute,
                      onChanged: _setMute,
                    ),
                  ],
                )
              ],
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: const <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              //leading: Icon(Icons.message),
              leading: Icon(Icons.schedule),
              title: Text('Schedule'),
              onTap: null,
            ),
            ListTile(
              // leading: Icon(Icons.alarm),
              leading: Icon(Icons.list),
              title: Text('Reminders'),
              onTap: null,
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Bell'),
              onTap: null,
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Advanced'),
              onTap: null,
            ),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _setEnabled(true),
      //   tooltip: 'Increment',
      //   child: Icon(Icons.add),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class QuietHours {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  QuietHours(this.startTime, this.endTime);

  DateTime _getTimeOfDayToday(TimeOfDay tod) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
  }

  DateTime _getTimeOfDayTomorrow(TimeOfDay tod) {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    return DateTime(
        tomorrow.year, tomorrow.month, tomorrow.day, tod.hour, tod.minute);
  }

  DateTime getNextQuietEnd() {
    DateTime quietStart = _getTimeOfDayToday(startTime);
    DateTime quietEnd = _getTimeOfDayToday(endTime);
    if (quietEnd.isBefore(quietStart)) {
      quietEnd = _getTimeOfDayTomorrow(endTime);
    }
    return quietEnd;
  }

  bool inQuietHours(DateTime date) {
    DateTime quietStart = _getTimeOfDayToday(startTime);
    DateTime quietEnd = getNextQuietEnd();
    return (date.isAfter(quietStart) && date.isBefore(quietEnd));
  }
}

enum ScheduleType { PERIODIC, RANDOM }

abstract class Scheduler {
  final ScheduleType scheduleType;
  final int alarmID = 0;
  final Notifier _notifier = new Notifier();
  bool running = false;
  static bool initialized = false;
  QuietHours quietHours;
  Reminders reminders;

  // The background
  static SendPort uiSendPort;

  Scheduler(this.scheduleType, this.quietHours) {
    init();
  }

  void init() async {
    if (!initialized) {
      // IsolateNameServer.registerPortName(receivePort.sendPort, isolateName);
      reminders = new Reminders();
      reminders.init();

      await AndroidAlarmManager.initialize();

      // Register for events from the background isolate. These messages will
      // always coincide with an alarm firing.
      port.listen((_) async => await _triggerNotification());
    }
    initialized = true;
  }

  void cancel() async {
    await AndroidAlarmManager.cancel(alarmID);
  }

  void enable() {
    schedule();
    running = true;
  }

  void disable() {
    cancel();
    running = false;
  }

  void schedule();

  Future<void> _triggerNotification() async {
    // 1) lookup a random reminder
    // 2) trigger a notification based on
    //    https://pub.dev/packages/flutter_local_notifications

    final DateTime now = DateTime.now();
    final int isolateId = Isolate.current.hashCode;
    print("[$now] _triggerNotification isolate=$isolateId");

    if (quietHours.inQuietHours(now)) {
      print("In quiet hours... ignoring notification");
      return;
    }
    _notifier.showNotification(reminders.randomReminder());
  }

  // alarmCallback will not run in the same isolate as the main application.
  // Unlike threads, isolates do not share memory and communication between
  // isolates must be done via message passing (see more documentation on isolates here).
  static void alarmCallback() {
    final DateTime now = DateTime.now();
    final int isolateId = Isolate.current.hashCode;
    print("[$now] alarmCallback isolate=$isolateId");

    // Send to the UI thread

    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send(null);
  }
}

class PeriodicScheduler extends Scheduler {
  final int durationHours;
  final int durationMinutes; // minimum granularity: 15m

  PeriodicScheduler(
      this.durationHours, this.durationMinutes, QuietHours quietHours)
      : super(ScheduleType.PERIODIC, quietHours);

  void schedule() async {
    // Schedule first notification to align with the top of the hour,
    // based on the hours/mins
    int periodInMins = 60 * durationHours + durationMinutes;
    DateTime now = DateTime.now();
    int nowMinSinceEpoch = (now.millisecondsSinceEpoch / 60000).round();
    int nextIntervalMin = (nowMinSinceEpoch + periodInMins) % periodInMins + 1;

    //DateTime startTime = now.add(Duration(minutes: nextIntervalMin));
    DateTime startTime = DateTime.fromMillisecondsSinceEpoch(
        (nowMinSinceEpoch + nextIntervalMin) * 60000);

    print("Scheduling for $startTime");
    if (testing) {
      await AndroidAlarmManager.periodic(
          Duration(
              /*hours: durationHours, minutes: durationMinutes*/ seconds: 30),
          alarmID,
          Scheduler.alarmCallback,
          // startAt: startTime,
          exact: true,
          wakeup: true);
    } else {
      await AndroidAlarmManager.periodic(
          Duration(hours: durationHours, minutes: durationMinutes),
          alarmID,
          Scheduler.alarmCallback,
          startAt: startTime,
          exact: true,
          wakeup: true);
    }
  }

  // void schedule() async {
  //   DateTime nextDate = DateTime.now().add(Duration(hours: durationHours, minutes: durationMinutes));
  //   if (quietHours.inQuietHours(nextDate)) {
  //     print("Scheduling past next quiet hours");
  //     nextDate = quietHours.getNextQuietEnd().add(Duration(hours: durationHours, minutes: durationMinutes));
  //   }
  //   await AndroidAlarmManager.oneShotAt(
  //       nextDate, alarmID, Scheduler.alarmCallback,
  //       exact: true, wakeup: true);
  // }
}

class RandomScheduler extends Scheduler {
  //DateTimeRange range;
  final int minMinutes;
  final int maxMinutes;

  RandomScheduler(this.minMinutes, this.maxMinutes, QuietHours quietHours)
      : super(ScheduleType.RANDOM, quietHours);

  Future<void> _triggerNotification() async {
    super._triggerNotification();
    schedule();
  }

  void schedule() async {
    Random random = new Random();
    int nextMinutes = minMinutes + random.nextInt(maxMinutes - minMinutes);
    DateTime nextDate = DateTime.now().add(Duration(minutes: nextMinutes));
    // if (quietHours.inQuietHours(nextDate)) {
    //   print("Scheduling past next quiet hours");
    //   nextDate = quietHours.getNextQuietEnd().add(Duration(minutes: nextMinutes));
    // }
    await AndroidAlarmManager.oneShotAt(
        nextDate, alarmID, Scheduler.alarmCallback,
        exact: true, wakeup: true);
  }
}

class Reminders {
  void init() {}

  String randomReminder() {
    return 'this is a test';
  }
}

class Notifier {
  static const String channelId = 'remindfulbell_channel_id';
  static const String channelName = 'remindfulbell_channel_name';
  static const String channelDescription = 'Notifications for remindful bell';
  static const String notifTitle = appName;

  void showNotification(String notifText) async {
    print("showNotification: " + notifText);
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(channelId, channelName, channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
        0, notifTitle, notifText, platformChannelSpecifics,
        payload: 'item x');
  }
}
