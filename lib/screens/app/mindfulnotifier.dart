import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:mindfulnotifier/components/notifier.dart';
import 'package:mindfulnotifier/components/schedule.dart';
import 'package:mindfulnotifier/screens/schedules/schedulesview.dart';
import 'package:mindfulnotifier/screens/widgetview.dart';
import 'package:date_format/date_format.dart';

const bool testing = false;

class MindfulNotifierApp extends StatelessWidget {
  final String title;
  MindfulNotifierApp(this.title);

  void init() async {
    initializeNotifications();
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
        '/': (context) => MindfulNotifierAppWidget(title: title),
        '/schedules': (context) => SchedulesWidget(),
        // '/reminders': (context) => RemindersScreen(),
        // '/bells': (context) => BellScreen(),
        // '/advanced': (context) => AdvancedScreen(),
      },
    );
  }
}

class MindfulNotifierAppWidget extends StatefulWidget {
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

  MindfulNotifierAppWidget({Key key, this.title}) : super(key: key);

  @override
  MindfulNotifierWidgetController createState() =>
      MindfulNotifierWidgetController(title);
}

class MindfulNotifierWidgetController extends State<MindfulNotifierAppWidget> {
  // UI event handlers, init code, etc goes here

  final String title;
  String message = 'Not Running';
  String infoMessage = 'Not Running';
  bool _enabled = false;
  bool _mute = false;
  bool _vibrate = false;
  Scheduler scheduler;
  TimeOfDay quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    initializeReceivePort();
  }

  @override
  void dispose() {
    // scheduler.dispose();
    super.dispose();
  }

  MindfulNotifierWidgetController(this.title) {
    scheduler = Scheduler();
    scheduler.controller = this;
    scheduler.appName = title;
    scheduler.init();
  }

  // Future<void> _handlePermissions() async {
  //   // TODO change this to take the user to the settings in UI
  //   Map<Permission, PermissionStatus> statuses = await [
  //     // Permission.ignoreBatteryOptimizations,
  //     Permission.notification,
  //   ].request();
  //   print(statuses[Permission.location]);
  // }

  void setEnabled(bool enabled) {
    // await _handlePermissions();
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values.
      _enabled = enabled;
    });
    if (_enabled) {
      setMessage('Enabled. Awaiting first notification...');
      setInfoMessage('Enabled');
      scheduler.enable();
    } else {
      scheduler.disable();
      setMessage('Disabled');
      setInfoMessage('Disabled');
    }
  }

  void setNextNotification(DateTime dateTime) {
    var timestr =
        formatDate(dateTime, [hh, ':', nn, ':', ss, " ", am]).toString();
    setInfoMessage("Next notification at $timestr");
  }

  void setMute(bool mute) {
    setState(() {
      _mute = mute;
    });
    Notifier.mute = _mute;
  }

  void setVibrate(bool vibrate) {
    setState(() {
      _vibrate = vibrate;
    });
    Notifier.vibrate = _vibrate;
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
  Widget build(BuildContext context) => _MindfulNotifierWidgetView(this);
}

class _MindfulNotifierWidgetView extends WidgetView<MindfulNotifierAppWidget,
    MindfulNotifierWidgetController> {
  _MindfulNotifierWidgetView(MindfulNotifierWidgetController state)
      : super(state);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () => showDialog<bool>(
            context: context,
            builder: (ctxt) => AlertDialog(
                  title: Text('Warning'),
                  content: Text(
                    "If you use the back button here the app will exit, " +
                        "and you won't receive any further notifications. Do you really want to exit?",
                    softWrap: true,
                  ),
                  actions: [
                    FlatButton(
                      child: Text('Yes'),
                      onPressed: () {
                        state.scheduler.shutdown();
                        shutdownReceivePort();
                        Navigator.pop(ctxt, true);
                      },
                    ),
                    FlatButton(
                      child: Text('No'),
                      onPressed: () => Navigator.pop(ctxt, false),
                    ),
                  ],
                )),
        // Widget tree
        child: Scaffold(
          appBar: AppBar(
            title: Text(state.widget.title),
          ),
          body: Center(
            child: Column(
              // Invoke "debug painting" (press "p" in the console, choose the
              // "Toggle Debug Paint" action from the Flutter Inspector in Android
              // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
              // to see the wireframe for each widget.
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Expanded(
                  flex: 15,
                  child: Container(
                    margin:
                        // EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 24),
                        EdgeInsets.only(
                            top: 30, left: 30, right: 30, bottom: 30),
                    alignment: Alignment.center,
                    // decoration: BoxDecoration(color: Colors.grey[100]),
                    child: Text(
                      '${state.message}',
                      style: Theme.of(context).textTheme.headline4,
                      // style: Theme.of(context).textTheme.headline5,
                      textAlign: TextAlign.left,
                      softWrap: true,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Switch(
                            value: state._enabled,
                            onChanged: state.setEnabled,
                          ),
                          Text(state._enabled ? 'Enabled' : 'Enable'),
                        ],
                      ),
                      ToggleButtons(
                        isSelected: [state._mute, state._vibrate],
                        onPressed: (index) {
                          switch (index) {
                            case 0:
                              state.setMute(!state._mute);
                              break;
                            case 1:
                              state.setVibrate(!state._vibrate);
                              break;
                          }
                        },
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(state._mute ? 'Muted' : 'Mute'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('Vibrate'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '${state.infoMessage}',
                    style: TextStyle(color: Colors.black38),
                  ),
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
                  leading: Icon(Icons.schedule),
                  title: Text('Schedule'),
                  subtitle: Text('Configure reminder frequency'),
                  onTap: state.handleScheduleOnTap,
                ),
                ListTile(
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
        ));
  }
}
