import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:android_alarm_manager/android_alarm_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
      home: RemindfulAppWidget(title: _title),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}

class RemindfulAppWidget extends StatefulWidget {
  RemindfulAppWidget({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

/*
From https://flutter.dev/docs/development/ui/interactive#managing-state:
Who manages the stateful widget’s state? The widget itself? 
The parent widget? Both? Another object? The answer is… it depends. 
There are several valid ways to make your widget interactive. 
You, as the widget designer, make the decision based on how you expect 
your widget to be used. Here are the most common ways to manage state:

  - The widget manages its own state
  - The parent manages the widget’s state
  - A mix-and-match approach

How do you decide which approach to use? The following principles 
should help you decide:
  - If the state in question is user data, for example the checked or 
    unchecked mode of a checkbox, or the position of a slider, then 
    the state is best managed by the parent widget.
  - If the state in question is aesthetic, for example an animation,
    then the state is best managed by the widget itself.
If in doubt, start by managing state in the parent widget.
*/

  final String title;

  @override
  _RemindfulWidgetController createState() => _RemindfulWidgetController();
}

class _RemindfulWidgetController extends State<RemindfulAppWidget> {
  // UI event handlers, init code, etc goes here

  String message = 'Not Running';
  bool _enabled = false;
  bool _mute = false;
  Scheduler scheduler;
  TimeOfDay quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = TimeOfDay(hour: 10, minute: 0);

  _RemindfulWidgetController() {
    // TODO the scheduler will be created in the enable code below,
    // based on the schedule configuration defined by the schedule widget
    setScheduler(
        new PeriodicScheduler(0, 15, new QuietHours(quietStart, quietEnd)));
  }

  void setScheduler(Scheduler s) {
    scheduler = s;
  }

  void setEnabled(bool enabled) {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _enabled = enabled;
      if (_enabled) {
        scheduler.enable();
        setMessage('Running');
      } else {
        scheduler.disable();
        setMessage('Disabled');
      }
    });
  }

  void setMute(bool mute) {
    setState(() {
      _mute = mute;
      Notifier.mute = _mute;
    });
  }

  void setMessage(String msg) {
    setState(() {
      message = msg;
    });
  }

  void handleScheduleOnTap() {
    // TODO launch the schedule widget
    // https://flutter.dev/docs/cookbook/navigation/navigation-basics

    //   Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _RemindfulWidgetView(this);
}

class _RemindfulWidgetView extends StatelessWidget {
  final _RemindfulWidgetController state;
  const _RemindfulWidgetView(this.state, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Widget tree
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(state.widget.title),
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
              '$state._message',
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
                      value: state._enabled,
                      onChanged: state.setEnabled,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text('Mute'),
                    Switch(
                      value: state._mute,
                      onChanged: state.setMute,
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
          children: <Widget>[
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
              subtitle: Text('Configure reminder frequency'),
              onTap: state.handleScheduleOnTap,
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
  static const int quietHoursStartAlarmID = 21;
  static const int quietHoursEndAlarmID = 22;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  static bool inQuietHours = false;
  static SendPort uiSendPort;

  QuietHours(this.startTime, this.endTime);
  QuietHours.defaultQuietHours()
      : this(TimeOfDay(hour: 21, minute: 0), TimeOfDay(hour: 9, minute: 0));

  DateTime _getTimeOfDayToday(TimeOfDay tod) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
  }

  DateTime _getTimeOfDayTomorrow(TimeOfDay tod) {
    final tomorrow = DateTime.now().add(Duration(days: 1));
    return DateTime(
        tomorrow.year, tomorrow.month, tomorrow.day, tod.hour, tod.minute);
  }

  DateTime getNextQuietStart() {
    DateTime quietStart = _getTimeOfDayToday(startTime);
    if (quietStart.isBefore(DateTime.now())) {
      quietStart = _getTimeOfDayTomorrow(startTime);
    }
    return quietStart;
  }

  DateTime getNextQuietEnd() {
    DateTime quietStart = _getTimeOfDayToday(startTime);
    DateTime quietEnd = _getTimeOfDayToday(endTime);
    if (quietEnd.isBefore(quietStart)) {
      quietEnd = _getTimeOfDayTomorrow(endTime);
    }
    return quietEnd;
  }

  bool isInQuietHours(DateTime date) {
    DateTime quietStart = _getTimeOfDayToday(startTime);
    DateTime quietEnd = getNextQuietEnd();
    return (date.isAfter(quietStart) && date.isBefore(quietEnd));
  }

  void initializeTimers() async {
    if (isInQuietHours(DateTime.now())) {
      quietStart();
    }
    print("Initializing quiet hours timers");
    await AndroidAlarmManager.periodic(Duration(days: 1),
        quietHoursStartAlarmID, QuietHours.alarmCallbackStart,
        startAt: getNextQuietStart(), exact: true, wakeup: true);
    await AndroidAlarmManager.periodic(
        Duration(days: 1), quietHoursEndAlarmID, QuietHours.alarmCallbackEnd,
        startAt: getNextQuietEnd(), exact: true, wakeup: true);
  }

  void cancelTimers() async {
    print("Cancelling quiet hours timers");
    await AndroidAlarmManager.cancel(quietHoursStartAlarmID);
    await AndroidAlarmManager.cancel(quietHoursEndAlarmID);
  }

  void quietStart() {
    final DateTime now = DateTime.now();
    print("[$now] Quiet hours start");
    inQuietHours = true;
  }

  static void alarmCallbackStart() {
    // Send to the UI thread
    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send('quietStartCallback');
  }

  void quietEnd() {
    final DateTime now = DateTime.now();
    print("[$now] Quiet hours end");
    inQuietHours = false;
  }

  static void alarmCallbackEnd() {
    // Send to the UI thread
    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send('quietEndCallback');
  }
}

enum ScheduleType { PERIODIC, RANDOM }

abstract class Scheduler {
  final ScheduleType scheduleType;
  final int scheduleAlarmID = 10;
  final Notifier _notifier = new Notifier();
  bool running = false;
  static bool initialized = false;
  QuietHours quietHours;
  Reminders reminders;

  // The background
  static SendPort uiSendPort;

  Scheduler(this.scheduleType, this.quietHours) {
    _init();
  }

  void _init() async {
    uiSendPort = null;
    if (!Scheduler.initialized) {
      print("Initializing scheduler");
      // IsolateNameServer.registerPortName(receivePort.sendPort, isolateName);
      reminders = new Reminders();
      reminders.init();

      await AndroidAlarmManager.initialize();

      // Register for events from the background isolate. These messages will
      // always coincide with an alarm firing.
      //port.listen((_) async => await _triggerNotification());
      port.listen((_) async {
        switch (_) {
          case 'scheduleCallback':
            await _triggerNotification();
            break;
          case 'quietStartCallback':
            quietHours.quietStart();
            break;
          case 'quietEndCallback':
            quietHours.quietEnd();
            break;
        }
      });
    }
    Scheduler.initialized = true;
  }

  void cancelSchedule() async {
    print("Cancelling notification schedule");
    await AndroidAlarmManager.cancel(scheduleAlarmID);
  }

  void enable() {
    quietHours.initializeTimers();
    schedule();
    running = true;
  }

  void disable() {
    cancelSchedule();
    quietHours.cancelTimers();
    running = false;
  }

  void schedule() {
    print("Scheduling notification, type=$scheduleType");
  }

  Future<void> _triggerNotification() async {
    // 1) lookup a random reminder
    // 2) trigger a notification based on
    //    https://pub.dev/packages/flutter_local_notifications

    final DateTime now = DateTime.now();
    final int isolateId = Isolate.current.hashCode;
    print("[$now] _triggerNotification isolate=$isolateId");

    // if (quietHours.isInQuietHours(now)) {
    if (QuietHours.inQuietHours) {
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
    uiSendPort?.send('scheduleCallback');
  }
}

class PeriodicScheduler extends Scheduler {
  final int durationHours;
  final int durationMinutes; // minimum granularity: 15m

  PeriodicScheduler(
      this.durationHours, this.durationMinutes, QuietHours quietHours)
      : super(ScheduleType.PERIODIC, quietHours);

  DateTime getInitialStart({DateTime now}) {
    now ??= DateTime.now();
    int periodInMins = 60 * durationHours + durationMinutes;
    DateTime startTime = now.add(Duration(minutes: periodInMins));
    switch (durationMinutes) {
      case 0:
      case 45:
        // schedule next for top of the hour
        DateTime startTimeRaw = now.add(Duration(hours: 1));
        startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
            startTimeRaw.day, startTimeRaw.hour, 0, 0, 0, 0);
        break;
      case 30:
        // schedule next for either top or bottom the hour (< 30m)
        DateTime startTimeRaw = now.add(Duration(minutes: 30));
        if (startTimeRaw.minute < 30) {
          startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
              startTimeRaw.day, startTimeRaw.hour, 0, 0, 0, 0);
        } else {
          startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
              startTimeRaw.day, startTimeRaw.hour, 30, 0, 0, 0);
        }
        break;
      case 15:
        // schedule next for < 15m
        DateTime startTimeRaw = now.add(Duration(minutes: 15));
        int newMinute;
        int newHour = startTimeRaw.hour;
        // want to use the diff here, between now and 15m interval
        if (startTimeRaw.minute >= 0 && startTimeRaw.minute < 15) {
          newMinute = 0;
        } else if (startTimeRaw.minute >= 15 && startTimeRaw.minute < 30) {
          newMinute = 15;
        } else if (startTimeRaw.minute >= 30 && startTimeRaw.minute < 45) {
          newMinute = 30;
        } else {
          if (++newHour > 23) {
            // day rollover
            startTimeRaw = now.add(Duration(days: 1));
            newHour = 0;
          }
          newMinute = 0;
        }
        startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
            startTimeRaw.day, newHour, newMinute, 0, 0, 0);
        break;
    }
    return startTime;

    // // Schedule first notification to align with the top of the hour,
    // // based on the hours/mins. The minimum granularity is 15m.
    // int periodInMins = 60 * durationHours + durationMinutes;

    // DateTime startTime = now.add(Duration(minutes: periodInMins));

    // int nowMillisecondsSinceEpoch = now.millisecondsSinceEpoch;
    // int nowMinSinceEpoch = (nowMillisecondsSinceEpoch / 60000).round();

    // int nextIntervalMin = (nowMinSinceEpoch + periodInMins) % periodInMins + 1;

    // DateTime startTimeRaw = DateTime.fromMillisecondsSinceEpoch(
    //     nowMillisecondsSinceEpoch + (nextIntervalMin * 60000));
    // DateTime startTime = DateTime(startTimeRaw.year, startTimeRaw.month,
    //     startTimeRaw.day, startTimeRaw.hour, startTimeRaw.minute, 0, 0, 0);
    // print(
    //     "Scheduling: now: $now, nextIntervalMin: $nextIntervalMin, startTime: $startTime");
  }

  void schedule() async {
    super.schedule();
    if (testing) {
      print("Scheduling for periodic testing");
      await AndroidAlarmManager.periodic(
          Duration(seconds: 30), scheduleAlarmID, Scheduler.alarmCallback,
          exact: true, wakeup: true);
      return;
    }
    DateTime startTime = getInitialStart();
    print("Scheduling: now: ${DateTime.now()}, startTime: $startTime");
    await AndroidAlarmManager.periodic(
        Duration(hours: durationHours, minutes: durationMinutes),
        scheduleAlarmID,
        Scheduler.alarmCallback,
        startAt: startTime,
        exact: true,
        wakeup: true);
  }
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
    super.schedule();
    Random random = new Random();
    int nextMinutes = minMinutes + random.nextInt(maxMinutes - minMinutes);
    DateTime nextDate = DateTime.now().add(Duration(minutes: nextMinutes));
    // if (quietHours.inQuietHours(nextDate)) {
    //   print("Scheduling past next quiet hours");
    //   nextDate = quietHours.getNextQuietEnd().add(Duration(minutes: nextMinutes));
    // }
    print("Scheduling next random notifcation at $nextDate");
    await AndroidAlarmManager.oneShotAt(
        nextDate, scheduleAlarmID, Scheduler.alarmCallback,
        exact: true, wakeup: true);
  }
}

class Reminders {
  SharedPreferences _prefs;
  static final String reminderKey = 'reminders';
  static final String reminderInitializedKey = 'remindersInitialized';

  // This is the initial list of reminders. It will only be used until the reminders are persisted...
  List<String> reminders = [
    "Are you aware?",
    "Breathe deeply. There is only the present moment.",
    "Be present in this moment.",
    "Let go of greed, aversion, and delusion.",
    "Trust the universe.",
    "Respond, not react.",
    "All of this is impermanent.",
    "Connect, then correct.",
    "Accept the feeling of what is happening in this moment. Don't struggle against it. Instead, notice it. Take it in.",
    "Remember RAIN: Recognize / Allow / Invesigate with interest and care / Nurture with self-compassion",
    "Note feeling tones (flavour): Pleasant / Unpleasant / Neutral",
    "What is the attitude in the mind right now?",
    "May you be safe and free from harm. May you be healthy and free from suffering. May you be happy. May you be peaceful and live with ease.",
    "Whatever it is that has the nature to arise will also pass away; therefore, there is nothing to want.",
    "Sitting quietly, Doing nothing, Spring comes, and the grass grows, by itself.",
    // "If this fear is with me the rest of my life, that is okay.",
  ];
  List<String> shuffledReminders;

  Reminders() {
    init();
  }

  void init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs.containsKey(reminderInitializedKey)) {
      load();
    } else {
      print("Initial reminders persistence");
      persist();
    }
    shuffledReminders = reminders.toList();
  }

  String randomReminder() {
    shuffledReminders.shuffle();
    return shuffledReminders.first;
  }

  void persist() {
    print("Persisting reminders into storage");
    _prefs.setStringList(reminderKey, reminders);
    _prefs.setBool(reminderInitializedKey, true);
  }

  void load() {
    print("Loading reminders from storage");
    reminders = _prefs.getStringList(reminderKey);
  }
}

class Notifier {
  static String channelId = 'remindfulbell_channel_id';
  static const String channelName = 'remindfulbell_channel_name';
  static const String channelDescription = 'Notifications for remindful bell';
  static const String notifTitle = appName;
  static bool mute = false;
  static bool vibrate = true;
  static String customBellPath;
  final String defaultBellAsset = 'media/defaultbell.mp3';
  String customSoundFile;

  void showNotification(String notifText) async {
    DateTime now = DateTime.now();

    AndroidNotificationSound notifSound;
    if (customBellPath == null) {
      channelId = 'defaultbell';
      notifSound = RawResourceAndroidNotificationSound(channelId);
    } else {
      notifSound = UriAndroidNotificationSound(customBellPath);
      channelId = customBellPath;
    }
    print(
        "[$now] showNotification [channelId=$channelId]: title=$notifTitle text=$notifText mute=$mute");
    // "[$now] showNotification [channelId=$channelId]: title=$notifTitle text=$notifText mute=$mute, sound=$notifSound");
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(channelId, channelName, channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: vibrate,
            // playSound: !mute,
            playSound: false,
            // sound: notifSound,
            ticker: 'ticker');
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
        0, notifTitle, notifText, platformChannelSpecifics,
        payload: 'item x');

    if (!mute) {
      final player = AudioPlayer();
      if (customSoundFile == null) {
        await player.setAsset(defaultBellAsset);
      } else {
        await player.setFilePath(customBellPath);
      }
      await player.play();
      await player.dispose();
    }
  }
}
