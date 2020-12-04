import 'package:flutter/material.dart';
import 'package:mindfulnotifier/components/schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataStore {
  static const String scheduleTypeKey = 'scheduleType';
  static const String periodicHoursKey = 'periodicDurationHours';
  static const String periodicMinutesKey = 'periodicDurationMinutes';
  static const String randomMinHoursKey = 'randomMinHours';
  static const String randomMinMinutesKey = 'randomMinMinutes';
  static const String randomMaxHoursKey = 'randomMaxHours';
  static const String randomMaxMinutesKey = 'randomMaxMinutes';

  static const String quietHoursStartHourKey = 'quietHoursStartHour';
  static const String quietHoursStartMinuteKey = 'quietHoursStartMinute';
  static const String quietHoursEndHourKey = 'quietHoursEndHour';
  static const String quietHoursEndMinuteKey = 'quietHoursEndMinute';

  static SharedPreferences _prefs;

  /// Public factory
  static Future<DataStore> create() async {
    // Call the private constructor
    var component = DataStore._create();

    // ...initialization that requires async...
    await component._init();

    // Return the fully initialized object
    return component;
  }

  /// Private constructor
  DataStore._create() {
    print("Creating DataStore");
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Scheduler buildScheduler(var controller, String title) {
    print('Building scheduler');
    var scheduleType = ScheduleType.PERIODIC;
    if (_prefs.containsKey(scheduleTypeKey)) {
      if (_prefs.getString(scheduleTypeKey) == 'periodic') {
        scheduleType = ScheduleType.PERIODIC;
      } else {
        scheduleType = ScheduleType.RANDOM;
      }
    } else {
      _prefs.setString(scheduleTypeKey, scheduleType.toString());
    }

    QuietHours quietHours = buildQuietHours();

    if (scheduleType == ScheduleType.PERIODIC) {
      // PERIODIC
      var periodicHours = 1;
      var periodicMinutes = 0;
      if (_prefs.containsKey(periodicHoursKey)) {
        periodicHours = _prefs.getInt(periodicHoursKey);
      }
      if (_prefs.containsKey(periodicMinutesKey)) {
        periodicMinutes = _prefs.getInt(periodicMinutesKey);
      }
      return PeriodicScheduler(
          controller, periodicHours, periodicMinutes, quietHours, title);
    }

    // RANDOM
    var randomMinHours = 0;
    var randomMinMinutes = 45;
    var randomMaxHours = 1;
    var randomMaxMinutes = 30;
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
    return new RandomScheduler(
        controller,
        randomMinHours * 60 + randomMinMinutes,
        randomMaxHours * 60 + randomMaxMinutes,
        quietHours,
        title);
  }

  QuietHours buildQuietHours() {
    var quietHoursStartHour, quietHoursStartMinute;
    var quietHoursEndHour, quietHoursEndMinute;

    if (_prefs.containsKey(quietHoursStartHourKey)) {
      quietHoursStartHour = _prefs.getInt(quietHoursStartHourKey);
    }
    if (_prefs.containsKey(quietHoursStartMinuteKey)) {
      quietHoursStartMinute = _prefs.getInt(quietHoursStartMinuteKey);
    }
    if (_prefs.containsKey(quietHoursEndHourKey)) {
      quietHoursEndHour = _prefs.getInt(quietHoursEndHourKey);
    }
    if (_prefs.containsKey(quietHoursEndMinuteKey)) {
      quietHoursEndMinute = _prefs.getInt(quietHoursEndMinuteKey);
    }

    return new QuietHours(
        new TimeOfDay(hour: quietHoursStartHour, minute: quietHoursStartMinute),
        new TimeOfDay(hour: quietHoursEndHour, minute: quietHoursEndMinute));
  }
}
