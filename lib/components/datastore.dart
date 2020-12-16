import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = Logger(printer: SimpleLogPrinter('datastore'));

abstract class ScheduleDataStoreBase {
  bool get enabled;
  bool get mute;

  bool get vibrate;
  String get scheduleTypeStr;
  int get periodicHours;
  int get periodicMinutes;
  int get randomMinHours;
  int get randomMinMinutes;
  int get randomMaxHours;
  int get randomMaxMinutes;
  int get quietHoursStartHour;
  int get quietHoursStartMinute;
  int get quietHoursEndHour;
  int get quietHoursEndMinute;
  String get message;
  String get infoMessage;
  String get controlMessage;
}

class ScheduleDataStoreRO implements ScheduleDataStoreBase {
  final bool _enabled;
  final bool _mute;
  final bool _vibrate;
  final String _scheduleTypeStr;
  final int _periodicHours;
  final int _periodicMinutes;
  final int _randomMinHours;
  final int _randomMinMinutes;
  final int _randomMaxHours;
  final int _randomMaxMinutes;
  final int _quietHoursStartHour;
  final int _quietHoursStartMinute;
  final int _quietHoursEndHour;
  final int _quietHoursEndMinute;
  final String _message;
  final String _infoMessage;
  final String _heartbeatMessage;

  ScheduleDataStoreRO(
      this._enabled,
      this._mute,
      this._vibrate,
      this._scheduleTypeStr,
      this._periodicHours,
      this._periodicMinutes,
      this._randomMinHours,
      this._randomMinMinutes,
      this._randomMaxHours,
      this._randomMaxMinutes,
      this._quietHoursStartHour,
      this._quietHoursStartMinute,
      this._quietHoursEndHour,
      this._quietHoursEndMinute,
      this._message,
      this._infoMessage,
      this._heartbeatMessage);

  bool get enabled {
    return _enabled;
  }

  bool get mute {
    return _mute;
  }

  bool get vibrate {
    return _vibrate;
  }

  String get scheduleTypeStr {
    return _scheduleTypeStr;
  }

  int get periodicHours {
    return _periodicHours;
  }

  int get periodicMinutes {
    return _periodicMinutes;
  }

  int get randomMinHours {
    return _randomMinHours;
  }

  int get randomMinMinutes {
    return _randomMinMinutes;
  }

  int get randomMaxHours {
    return _randomMaxHours;
  }

  int get randomMaxMinutes {
    return _randomMaxMinutes;
  }

  int get quietHoursStartHour {
    return _quietHoursStartHour;
  }

  int get quietHoursStartMinute {
    return _quietHoursStartMinute;
  }

  int get quietHoursEndHour {
    return _quietHoursEndHour;
  }

  int get quietHoursEndMinute {
    return _quietHoursEndMinute;
  }

  String get message {
    return _message;
  }

  String get infoMessage {
    return _infoMessage;
  }

  String get controlMessage {
    return _heartbeatMessage;
  }
}

class ScheduleDataStore implements ScheduleDataStoreBase {
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
  static const String controlMessageKey = 'controlMessage';

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
  static const String defaultControlMessage = '';

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
    logger.i("Initializing SharedPreferences");
    _prefs = await SharedPreferences.getInstance();
  }

  void reload() async {
    await _prefs.reload();
  }

  void dumpToLog() {
    logger.d("ScheduleDataStore:");
    for (String key in _prefs.getKeys()) {
      logger.d("$key=${_prefs.get(key)}");
    }
  }

  set enabled(bool value) {
    _prefs.setBool(ScheduleDataStore.enabledKey, value);
  }

  @override
  bool get enabled {
    if (!_prefs.containsKey(ScheduleDataStore.enabledKey)) {
      enabled = false;
    }
    return _prefs.getBool(ScheduleDataStore.enabledKey);
  }

  set mute(bool value) {
    _prefs.setBool(ScheduleDataStore.muteKey, value);
  }

  @override
  bool get mute {
    if (!_prefs.containsKey(ScheduleDataStore.muteKey)) {
      mute = false;
    }
    return _prefs.getBool(ScheduleDataStore.muteKey);
  }

  set vibrate(bool value) {
    _prefs.setBool(ScheduleDataStore.vibrateKey, value);
  }

  @override
  bool get vibrate {
    if (!_prefs.containsKey(ScheduleDataStore.vibrateKey)) {
      vibrate = false;
    }
    return _prefs.getBool(ScheduleDataStore.vibrateKey);
  }

  set scheduleTypeStr(String value) {
    _prefs.setString(ScheduleDataStore.scheduleTypeKey, value);
  }

  @override
  String get scheduleTypeStr {
    if (!_prefs.containsKey(ScheduleDataStore.scheduleTypeKey)) {
      scheduleTypeStr = defaultScheduleTypeStr;
    }
    return _prefs.getString(ScheduleDataStore.scheduleTypeKey);
  }

  set periodicHours(int value) {
    _prefs.setInt(periodicHoursKey, value);
  }

  @override
  int get periodicHours {
    if (!_prefs.containsKey(ScheduleDataStore.periodicHoursKey)) {
      periodicHours = defaultPeriodicHours;
    }
    return _prefs.getInt(ScheduleDataStore.periodicHoursKey);
  }

  set periodicMinutes(int value) {
    _prefs.setInt(periodicMinutesKey, value);
  }

  @override
  int get periodicMinutes {
    if (!_prefs.containsKey(ScheduleDataStore.periodicMinutesKey)) {
      periodicMinutes = defaultPeriodicMinutes;
    }
    return _prefs.getInt(ScheduleDataStore.periodicMinutesKey);
  }

  set randomMinHours(int value) {
    _prefs.setInt(randomMinHoursKey, value);
  }

  @override
  int get randomMinHours {
    if (!_prefs.containsKey(ScheduleDataStore.randomMinHoursKey)) {
      randomMinHours = defaultRandomMinHours;
    }
    return _prefs.getInt(ScheduleDataStore.randomMinHoursKey);
  }

  set randomMinMinutes(int value) {
    _prefs.setInt(randomMinMinutesKey, value);
  }

  @override
  int get randomMinMinutes {
    if (!_prefs.containsKey(ScheduleDataStore.randomMinMinutesKey)) {
      randomMinMinutes = defaultRandomMinMinutes;
    }
    return _prefs.getInt(ScheduleDataStore.randomMinMinutesKey);
  }

  set randomMaxHours(int value) {
    _prefs.setInt(randomMaxHoursKey, value);
  }

  @override
  int get randomMaxHours {
    if (!_prefs.containsKey(ScheduleDataStore.randomMaxHoursKey)) {
      randomMaxHours = defaultRandomMaxHours;
    }
    return _prefs.getInt(ScheduleDataStore.randomMaxHoursKey);
  }

  set randomMaxMinutes(int value) {
    _prefs.setInt(randomMaxMinutesKey, value);
  }

  @override
  int get randomMaxMinutes {
    if (!_prefs.containsKey(ScheduleDataStore.randomMaxMinutesKey)) {
      randomMaxMinutes = defaultRandomMaxMinutes;
    }
    return _prefs.getInt(ScheduleDataStore.randomMaxMinutesKey);
  }

  set quietHoursStartHour(int value) {
    _prefs.setInt(quietHoursStartHourKey, value);
  }

  @override
  int get quietHoursStartHour {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursStartHourKey)) {
      quietHoursStartHour = defaultQuietHoursStartHour;
    }
    return _prefs.getInt(ScheduleDataStore.quietHoursStartHourKey);
  }

  set quietHoursStartMinute(int value) {
    _prefs.setInt(quietHoursStartMinuteKey, value);
  }

  @override
  int get quietHoursStartMinute {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursStartMinuteKey)) {
      quietHoursStartMinute = defaultQuietHoursStartMinute;
    }
    return _prefs.getInt(ScheduleDataStore.quietHoursStartMinuteKey);
  }

  set quietHoursEndHour(int value) {
    _prefs.setInt(quietHoursEndHourKey, value);
  }

  @override
  int get quietHoursEndHour {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursEndHourKey)) {
      quietHoursEndHour = defaultQuietHoursEndHour;
    }
    return _prefs.getInt(ScheduleDataStore.quietHoursEndHourKey);
  }

  set quietHoursEndMinute(int value) {
    _prefs.setInt(quietHoursEndMinuteKey, value);
  }

  @override
  int get quietHoursEndMinute {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursEndMinuteKey)) {
      quietHoursEndMinute = defaultQuietHoursEndMinute;
    }
    return _prefs.getInt(ScheduleDataStore.quietHoursEndMinuteKey);
  }

  set message(String value) {
    _prefs.setString(messageKey, value);
  }

  @override
  String get message {
    if (!_prefs.containsKey(ScheduleDataStore.messageKey)) {
      message = defaultMessage;
    }
    return _prefs.getString(ScheduleDataStore.messageKey);
  }

  set infoMessage(String value) {
    _prefs.setString(infoMessageKey, value);
  }

  @override
  String get infoMessage {
    if (!_prefs.containsKey(ScheduleDataStore.infoMessageKey)) {
      infoMessage = defaultInfoMessage;
    }
    return _prefs.getString(ScheduleDataStore.infoMessageKey);
  }

  set controlMessage(String value) {
    _prefs.setString(controlMessageKey, value);
  }

  @override
  String get controlMessage {
    if (!_prefs.containsKey(ScheduleDataStore.controlMessageKey)) {
      controlMessage = defaultControlMessage;
    }
    return _prefs.getString(ScheduleDataStore.controlMessageKey);
  }

  ScheduleDataStoreRO getScheduleDataStoreRO() {
    return ScheduleDataStoreRO(
        enabled,
        mute,
        vibrate,
        scheduleTypeStr,
        periodicHours,
        periodicMinutes,
        randomMinHours,
        randomMinMinutes,
        randomMaxHours,
        randomMaxMinutes,
        quietHoursStartHour,
        quietHoursStartMinute,
        quietHoursEndHour,
        quietHoursEndMinute,
        message,
        infoMessage,
        controlMessage);
  }
}
