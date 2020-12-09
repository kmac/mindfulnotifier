import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:date_format/date_format.dart';
import 'package:logger/logger.dart';

import 'package:mindfulnotifier/components/datastore.dart';
import 'package:mindfulnotifier/components/utils.dart';
import 'package:mindfulnotifier/screens/widgetview.dart';

var logger = Logger();

enum ScheduleType { periodic, random }

class SchedulesWidgetController extends GetxController {
  SharedPreferences _prefs;
  final scheduleType = ScheduleType.periodic.obs;
  final periodicHours = 1.obs;
  final periodicMinutes = 0.obs;
  final randomMinDateTime = DateTime.parse("1970-01-01 00:45:00Z").obs;
  final randomMaxDateTime = DateTime.parse("1970-01-01 01:30:00Z").obs;
  int randomMinHours = 0;
  int randomMinMinutes = 45;
  int randomMaxHours = 1;
  int randomMaxMinutes = 15;
  int quietHoursStartHour = 21;
  int quietHoursStartMinute = 0;
  int quietHoursEndHour = 9;
  int quietHoursEndMinute = 0;

  TextEditingController quietHoursStartTimeController = TextEditingController();
  TextEditingController quietHoursEndTimeController = TextEditingController();

  // UI event handlers, init code, etc goes here
  SchedulesWidgetController();

  DateTime _getDateTime(int hours, int minutes) {
    return DateTime.parse(
        "1970-01-01 ${timeNumToString(hours)}:${timeNumToString(minutes)}:00Z");
  }

  @override
  void onInit() {
    ever(scheduleType, handleScheduleType);
    ever(periodicHours, handlePeriodicHours);
    ever(periodicMinutes, handlePeriodicMinutes);
    ever(randomMinDateTime, handleRandomMinDateTime);
    ever(randomMaxDateTime, handleRandomMaxDateTime);

    loadPrefs();
    quietHoursStartTimeController.text = formatDate(
        DateTime(2020, 01, 1, quietHoursStartHour, quietHoursStartMinute),
        [hh, ':', nn, " ", am]).toString();
    quietHoursEndTimeController.text = formatDate(
        DateTime(2020, 01, 1, quietHoursEndHour, quietHoursEndMinute),
        [hh, ':', nn, " ", am]).toString();
    super.onInit();
  }

  void loadPrefs() async {
    logger.d("loadPrefs");
    _prefs = await SharedPreferences.getInstance();

    // scheduleType
    if (_prefs.containsKey(DataStore.scheduleTypeKey)) {
      if (_prefs.getString(DataStore.scheduleTypeKey) == 'periodic') {
        scheduleType.value = ScheduleType.periodic;
      } else {
        scheduleType.value = ScheduleType.random;
      }
    } else {
      _prefs.setString(DataStore.scheduleTypeKey, scheduleType.toString());
    }

    // periodicHours / periodicMinutes
    if (_prefs.containsKey(DataStore.periodicHoursKey)) {
      periodicHours.value = _prefs.getInt(DataStore.periodicHoursKey);
    } else {
      _prefs.setInt(DataStore.periodicHoursKey, periodicHours.value);
    }
    if (_prefs.containsKey(DataStore.periodicMinutesKey)) {
      periodicMinutes.value = _prefs.getInt(DataStore.periodicMinutesKey);
    } else {
      _prefs.setInt(DataStore.periodicMinutesKey, periodicMinutes.value);
    }

    if (_prefs.containsKey(DataStore.randomMinHoursKey)) {
      randomMinHours = _prefs.getInt(DataStore.randomMinHoursKey);
    }
    if (_prefs.containsKey(DataStore.randomMinMinutesKey)) {
      randomMinMinutes = _prefs.getInt(DataStore.randomMinMinutesKey);
    }
    if (_prefs.containsKey(DataStore.randomMaxHoursKey)) {
      randomMaxHours = _prefs.getInt(DataStore.randomMaxHoursKey);
    }
    if (_prefs.containsKey(DataStore.randomMaxMinutesKey)) {
      randomMaxMinutes = _prefs.getInt(DataStore.randomMaxMinutesKey);
    }
    randomMinDateTime.value = _getDateTime(randomMinHours, randomMinMinutes);
    randomMaxDateTime.value = _getDateTime(randomMaxHours, randomMaxMinutes);

    if (_prefs.containsKey(DataStore.quietHoursStartHourKey)) {
      quietHoursStartHour = _prefs.getInt(DataStore.quietHoursStartHourKey);
    }
    if (_prefs.containsKey(DataStore.quietHoursStartMinuteKey)) {
      quietHoursStartMinute = _prefs.getInt(DataStore.quietHoursStartMinuteKey);
    }
    setQuietHoursStart(
        TimeOfDay(hour: quietHoursStartHour, minute: quietHoursStartMinute));
    if (_prefs.containsKey(DataStore.quietHoursEndHourKey)) {
      quietHoursEndHour = _prefs.getInt(DataStore.quietHoursEndHourKey);
    }
    if (_prefs.containsKey(DataStore.quietHoursEndMinuteKey)) {
      quietHoursEndMinute = _prefs.getInt(DataStore.quietHoursEndMinuteKey);
    }
    setQuietHoursEnd(
        TimeOfDay(hour: quietHoursEndHour, minute: quietHoursEndMinute));
  }

  void handleScheduleType(ScheduleType t) {
    if (t == ScheduleType.periodic) {
      _prefs.setString(DataStore.scheduleTypeKey, 'periodic');
    } else {
      _prefs.setString(DataStore.scheduleTypeKey, 'random');
    }
  }

  void handlePeriodicHours(int hours) {
    _prefs.setInt(DataStore.periodicHoursKey, hours);
    if (hours > 0) {
      periodicMinutes.value = 0;
    }
  }

  void handlePeriodicMinutes(int minutes) {
    _prefs.setInt(DataStore.periodicMinutesKey, minutes);
  }

  void handleRandomMinDateTime(DateTime time) {
    _prefs.setInt(DataStore.randomMinHoursKey, time.hour);
    _prefs.setInt(DataStore.randomMinMinutesKey, time.minute);
  }

  void handleRandomMaxDateTime(DateTime time) {
    _prefs.setInt(DataStore.randomMaxHoursKey, time.hour);
    _prefs.setInt(DataStore.randomMaxMinutesKey, time.minute);
  }

  void setQuietHoursStart(TimeOfDay time) {
    quietHoursStartHour = time.hour;
    quietHoursStartMinute = time.minute;
    quietHoursStartTimeController.text = formatDate(
        DateTime(2019, 08, 1, quietHoursStartHour, quietHoursStartMinute),
        [hh, ':', nn, " ", am]).toString();
    _prefs.setInt(DataStore.quietHoursStartHourKey, quietHoursStartHour);
    _prefs.setInt(DataStore.quietHoursStartMinuteKey, quietHoursStartMinute);
  }

  void setQuietHoursEnd(TimeOfDay time) {
    quietHoursEndHour = time.hour;
    quietHoursEndMinute = time.minute;
    quietHoursEndTimeController.text = formatDate(
        DateTime(2019, 08, 1, quietHoursEndHour, quietHoursEndMinute),
        [hh, ':', nn, " ", am]).toString();
    _prefs.setInt(DataStore.quietHoursEndHourKey, quietHoursEndHour);
    _prefs.setInt(DataStore.quietHoursEndMinuteKey, quietHoursEndMinute);
  }
}

class SchedulesWidget extends StatelessWidget {
  final SchedulesWidgetController controller =
      Get.put(SchedulesWidgetController());

  DropdownButton<int> _buildDropDown(
      int dropdownValue, List<int> allowedValues, Function onChangedFunc,
      [bool useTwoDigits = false]) {
    return DropdownButton<int>(
      value: dropdownValue,
      // icon: Icon(Icons.arrow_downward),
      // iconSize: 24,
      elevation: 16,
      // style: TextStyle(color: Colors.deepPurple, fontSize: 20),
      style: TextStyle(color: Colors.black54, fontSize: 30),
      underline: Container(height: 2, color: Colors.black54
          // color: Colors.deepPurpleAccent,
          ),
      onChanged: onChangedFunc,
      items: allowedValues.map<DropdownMenuItem<int>>((int value) {
        return DropdownMenuItem<int>(
          value: value,
          child: Text(useTwoDigits ? timeNumToString(value) : value.toString()),
        );
      })?.toList(),
    );
  }

  List<Widget> _buildScheduleView(BuildContext context) {
    List<Widget> widgets = [
      Text('Schedule Type', style: Theme.of(context).textTheme.headline5),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        const Text('Periodic'),
        Radio(
          value: ScheduleType.periodic,
          groupValue: controller.scheduleType.value,
          onChanged: (value) => controller.scheduleType.value = value,
        ),
        const Text('Random'),
        Radio(
          value: ScheduleType.random,
          groupValue: controller.scheduleType.value,
          onChanged: (value) => controller.scheduleType.value = value,
        ),
      ])
    ];
    if (controller.scheduleType.value == ScheduleType.periodic) {
      widgets.add(
        new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
                // padding: EdgeInsets.all(24.0),
                padding: EdgeInsets.fromLTRB(30, 0, 30, 20),
                child: Text(
                    'Choose the reminder period. ' +
                        'Reminders are aligned to the top of hour, ' +
                        'unless the period is shorter than one hour, in which' +
                        ' case the granularity is 15 minutes.',
                    style: TextStyle(
                      fontWeight: FontWeight.w300, /*fontSize: 12*/
                    ),
                    softWrap: true)),
            new Container(
                decoration: BoxDecoration(color: Colors.grey[200]),
                padding: EdgeInsets.all(8),
                width: 200,
                child: new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    new Column(
                      children: [
                        Text('Hours'),
                        _buildDropDown(
                            controller.periodicHours.value,
                            [0, 1, 2, 3, 4, 8, 12],
                            (value) => controller.periodicHours.value = value,
                            true),
                      ],
                    ),
                    Text(' : '),
                    new Column(
                      children: [
                        Text('Minutes'),
                        _buildDropDown(
                            controller.periodicMinutes.value,
                            controller.periodicHours.value > 0
                                ? [0]
                                : [0, 15, 30],
                            (value) => controller.periodicMinutes.value = value,
                            true),
                      ],
                    )
                  ],
                )),
          ],
        ),
      );
    } else {
      widgets.add(new Center(
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            new Container(
                decoration: BoxDecoration(color: Colors.grey[200]),
                padding: EdgeInsets.all(8),
                child: new Column(
                  children: <Widget>[
                    Text('Minimum Delay',
                        style: Theme.of(context).textTheme.bodyText1),
                    TimePickerSpinner(
                      isForce2Digits: true,
                      time: controller.randomMinDateTime.value,
                      is24HourMode: true,
                      spacing: 20,
                      minutesInterval: 5,
                      onTimeChange: (value) =>
                          controller.randomMinDateTime.value = value,
                    ),
                  ],
                )),
            new Container(
                decoration: BoxDecoration(color: Colors.grey[200]),
                padding: EdgeInsets.all(8),
                child: new Column(
                  children: <Widget>[
                    Text('Maximum Delay',
                        style: Theme.of(context).textTheme.bodyText1),
                    TimePickerSpinner(
                      isForce2Digits: true,
                      time: controller.randomMaxDateTime.value,
                      // spacing: 10,
                      minutesInterval: 5,
                      onTimeChange: (value) =>
                          controller.randomMaxDateTime.value = value,
                    ),
                  ],
                )),
          ],
        ),
      ));
    }
    return widgets;
  }

  Future<Null> _selectQuietHoursStartTime(BuildContext context) async {
    var selectedTime = TimeOfDay(
        hour: controller.quietHoursStartHour,
        minute: controller.quietHoursStartMinute);
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      controller.setQuietHoursStart(picked);
      selectedTime = picked;
    }
  }

  Future<Null> _selectQuietHoursEndTime(BuildContext context) async {
    var selectedTime = TimeOfDay(
        hour: controller.quietHoursEndHour,
        minute: controller.quietHoursEndMinute);
    final TimeOfDay picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );
    if (picked != null) {
      controller.setQuietHoursEnd(picked);
      selectedTime = picked;
    }
  }

  List<Widget> _buildQuietHoursView(BuildContext context) {
    List<Widget> widgets = [
      Text('Quiet Hours', style: Theme.of(context).textTheme.headline5),
      new Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          InkWell(
              onTap: () {
                _selectQuietHoursStartTime(context);
              },
              child: Container(
                  width: 140,
                  margin: EdgeInsets.only(top: 30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  child: TextFormField(
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                    enabled: false,
                    keyboardType: TextInputType.text,
                    controller: controller.quietHoursStartTimeController,
                    decoration: InputDecoration(
                        disabledBorder:
                            UnderlineInputBorder(borderSide: BorderSide.none),
                        labelText: 'Start Time',
                        contentPadding: EdgeInsets.all(5)),
                  ))),
          Text('to: '),
          InkWell(
              onTap: () {
                _selectQuietHoursEndTime(context);
              },
              child: Container(
                  width: 140,
                  // height: _height / 9,
                  margin: EdgeInsets.only(top: 30),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  child: TextFormField(
                    style: TextStyle(fontSize: 20),
                    textAlign: TextAlign.center,
                    enabled: false,
                    keyboardType: TextInputType.text,
                    controller: controller.quietHoursEndTimeController,
                    decoration: InputDecoration(
                        disabledBorder:
                            UnderlineInputBorder(borderSide: BorderSide.none),
                        labelText: 'End Time',
                        contentPadding: EdgeInsets.all(5)),
                  ))),
        ],
      ),
    ];
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Configure schedule'),
      ),
      body: Center(
          child: Obx(() => Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Container(
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _buildScheduleView(context),
                      ),
                    ),
                    Container(
                        alignment: Alignment.topCenter,
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _buildQuietHoursView(context))),
                  ]))),
    );
  }
}
