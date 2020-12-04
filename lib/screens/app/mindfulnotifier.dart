import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/schedule.dart';
import 'package:mindfulnotifier/screens/schedules/schedulesview.dart';
import 'package:mindfulnotifier/screens/widgetview.dart';
import 'package:date_format/date_format.dart';

const bool testing = false;

class RemindfulApp extends StatelessWidget {
  final String title;
  RemindfulApp(this.title);

  void init() async {
    initializeNotifications();
    initializeAlarmManager();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      //home: RemindfulAppWidget(title: title),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routes: {
        '/': (context) => RemindfulAppWidget(title: title),
        '/schedules': (context) => SchedulesWidget(),
        // '/reminders': (context) => RemindersScreen(),
        // '/bells': (context) => BellScreen(),
        // '/advanced': (context) => AdvancedScreen(),
      },
    );
  }
}

class RemindfulAppWidget extends StatefulWidget {
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

  RemindfulAppWidget({Key key, this.title}) : super(key: key);

  @override
  RemindfulWidgetController createState() => RemindfulWidgetController(title);
}

class RemindfulWidgetController extends State<RemindfulAppWidget> {
  // UI event handlers, init code, etc goes here

  final String title;
  String message = 'Not Running';
  String infoMessage = 'Not Running';
  bool _enabled = false;
  bool _mute = false;
  static Scheduler scheduler;
  TimeOfDay quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = TimeOfDay(hour: 10, minute: 0);

  RemindfulWidgetController(this.title) {
    _getDS();
  }

  static DataStore _ds;

  static void _getDS() async {
    _ds ??= await DataStore.create();
  }

  Future<void> _handlePermissions() async {
    // TODO change this to take the user to the settings in UI
    Map<Permission, PermissionStatus> statuses = await [
      Permission.ignoreBatteryOptimizations,
      Permission.notification,
    ].request();
    print(statuses[Permission.location]);
  }

  void setEnabled(bool enabled) async {
    // await _handlePermissions();
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values.
      _enabled = enabled;
      if (_enabled) {
        if (scheduler != null) {
          scheduler.disable();
        }
        setMessage('Running');
        setInfoMessage('Running');
        scheduler = _ds.buildScheduler(this, title);
        scheduler.enable();
      } else {
        scheduler?.disable();
        setMessage('Disabled');
        setInfoMessage('Disabled');
        scheduler = null;
      }
    });
  }

  void setNextNotification(TimeOfDay timeOfDay) {
    var timestr = formatDate(
        DateTime(2020, 01, 1, timeOfDay.hour, timeOfDay.minute),
        [hh, ':', nn, " ", am]).toString();
    if (message == 'Running' || message == 'Disabled') {
      setMessage("Next notification at $timestr");
    }
    setInfoMessage("Next notification at $timestr");
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

  void setInfoMessage(String msg) {
    setState(() {
      infoMessage = msg;
    });
  }

  void handleScheduleOnTap() {
    // https://flutter.dev/docs/cookbook/navigation/navigation-basics
    Navigator.pushNamed(
      context,
      '/schedules',
    );
    // Navigator.pop(context);
  }

  void handleRemindersOnTap() {
    Navigator.pop(context);
  }

  void handleBellOnTap() {
    Navigator.pop(context);
  }

  void handleAdvancedOnTap() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _RemindfulWidgetView(this);
}

class _RemindfulWidgetView
    extends WidgetView<RemindfulAppWidget, RemindfulWidgetController> {
  _RemindfulWidgetView(RemindfulWidgetController state) : super(state);

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
              '${state.message}',
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
            Text(
              '${state.infoMessage}',
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
              subtitle: Text('Configure reminder contents'),
              onTap: state.handleRemindersOnTap,
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Bell'),
              subtitle: Text('Configure bell'),
              onTap: state.handleBellOnTap,
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Advanced'),
              onTap: state.handleAdvancedOnTap,
            ),
          ],
        ),
      ),
    );
  }
}
