import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:remindfulbell/screens/widgetview.dart';
import 'package:remindfulbell/components/notifier.dart';
import 'package:remindfulbell/components/schedule.dart';

// const String appName = 'Remindful Bell';
const bool testing = false;

class RemindfulApp extends StatelessWidget {
  final String title;
  RemindfulApp(this.title);

  void init() async {}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      home: RemindfulAppWidget(title: title),
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
  bool _enabled = false;
  bool _mute = false;
  Scheduler scheduler;
  TimeOfDay quietStart = TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = TimeOfDay(hour: 10, minute: 0);

  RemindfulWidgetController(this.title) {
    // TODO the scheduler will be created in the enable code below,
    // based on the schedule configuration defined by the schedule widget
    setScheduler(new PeriodicScheduler(
        this, 0, 15, new QuietHours(quietStart, quietEnd), title));
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
              onTap: null,
            ),
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Bell'),
              subtitle: Text('Configure bell'),
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
