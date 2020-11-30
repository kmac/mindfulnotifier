import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_duration_picker/flutter_duration_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:time_range/time_range.dart';
import 'package:datetime_picker_formfield/datetime_picker_formfield.dart';
import 'package:intl/intl.dart';

import 'package:remindfulbell/screens/widgetview.dart';

class SchedulesWidget extends StatefulWidget {
  SchedulesWidget({Key key}) : super(key: key);

  @override
  SchedulesWidgetController createState() => SchedulesWidgetController();
}

enum ScheduleType { periodic, random }

class ConfigManager {}

class SchedulesWidgetController extends State<SchedulesWidget> {
  var scheduleTypeKey = 'scheduleType';
  var periodicDurationHoursKey = 'periodicDurationHours';
  var periodicDurationMinutesKey = 'periodicDurationMinutes';
  var randomMinHoursKey = 'randomMinHours';
  var randomMinMinutesKey = 'randomMinMinutes';
  var randomMaxHoursKey = 'randomMaxHours';
  var randomMaxMinutesKey = 'randomMaxMinutes';

  SharedPreferences _prefs;
  ScheduleType scheduleType = ScheduleType.periodic;
  int periodicDurationHours = 1;
  int periodicDurationMinutes = 0;
  Duration periodicDuration = Duration(hours: 1);
  int randomMinHours = 0;
  int randomMinMinutes = 45;
  int randomMaxHours = 1;
  int randomMaxMinutes = 15;
  DateTime randomMinDateTime = DateTime.parse("1970-01-01 00:45:00Z");
  DateTime randomMaxDateTime = DateTime.parse("1970-01-01 01:30:00Z");

  // UI event handlers, init code, etc goes here
  SchedulesWidgetController() {
    loadPrefs();
  }

  String _twoDigits(int source) {
    if (source < 10) {
      return "0$source";
    }
    return source.toString();
  }

  DateTime _getDateTime(int hours, int minutes) {
    return DateTime.parse(
        "1970-01-01 ${_twoDigits(hours)}:${_twoDigits(minutes)}:00Z");
  }

  @override
  void initState() {
    super.initState();
  }

  void loadPrefs() async {
    print("loadPrefs");
    _prefs = await SharedPreferences.getInstance();

    // scheduleType
    if (_prefs.containsKey(scheduleTypeKey)) {
      if (_prefs.getString(scheduleTypeKey) == 'periodic') {
        scheduleType = ScheduleType.periodic;
      } else {
        scheduleType = ScheduleType.random;
      }
    } else {
      _prefs.setString(scheduleTypeKey, scheduleType.toString());
    }
    setScheduleType(scheduleType);

    // periodicDuration
    int durationHours = 1;
    int durationMinutes = 0;
    if (_prefs.containsKey(periodicDurationHoursKey)) {
      durationHours = _prefs.getInt(periodicDurationHoursKey);
    } else {
      _prefs.setInt(periodicDurationHoursKey, durationHours);
    }
    if (_prefs.containsKey(periodicDurationMinutesKey)) {
      durationMinutes = _prefs.getInt(periodicDurationMinutesKey);
    } else {
      _prefs.setInt(periodicDurationMinutesKey, durationMinutes);
    }
    periodicDuration = Duration(hours: durationHours, minutes: durationMinutes);
    setPeriodicDuration(periodicDuration);

    if (_prefs.containsKey(randomMinHoursKey)) {
      randomMinHours = _prefs.getInt(randomMinHoursKey);
    }
    if (_prefs.containsKey(randomMinMinutesKey)) {
      randomMinMinutes = _prefs.getInt(randomMinMinutesKey);
    }
    if (_prefs.containsKey(randomMaxHoursKey)) {
      randomMaxHours = _prefs.getInt(randomMaxHoursKey);
    }
    if (_prefs.containsKey(randomMaxMinutesKey)) {
      randomMaxMinutes = _prefs.getInt(randomMaxMinutesKey);
    }
    randomMinDateTime = _getDateTime(randomMinHours, randomMinMinutes);
    setRandomMinDateTime(randomMinDateTime);
    randomMaxDateTime = _getDateTime(randomMaxHours, randomMaxMinutes);
    setRandomMaxDateTime(randomMaxDateTime);
  }

  @override
  Widget build(BuildContext context) => _SchedulesWidgetView(this);

  void setScheduleType(ScheduleType t) {
    setState(() {
      scheduleType = t;
    });
    if (t == ScheduleType.periodic) {
      _prefs.setString(scheduleTypeKey, 'periodic');
    } else {
      _prefs.setString(scheduleTypeKey, 'random');
    }
  }

  void setPeriodicDurationHours(int hours) {
    _prefs.setInt(periodicDurationHoursKey, hours);
    setState(() {
      periodicDurationHours = hours;
    });
    if (hours > 0) {
      setPeriodicDurationMinutes(0);
    }
  }

  void setPeriodicDurationMinutes(int minutes) {
    _prefs.setInt(periodicDurationHoursKey, minutes);
    setState(() {
      periodicDurationMinutes = minutes;
    });
  }

  void setPeriodicDuration(Duration d) {
    print(
        "Setting duration: Duration: hours: ${d.inHours}, minutes: ${d.inMinutes}");
    int hours = d.inMinutes ~/ 60;
    if (hours > 23) {
      hours = 23;
    }
    int minutes = d.inMinutes % 60;
    _prefs.setInt(periodicDurationHoursKey, hours);
    _prefs.setInt(periodicDurationMinutesKey, minutes);
    print("Setting duration: hours: $hours, minutes: $minutes");
    setState(() {
      periodicDuration = Duration(hours: hours, minutes: minutes);
    });
  }

  void setRandomMinDateTime(DateTime time) {
    _prefs.setInt(randomMinHoursKey, time.hour);
    _prefs.setInt(randomMinMinutesKey, time.minute);
    setState(() {
      randomMinDateTime = time;
    });
  }

  void setRandomMaxDateTime(DateTime time) {
    _prefs.setInt(randomMaxHoursKey, time.hour);
    _prefs.setInt(randomMaxMinutesKey, time.minute);
    setState(() {
      randomMaxDateTime = time;
    });
  }
}

class _SchedulesWidgetView
    extends WidgetView<SchedulesWidget, SchedulesWidgetController> {
  _SchedulesWidgetView(SchedulesWidgetController state) : super(state);

  final bool useDurationPicker = false;

  DropdownButton<int> _buildDropDown(
      int dropdownValue, List<int> allowedValues, Function onChangedFunc,
      [bool useTwoDigits = false]) {
    return DropdownButton<int>(
      value: dropdownValue,
      // icon: Icon(Icons.arrow_downward),
      // iconSize: 24,
      elevation: 16,
      style: TextStyle(color: Colors.deepPurple),
      underline: Container(
        height: 2,
        color: Colors.deepPurpleAccent,
      ),
      onChanged: onChangedFunc,
      items: allowedValues.map<DropdownMenuItem<int>>((int value) {
        return DropdownMenuItem<int>(
          value: value,
          child:
              Text(useTwoDigits ? state._twoDigits(value) : value.toString()),
        );
      })?.toList(),
    );
  }

  List<Widget> _buildScheduleView() {
    List<Widget> widgets = [
      Text('Schedule'),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        const Text('Periodic'),
        Radio(
          value: ScheduleType.periodic,
          groupValue: state.scheduleType,
          onChanged: state.setScheduleType,
        ),
        const Text('Random'),
        Radio(
          value: ScheduleType.random,
          groupValue: state.scheduleType,
          onChanged: state.setScheduleType,
        ),
      ])
    ];
    if (state.scheduleType == ScheduleType.periodic) {
      if (useDurationPicker) {
        widgets.add(new Center(
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                  'Choose the notification period. The granularity is 15 minutes.'),
              DurationPicker(
                duration: state.periodicDuration,
                onChange: state.setPeriodicDuration,
                snapToMins: 15.0,
              ),
            ],
          ),
        ));
      } else {
        widgets.add(
          new Center(
              child: new Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                  'Choose the notification period. Notifications are aligned on the top of hour, If the period is shorter than one hour, the granularity is 15 minutes.'),
              new Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  new Column(
                    children: [
                      Text('Hours'),
                      _buildDropDown(
                          state.periodicDurationHours,
                          [0, 1, 2, 3, 4, 8, 12],
                          state.setPeriodicDurationHours),
                    ],
                  ),
                  Text(':'),
                  new Column(
                    children: [
                      Text('Minutes'),
                      _buildDropDown(
                          state.periodicDurationMinutes,
                          state.periodicDurationHours > 0
                              ? [0]
                              : [0, 15, 30, 45],
                          state.setPeriodicDurationMinutes,
                          true),
                    ],
                  )
                ],
              ),
            ],
          )),
        );
      }
    } else {
      widgets.add(new Center(
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            new Container(
                decoration: BoxDecoration(border: Border.all(width: 2)),
                child: new Column(
                  children: <Widget>[
                    Text('Minimum Delay'),
                    TimePickerSpinner(
                      isForce2Digits: true,
                      time: state.randomMinDateTime,
                      is24HourMode: true,
                      // spacing: 10,
                      minutesInterval: 5,
                      onTimeChange: state.setRandomMinDateTime,
                    ),
                  ],
                )),
            new Container(
                decoration: BoxDecoration(border: Border.all(width: 2)),
                child: new Column(
                  children: <Widget>[
                    Text('Maximum Delay'),
                    TimePickerSpinner(
                      isForce2Digits: true,
                      time: state.randomMaxDateTime,
                      // spacing: 10,
                      minutesInterval: 5,
                      onTimeChange: state.setRandomMaxDateTime,
                    ),
                  ],
                )),
          ],
        ),
      ));

      // Use this for Quiet Hours?
      // final format = DateFormat("hh:mm a");
      // widgets.addAll([
      //   Text('Basic time field (${format.pattern})'),
      //   DateTimeField(
      //     format: format,
      //     onShowPicker: (context, currentValue) async {
      //       final time = await showTimePicker(
      //         context: context,
      //         initialTime:
      //             TimeOfDay.fromDateTime(currentValue ?? DateTime.now()),
      //       );
      //       return DateTimeField.convert(time);
      //     },
      //   ),
      // ]);
    }
    return widgets;
  }

  final quietTimeDateFormat = DateFormat("hh:mm a");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Container(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _buildScheduleView(),
                ),
              ),
              Container(
                alignment: Alignment.topCenter,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text('Quiet Hours'),
                      new Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          Text('From: '),
                          SizedBox(
                              width: 80,
                              child: DateTimeField(
                                format: quietTimeDateFormat,
                                resetIcon: null,
                                onShowPicker: (context, currentValue) async {
                                  final time = await showTimePicker(
                                    context: context,
                                    // this will be state.___:
                                    initialTime: TimeOfDay.fromDateTime(
                                        currentValue ??
                                            DateTimeField.convert(TimeOfDay(
                                                hour: 21, minute: 0))),
                                  );
                                  return DateTimeField.convert(time);
                                },
                                initialValue: DateTimeField.convert(
                                    TimeOfDay(hour: 21, minute: 0)),
                              )),
                          Text('to: '),
                          SizedBox(
                              width: 80,
                              child: DateTimeField(
                                format: quietTimeDateFormat,
                                resetIcon: null,
                                onShowPicker: (context, currentValue) async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                        currentValue ?? DateTime.now()),
                                  );
                                  return DateTimeField.convert(time);
                                },
                                initialValue: DateTimeField.convert(
                                    TimeOfDay(hour: 9, minute: 0)),
                              )),
                        ],
                      ),
                    ]),
              ),
            ]),
      ),
    );
  }
}
