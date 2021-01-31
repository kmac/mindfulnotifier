import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindfulnotifier/components/logging.dart';

var logger = createLogger('datastore');

abstract class ScheduleDataStoreBase {
  bool get enabled;
  bool get mute;
  bool get vibrate;
  bool get useBackgroundService;
  bool get useStickyNotification;
  bool get includeDebugInfo;
  String get scheduleTypeStr;
  int get periodicHours;
  int get periodicMinutes;
  int get randomMinMinutes;
  int get randomMaxMinutes;
  int get quietHoursStartHour;
  int get quietHoursStartMinute;
  int get quietHoursEndHour;
  int get quietHoursEndMinute;
  bool get notifyQuietHours;
  String get reminderMessage;
  String get infoMessage;
  String get controlMessage;
  String get theme;
  String get bellId;
  String get customBellPath;
}

class ScheduleDataStoreRO implements ScheduleDataStoreBase {
  final bool _enabled;
  final bool _mute;
  final bool _vibrate;
  final bool _useBackgroundService;
  final bool _useStickyNotification;
  final bool _includeDebugInfo;
  final String _scheduleTypeStr;
  final int _periodicHours;
  final int _periodicMinutes;
  final int _randomMinMinutes;
  final int _randomMaxMinutes;
  final int _quietHoursStartHour;
  final int _quietHoursStartMinute;
  final int _quietHoursEndHour;
  final int _quietHoursEndMinute;
  final bool _notifyQuietHours;
  final String _reminderMessage;
  final String _infoMessage;
  final String _controlMessage;
  final String _theme;
  final String _bellId;
  final String _customBellPath;

  ScheduleDataStoreRO(
      this._enabled,
      this._mute,
      this._vibrate,
      this._useBackgroundService,
      this._useStickyNotification,
      this._includeDebugInfo,
      this._scheduleTypeStr,
      this._periodicHours,
      this._periodicMinutes,
      this._randomMinMinutes,
      this._randomMaxMinutes,
      this._quietHoursStartHour,
      this._quietHoursStartMinute,
      this._quietHoursEndHour,
      this._quietHoursEndMinute,
      this._notifyQuietHours,
      this._reminderMessage,
      this._infoMessage,
      this._controlMessage,
      this._theme,
      this._bellId,
      this._customBellPath);

  bool get enabled {
    return _enabled;
  }

  bool get mute {
    return _mute;
  }

  bool get vibrate {
    return _vibrate;
  }

  bool get useBackgroundService {
    return _useBackgroundService;
  }

  bool get useStickyNotification {
    return _useStickyNotification;
  }

  bool get includeDebugInfo {
    return _includeDebugInfo;
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

  int get randomMinMinutes {
    return _randomMinMinutes;
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

  bool get notifyQuietHours {
    return _notifyQuietHours;
  }

  String get reminderMessage {
    return _reminderMessage;
  }

  String get infoMessage {
    return _infoMessage;
  }

  String get controlMessage {
    return _controlMessage;
  }

  String get theme {
    return _theme;
  }

  String get bellId {
    return _bellId;
  }

  String get customBellPath {
    return _customBellPath;
  }
}

class ScheduleDataStore implements ScheduleDataStoreBase {
  static const String enabledKey = 'enabled';
  static const String muteKey = 'mute';
  static const String vibrateKey = 'vibrate';
  static const String useBackgroundServiceKey = 'useBackgroundService';
  static const String useStickyNotificationKey = 'useStickyNotification';
  static const String includeDebugInfoKey = 'includeDebugInfoKey';
  static const String scheduleTypeKey = 'scheduleType';
  static const String periodicHoursKey = 'periodicDurationHours';
  static const String periodicMinutesKey = 'periodicDurationMinutes';
  static const String randomMinMinutesKey = 'randomMinMinutes';
  static const String randomMaxMinutesKey = 'randomMaxMinutes';
  static const String quietHoursStartHourKey = 'quietHoursStartHour';
  static const String quietHoursStartMinuteKey = 'quietHoursStartMinute';
  static const String quietHoursEndHourKey = 'quietHoursEndHour';
  static const String quietHoursEndMinuteKey = 'quietHoursEndMinute';
  static const String notifyQuietHoursKey = 'notifyQuietHours';
  static const String reminderMessageKey = 'reminderMessage';
  static const String infoMessageKey = 'infoMessage';
  static const String controlMessageKey = 'controlMessage';
  static const String themeKey = 'theme';
  static const String bellIdKey = 'bellId';
  static const String customBellPathKey = 'customBellPath';

  // defaults
  static const bool defaultUseBackgroundService = false;
  static const String defaultScheduleTypeStr = 'periodic';
  static const int defaultPeriodicHours = 1;
  static const int defaultPeriodicMinutes = 0;
  static const int defaultRandomMinMinutes = 45;
  static const int defaultRandomMaxMinutes = 60;
  static const int defaultQuietHoursStartHour = 21;
  static const int defaultQuietHoursStartMinute = 0;
  static const int defaultQuietHoursEndHour = 9;
  static const int defaultQuietHoursEndMinute = 0;
  static const bool defaultNotifyQuietHours = true;
  static const String defaultReminderMessage = 'Not Enabled';
  static const String defaultInfoMessage = 'Uninitialized';
  static const String defaultControlMessage = '';
  static const String defaultTheme = 'Default';
  static const String defaultBellId = 'bell1';
  static const String defaultCustomBellPath = '';

  static SharedPreferences _prefs;
  static ScheduleDataStore _instance;

  /// Public factory
  static Future<ScheduleDataStore> getInstance() async {
    if (_instance == null) {
      _instance = ScheduleDataStore._create();
      await _instance._init();
    }
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

  void backup(File backupFile) {
    var jsonData = _toJson();
    logger.d('backup, tofile:${backupFile.path}: $jsonData');
    backupFile.writeAsStringSync(_toJson(), flush: true);
  }

  void restore(File backupFile) {
    String jsonData = backupFile.readAsStringSync();
    logger.d('restore, file=${backupFile.path}: $jsonData');
    Map<String, dynamic> jsonMap = json.decoder.convert(jsonData);
    _initFromJson(jsonMap);
  }

  String _toJson() {
    Map<String, dynamic> toMap = Map();
    for (var key in _prefs.getKeys()) {
      toMap[key] = _prefs.get(key);
    }
    return json.encoder.convert(toMap);
  }

  void _initFromJson(Map<String, dynamic> jsonMap) async {
    //json.decoder.convert(input)
    for (var key in jsonMap.keys) {
      setSync(key, jsonMap[key]);
    }
  }

  void dumpToLog() {
    logger.d("ScheduleDataStore:");
    for (String key in _prefs.getKeys()) {
      logger.d("$key=${_prefs.get(key)}");
    }
  }

  Future<void> setSync(String key, dynamic val) async {
    if (val is bool) {
      await _prefs.setBool(key, val);
    } else if (val is int) {
      await _prefs.setInt(key, val);
    } else if (val is double) {
      await _prefs.setDouble(key, val);
    } else if (val is String) {
      await _prefs.setString(key, val);
    } else if (val is List) {
      // For restore:
      if (val is List<dynamic>) {
        List<String> newlist = List();
        for (dynamic newval in val) {
          newlist.add("$newval");
        }
        await _prefs.setStringList(key, newlist);
      } else {
        await _prefs.setStringList(key, val);
      }
    } else {
      logger.e(
          "Unsupported runtimeType: key=$key, value=$val, val.runtimeType=${val.runtimeType}");
    }
  }

  set enabled(bool value) {
    setSync(ScheduleDataStore.enabledKey, value);
  }

  @override
  bool get enabled {
    if (!_prefs.containsKey(ScheduleDataStore.enabledKey)) {
      enabled = false;
    }
    return _prefs.getBool(ScheduleDataStore.enabledKey);
  }

  set mute(bool value) {
    setSync(ScheduleDataStore.muteKey, value);
  }

  @override
  bool get mute {
    if (!_prefs.containsKey(ScheduleDataStore.muteKey)) {
      mute = false;
    }
    return _prefs.getBool(ScheduleDataStore.muteKey);
  }

  set vibrate(bool value) {
    setSync(ScheduleDataStore.vibrateKey, value);
  }

  @override
  bool get vibrate {
    if (!_prefs.containsKey(ScheduleDataStore.vibrateKey)) {
      vibrate = false;
    }
    return _prefs.getBool(ScheduleDataStore.vibrateKey);
  }

  set useBackgroundService(bool value) {
    setSync(ScheduleDataStore.useBackgroundServiceKey, value);
  }

  @override
  bool get useBackgroundService {
    if (!_prefs.containsKey(ScheduleDataStore.useBackgroundServiceKey)) {
      useBackgroundService = false;
    }
    return _prefs.getBool(ScheduleDataStore.useBackgroundServiceKey);
  }

  set includeDebugInfo(bool value) {
    setSync(ScheduleDataStore.includeDebugInfoKey, value);
  }

  @override
  bool get useStickyNotification {
    if (!_prefs.containsKey(ScheduleDataStore.useStickyNotificationKey)) {
      useStickyNotification = true;
    }
    return _prefs.getBool(ScheduleDataStore.useStickyNotificationKey);
  }

  set useStickyNotification(bool value) {
    setSync(ScheduleDataStore.useStickyNotificationKey, value);
  }

  @override
  bool get includeDebugInfo {
    if (!_prefs.containsKey(ScheduleDataStore.includeDebugInfoKey)) {
      includeDebugInfo = false;
    }
    return _prefs.getBool(ScheduleDataStore.includeDebugInfoKey);
  }

  set scheduleTypeStr(String value) {
    setSync(ScheduleDataStore.scheduleTypeKey, value);
  }

  @override
  String get scheduleTypeStr {
    if (!_prefs.containsKey(ScheduleDataStore.scheduleTypeKey)) {
      scheduleTypeStr = defaultScheduleTypeStr;
    }
    return _prefs.getString(ScheduleDataStore.scheduleTypeKey);
  }

  set periodicHours(int value) {
    setSync(periodicHoursKey, value);
  }

  @override
  int get periodicHours {
    if (!_prefs.containsKey(ScheduleDataStore.periodicHoursKey)) {
      periodicHours = defaultPeriodicHours;
    }
    return _prefs.getInt(ScheduleDataStore.periodicHoursKey);
  }

  set periodicMinutes(int value) {
    setSync(periodicMinutesKey, value);
  }

  @override
  int get periodicMinutes {
    if (!_prefs.containsKey(ScheduleDataStore.periodicMinutesKey)) {
      periodicMinutes = defaultPeriodicMinutes;
    }
    return _prefs.getInt(ScheduleDataStore.periodicMinutesKey);
  }

  set randomMinMinutes(int value) {
    setSync(randomMinMinutesKey, value);
  }

  @override
  int get randomMinMinutes {
    if (!_prefs.containsKey(ScheduleDataStore.randomMinMinutesKey)) {
      randomMinMinutes = defaultRandomMinMinutes;
    }
    return _prefs.getInt(ScheduleDataStore.randomMinMinutesKey);
  }

  set randomMaxMinutes(int value) {
    setSync(randomMaxMinutesKey, value);
  }

  @override
  int get randomMaxMinutes {
    if (!_prefs.containsKey(ScheduleDataStore.randomMaxMinutesKey)) {
      randomMaxMinutes = defaultRandomMaxMinutes;
    }
    return _prefs.getInt(ScheduleDataStore.randomMaxMinutesKey);
  }

  set quietHoursStartHour(int value) {
    setSync(quietHoursStartHourKey, value);
  }

  @override
  int get quietHoursStartHour {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursStartHourKey)) {
      quietHoursStartHour = defaultQuietHoursStartHour;
    }
    return _prefs.getInt(ScheduleDataStore.quietHoursStartHourKey);
  }

  set quietHoursStartMinute(int value) {
    setSync(quietHoursStartMinuteKey, value);
  }

  @override
  int get quietHoursStartMinute {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursStartMinuteKey)) {
      quietHoursStartMinute = defaultQuietHoursStartMinute;
    }
    return _prefs.getInt(ScheduleDataStore.quietHoursStartMinuteKey);
  }

  set quietHoursEndHour(int value) {
    setSync(quietHoursEndHourKey, value);
  }

  @override
  int get quietHoursEndHour {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursEndHourKey)) {
      quietHoursEndHour = defaultQuietHoursEndHour;
    }
    return _prefs.getInt(ScheduleDataStore.quietHoursEndHourKey);
  }

  set quietHoursEndMinute(int value) {
    setSync(quietHoursEndMinuteKey, value);
  }

  @override
  int get quietHoursEndMinute {
    if (!_prefs.containsKey(ScheduleDataStore.quietHoursEndMinuteKey)) {
      quietHoursEndMinute = defaultQuietHoursEndMinute;
    }
    return _prefs.getInt(ScheduleDataStore.quietHoursEndMinuteKey);
  }

  set notifyQuietHours(bool value) {
    setSync(notifyQuietHoursKey, value);
  }

  @override
  bool get notifyQuietHours {
    if (!_prefs.containsKey(ScheduleDataStore.notifyQuietHoursKey)) {
      notifyQuietHours = defaultNotifyQuietHours;
    }
    return _prefs.getBool(ScheduleDataStore.notifyQuietHoursKey);
  }

  set reminderMessage(String value) {
    setSync(reminderMessageKey, value);
  }

  @override
  String get reminderMessage {
    if (!_prefs.containsKey(ScheduleDataStore.reminderMessageKey)) {
      reminderMessage = defaultReminderMessage;
    }
    return _prefs.getString(ScheduleDataStore.reminderMessageKey);
  }

  set infoMessage(String value) {
    setSync(infoMessageKey, value);
  }

  @override
  String get infoMessage {
    if (!_prefs.containsKey(ScheduleDataStore.infoMessageKey)) {
      infoMessage = defaultInfoMessage;
    }
    return _prefs.getString(ScheduleDataStore.infoMessageKey);
  }

  set controlMessage(String value) {
    setSync(controlMessageKey, value);
  }

  @override
  String get controlMessage {
    if (!_prefs.containsKey(ScheduleDataStore.controlMessageKey)) {
      controlMessage = defaultControlMessage;
    }
    return _prefs.getString(ScheduleDataStore.controlMessageKey);
  }

  set theme(String value) {
    setSync(themeKey, value);
  }

  @override
  String get theme {
    if (!_prefs.containsKey(ScheduleDataStore.themeKey)) {
      theme = defaultTheme;
    }
    return _prefs.getString(ScheduleDataStore.themeKey);
  }

  set bellId(String value) {
    setSync(bellIdKey, value);
  }

  @override
  String get bellId {
    if (!_prefs.containsKey(ScheduleDataStore.bellIdKey)) {
      bellId = defaultBellId;
    }
    return _prefs.getString(ScheduleDataStore.bellIdKey);
  }

  set customBellPath(String value) {
    setSync(customBellPathKey, value);
  }

  @override
  String get customBellPath {
    if (!_prefs.containsKey(ScheduleDataStore.customBellPathKey)) {
      customBellPath = defaultCustomBellPath;
    }
    return _prefs.getString(ScheduleDataStore.customBellPathKey);
  }

  ScheduleDataStoreRO getScheduleDataStoreRO() {
    return ScheduleDataStoreRO(
        enabled,
        mute,
        vibrate,
        useBackgroundService,
        useStickyNotification,
        includeDebugInfo,
        scheduleTypeStr,
        periodicHours,
        periodicMinutes,
        randomMinMinutes,
        randomMaxMinutes,
        quietHoursStartHour,
        quietHoursStartMinute,
        quietHoursEndHour,
        quietHoursEndMinute,
        notifyQuietHours,
        reminderMessage,
        infoMessage,
        controlMessage,
        theme,
        bellId,
        customBellPath);
  }
}
