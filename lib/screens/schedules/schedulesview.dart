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
  var periodicHoursKey = 'periodicDurationHours';
  var periodicMinutesKey = 'periodicDurationMinutes';
  var randomMinHoursKey = 'randomMinHours';
  var randomMinMinutesKey = 'randomMinMinutes';
  var randomMaxHoursKey = 'randomMaxHours';
  var randomMaxMinutesKey = 'randomMaxMinutes';

  var quietHoursStartHourKey = 'quietHoursStartHour';
  var quietHoursStartMinuteKey = 'quietHoursStartMinute';
  var quietHoursEndHourKey = 'quietHoursEndHour';
  var quietHoursEndMinuteKey = 'quietHoursEndMinute';

  SharedPreferences _prefs;
  ScheduleType scheduleType = ScheduleType.periodic;
  int periodicHours = 1;
  int periodicMinutes = 0;

  int randomMinHours = 0;
  int randomMinMinutes = 45;
  int randomMaxHours = 1;
  int randomMaxMinutes = 15;
  DateTime randomMinDateTime = DateTime.parse("1970-01-01 00:45:00Z");
  DateTime randomMaxDateTime = DateTime.parse("1970-01-01 01:30:00Z");

  int quietHoursStartHour = 21;
  int quietHoursStartMinute = 0;
  int quietHoursEndHour = 9;
  int quietHoursEndMinute = 0;

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

    // periodicHours / periodicMinutes
    if (_prefs.containsKey(periodicHoursKey)) {
      periodicHours = _prefs.getInt(periodicHoursKey);
    } else {
      _prefs.setInt(periodicHoursKey, periodicHours);
    }
    if (_prefs.containsKey(periodicMinutesKey)) {
      periodicMinutes = _prefs.getInt(periodicMinutesKey);
    } else {
      _prefs.setInt(periodicMinutesKey, periodicMinutes);
    }

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

    if (_prefs.containsKey(quietHoursStartHourKey)) {
      quietHoursStartHour = _prefs.getInt(quietHoursStartHourKey);
    }
    if (_prefs.containsKey(quietHoursStartMinuteKey)) {
      quietHoursStartMinute = _prefs.getInt(quietHoursStartMinuteKey);
    }
    setQuietHoursStart(DateTimeField.convert(
        TimeOfDay(hour: quietHoursStartHour, minute: quietHoursStartMinute)));
    if (_prefs.containsKey(quietHoursEndHourKey)) {
      quietHoursEndHour = _prefs.getInt(quietHoursEndHourKey);
    }
    if (_prefs.containsKey(quietHoursEndMinuteKey)) {
      quietHoursEndMinute = _prefs.getInt(quietHoursEndMinuteKey);
    }
    setQuietHoursEnd(DateTimeField.convert(
        TimeOfDay(hour: quietHoursEndHour, minute: quietHoursEndMinute)));
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

  void setPeriodicHours(int hours) {
    _prefs.setInt(periodicHoursKey, hours);
    setState(() {
      periodicHours = hours;
    });
    if (hours > 0) {
      setPeriodicMinutes(0);
    }
  }

  void setPeriodicMinutes(int minutes) {
    _prefs.setInt(periodicMinutesKey, minutes);
    setState(() {
      periodicMinutes = minutes;
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

  void setQuietHoursStart(DateTime time) {
    print("setQuietHoursStart: $time");
    _prefs.setInt(quietHoursStartHourKey, time.hour);
    _prefs.setInt(quietHoursStartMinuteKey, time.minute);
    setState(() {
      quietHoursStartHour = time.hour;
      quietHoursStartMinute = time.minute;
    });
  }

  void setQuietHoursEnd(DateTime time) {
    print("setQuietHoursEnd: $time");
    _prefs.setInt(quietHoursEndHourKey, time.hour);
    _prefs.setInt(quietHoursEndMinuteKey, time.minute);
    setState(() {
      quietHoursEndHour = time.hour;
      quietHoursEndMinute = time.minute;
    });
  }
}

class _SchedulesWidgetView
    extends WidgetView<SchedulesWidget, SchedulesWidgetController> {
  _SchedulesWidgetView(SchedulesWidgetController state) : super(state);

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
                    _buildDropDown(state.periodicHours, [0, 1, 2, 3, 4, 8, 12],
                        state.setPeriodicHours),
                  ],
                ),
                Text(':'),
                new Column(
                  children: [
                    Text('Minutes'),
                    _buildDropDown(
                        state.periodicMinutes,
                        state.periodicHours > 0 ? [0] : [0, 15, 30, 45],
                        state.setPeriodicMinutes,
                        true),
                  ],
                )
              ],
            ),
          ],
        )),
      );
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
                                onChanged: state.setQuietHoursStart,
                                onShowPicker: (context, currentValue) async {
                                  final time = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                        // currentValue ??
                                        DateTimeField.convert(TimeOfDay(
                                            hour: state.quietHoursStartHour,
                                            minute:
                                                state.quietHoursStartMinute))),
                                  );
                                  return DateTimeField.convert(time);
                                },
                                initialValue: DateTimeField.convert(TimeOfDay(
                                    hour: state.quietHoursStartHour,
                                    minute: state.quietHoursStartMinute)),
                              )),
                          Text('to: '),
                          SizedBox(
                              width: 80,
                              child: DateTimeField(
                                format: quietTimeDateFormat,
                                resetIcon: null,
                                onChanged: state.setQuietHoursEnd,
                                onShowPicker: (context, currentValue) async {
                                  final time = await showTimePicker(
                                    context: context,

                                    // bug is either with this:
                                    initialTime: TimeOfDay.fromDateTime(
                                        // currentValue ??
                                        DateTimeField.convert(TimeOfDay(
                                            hour: state.quietHoursEndHour,
                                            minute:
                                                state.quietHoursEndMinute))),
                                  );
                                  return DateTimeField.convert(time);
                                },
                                // or this:
                                initialValue: DateTimeField.convert(TimeOfDay(
                                    hour: state.quietHoursEndHour,
                                    minute: state.quietHoursEndMinute)),
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
