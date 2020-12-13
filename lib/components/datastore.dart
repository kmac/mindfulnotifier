import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:mindfulnotifier/components/schedule.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = Logger(printer: SimpleLogPrinter('datastore'));

class ScheduleDataStore extends GetxService {
  static const String enabledKey = 'enabled';
  static const String muteKey = 'mute';
  static const String vibrateKey = 'vibrate';

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
  static const String messageKey = 'message';
  static const String infoMessageKey = 'infoMessage';

  // defaults
  static const String defaultScheduleTypeStr = 'periodic';
  static const int defaultPeriodicHours = 1;
  static const int defaultPeriodicMinutes = 0;
  static const int defaultRandomMinHours = 0;
  static const int defaultRandomMinMinutes = 45;
  static const int defaultRandomMaxHours = 1;
  static const int defaultRandomMaxMinutes = 15;
  static const int defaultQuietHoursStartHour = 21;
  static const int defaultQuietHoursStartMinute = 0;
  static const int defaultQuietHoursEndHour = 9;
  static const int defaultQuietHoursEndMinute = 0;
  static const String defaultMessage = 'Not Enabled';
  static const String defaultInfoMessage = 'Uninitialized';

  static SharedPreferences _prefs;

  static ScheduleDataStore _instance;

  /// Public factory
  static Future<ScheduleDataStore> getInstance() async {
    if (_instance == null) {
      // Call the private constructor
      _instance = ScheduleDataStore._create();
      // ...initialization that requires async...
      await _instance._init();
    }
    // Return the fully initialized object
    return _instance;
  }

  /// Private constructor
  ScheduleDataStore._create() {
    logger.i("Creating DataStore");
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ScheduleDataStore._internal() {
  //   _instance = this;
  //   _init();
  // }
  // factory ScheduleDataStore() => _instance ?? ScheduleDataStore._internal();
  // void _init() async {
  //   _prefs = await SharedPreferences.getInstance();
  //   reload();
  // }

  @override
  void onInit() async {
    super.onInit();
  }

  void reload() async {
    await _prefs.reload();
  }

  void dumpToLogOne() {
    StringBuffer sb = StringBuffer("ScheduleDataStore:\n");
    for (String key in _prefs.getKeys()) {
      sb.write("$key=${_prefs.get(key)}\n");
    }
    logger.d(sb);
  }

  void dumpToLog() {
    logger.d("ScheduleDataStore:");
    for (String key in _prefs.getKeys()) {
      logger.d("$key=${_prefs.get(key)}");
    }
  }

  void setEnable(bool value) {
    _prefs.setBool(ScheduleDataStore.enabledKey, value);
  }

  bool getEnable() {
    if (!_prefs.containsKey(ScheduleDataStore.enabledKey)) {
      setEnable(false);
    }
    return (_prefs.getBool(ScheduleDataStore.enabledKey));
  }

  void setMute(bool value) {
    _prefs.setBool(ScheduleDataStore.muteKey, value);
  }

  bool getMute() {
    if (!_prefs.containsKey(ScheduleDataStore.muteKey)) {
      setMute(false);
    }
    return (_prefs.getBool(ScheduleDataStore.muteKey));
  }

  void setVibrate(bool value) {
    _prefs.setBool(ScheduleDataStore.vibrateKey, value);
  }

  bool getVibrate() {
    if (!_prefs.containsKey(ScheduleDataStore.vibrateKey)) {
      setVibrate(false);
    }
    return (_prefs.getBool(ScheduleDataStore.vibrateKey));
  }

  void setScheduleTypeStr(String value) {
    _prefs.setString(ScheduleDataStore.scheduleTypeKey, value);
  }

  String getScheduleTypeStr() {
    if (!_prefs.containsKey(ScheduleDataStore.scheduleTypeKey)) {
      setScheduleTypeStr(defaultScheduleTypeStr);
    }
    return (_prefs.getString(ScheduleDataStore.scheduleTypeKey));
  }

  void setPeriodicHours(int value) {
    _prefs.setInt(periodicHoursKey, value);
  }

  int getPeriodicHours() {
    if (!_prefs.containsKey(ScheduleDataStore.periodicHoursKey)) {
      setPeriodicHours(defaultPeriodicHours);
    }
    return (_prefs.getInt(ScheduleDataStore.periodicHoursKey));
  }

  void setPeriodicMinutes(int value) {
    _prefs.setInt(periodicMinutesKey, value);
  }

  int getPeriodicMinutes() {
    if (!_prefs.containsKey(ScheduleDataStore.periodicMinutesKey)) {
      setPeriodicMinutes(defaultPeriodicMinutes);
    }
    return (_prefs.getInt(ScheduleDataStore.periodicMinutesKey));
  }

  void setRandomMinHours(int value) {
    _prefs.setInt(randomMinHoursKey, value);
  }

  int getRandomMinHours() {
    if (!_prefs.containsKey(ScheduleDataStore.randomMinHoursKey)) {
      setRandomMinHours(defaultRandomMinHours);
    }
    return (_prefs.getInt(ScheduleDataStore.randomMinHoursKey));
  }

  void setRandomMinMinutes(int value) {
    _prefs.setInt(randomMinMinutesKey, value);
  }

  int getRandomMinMinutes() {
    if (!_prefs.containsKey(ScheduleDataStore.randomMinMinutesKey)) {
      setRandomMinMinutes(defaultRandomMinMinutes);
    }
    return (_prefs.getInt(ScheduleDataStore.randomMinMinutesKey));
  }

  void setRandomMaxHours(int value) {
    _prefs.setInt(randomMaxHoursKey, value);
  }

  int getRandomMaxHours() {
    if (!_prefs.containsKey(ScheduleDataStore.randomMaxHoursKey)) {
      setRandomMaxHours(defaultRandomMaxHours);
    }
    return (_prefs.getInt(ScheduleDataStore.randomMaxHoursKey));
  }

  void setRandomMaxMinutes(int value) {
    _prefs.setInt(randomMaxMinutesKey, value);
  }

  int getRandomMaxMinutes() {
    if (!_prefs.containsKey(ScheduleDataStore.randomMaxMinutesKey)) {
      setRandomMaxMinutes(defaultRandomMaxMinutes);
    }
    return (_prefs.getInt(ScheduleDataStore.randomMaxMinutesKey));
  }

  void setQuietHoursStartHour(int value) {
    _prefs.setInt(quietHoursStartHourKey, value);
  }

  int getQuietHoursStartHour() {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursStartHourKey)) {
      setQuietHoursStartHour(defaultQuietHoursStartHour);
    }
    return (_prefs.getInt(ScheduleDataStore.quietHoursStartHourKey));
  }

  void setQuietHoursStartMinute(int value) {
    _prefs.setInt(quietHoursStartMinuteKey, value);
  }

  int getQuietHoursStartMinute() {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursStartMinuteKey)) {
      setQuietHoursStartMinute(defaultQuietHoursStartMinute);
    }
    return (_prefs.getInt(ScheduleDataStore.quietHoursStartMinuteKey));
  }

  void setQuietHoursEndHour(int value) {
    _prefs.setInt(quietHoursEndHourKey, value);
  }

  int getQuietHoursEndHour() {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursEndHourKey)) {
      setQuietHoursEndHour(defaultQuietHoursEndHour);
    }
    return (_prefs.getInt(ScheduleDataStore.quietHoursEndHourKey));
  }

  void setQuietHoursEndMinute(int value) {
    _prefs.setInt(quietHoursEndMinuteKey, value);
  }

  int getQuietHoursEndMinute() {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursEndMinuteKey)) {
      setQuietHoursEndMinute(defaultQuietHoursEndMinute);
    }
    return (_prefs.getInt(ScheduleDataStore.quietHoursEndMinuteKey));
  }

  void setMessage(String value) {
    _prefs.setString(messageKey, value);
  }

  String getMessage() {
    if (!_prefs.containsKey(ScheduleDataStore.messageKey)) {
      setMessage(defaultMessage);
    }
    return (_prefs.getString(ScheduleDataStore.messageKey));
  }

  void setInfoMessage(String value) {
    _prefs.setString(infoMessageKey, value);
  }

  String getInfoMessage() {
    if (!_prefs.containsKey(ScheduleDataStore.infoMessageKey)) {
      setInfoMessage(defaultInfoMessage);
    }
    return (_prefs.getString(ScheduleDataStore.infoMessageKey));
  }

  DelegatedScheduler buildSchedulerDelegate(Scheduler scheduler) {
    print('Building scheduler delegate');
    var scheduleType;
    if (getScheduleTypeStr() == 'periodic') {
      scheduleType = ScheduleType.PERIODIC;
    } else {
      scheduleType = ScheduleType.RANDOM;
    }

    QuietHours quietHours = buildQuietHours();

    var delegate;
    if (scheduleType == ScheduleType.PERIODIC) {
      delegate = PeriodicScheduler(
          scheduler, quietHours, getPeriodicHours(), getPeriodicMinutes());
    } else {
      delegate = RandomScheduler(
          scheduler,
          quietHours,
          getRandomMinHours() * 60 + getRandomMinMinutes(),
          getRandomMaxHours() * 60 + getRandomMaxMinutes());
    }
    return delegate;
  }

  QuietHours buildQuietHours() {
    return new QuietHours(
        new TimeOfDay(
            hour: getQuietHoursStartHour(), minute: getQuietHoursStartMinute()),
        new TimeOfDay(
            hour: getQuietHoursEndHour(), minute: getQuietHoursEndMinute()));
  }
}
