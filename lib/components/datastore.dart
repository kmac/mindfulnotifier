import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:equatable/equatable.dart';

import 'package:mindfulnotifier/components/logging.dart';

var logger = createLogger('datastore');

final Random random = Random();

// A list for the initial json string. Each entry has keys: text, enabled, tag, weight
// Idea: add optional weight to support weighing reminders differently
const List<Map<String, dynamic>> defaultJsonReminderMap = [
  {
    "text": "Are you aware?",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text": "Breathe deeply. This is the present moment.",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text": "Take a moment to pause, and come back to the present.",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text": "Bring awareness into this moment.",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text": "Let go of greed, aversion, and delusion.",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text": "Respond, not react.",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text": "All of this is impermanent.",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text":
        "Accept the feeling of what is happening in this moment. Don't struggle against it. Instead, notice it. Take it in.",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text":
        "RAIN: Recognize / Allow / Invesigate with interest and care / Nurture with self-compassion",
    "enabled": false,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text":
        "Note any feeling tones in the moment: Pleasant / Unpleasant / Neutral.",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text": "What is the attitude in the mind right now?",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text":
        "May you be happy. May you be healthy. May you be free from harm. May you be peaceful.",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text":
        "\"Whatever it is that has the nature to arise will also pass away; therefore, there is nothing to want.\" -- Joseph Goldstein",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  {
    "text":
        "\"Sitting quietly, Doing nothing, Spring comes, and the grass grows, by itself.\" -- Bashō",
    "enabled": true,
    "tag": "${Reminder.defaultTagName}"
  },
  // {
  //   "text":
  //       "Two is very two, two is very too. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long.",
  //   "enabled": true,
  //   "tag": "${Reminder.defaultTagName}"
  // },
  // {
  //   "text":
  //       "This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long. This is very long.",
  //   "enabled": true,
  //   "tag": "${Reminder.defaultTagName}"
  // },
];

// ISSUE sharing data across the UI and the alarm/scheduler isolate:
//  https://github.com/flutter/flutter/issues/61529

abstract class ScheduleDataStoreBase {
  static const String enabledKey = 'enabled';
  static const String muteKey = 'mute';
  static const String vibrateKey = 'vibrate';
  static const String audioOutputChannelKey = 'audioOutputChannel';
  static const String useBackgroundServiceKey = 'useBackgroundService';
  static const String useStickyNotificationKey = 'useStickyNotification';
  static const String includeDebugInfoKey = 'includeDebugInfoKey';
  static const String hideNextReminderKey = 'hideNextReminderKey';
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

  // replaced by jsonReminders :
  static const String remindersKeyDeprecated = 'reminders';
  static const String jsonRemindersKey = 'jsonReminders';

  static const String infoMessageKey = 'infoMessage';
  static const String controlMessageKey = 'controlMessage';
  static const String themeKey = 'theme';
  static const String bellIdKey = 'bellId';
  static const String customBellPathKey = 'customBellPath';

  // defaults
  static const String defaultAudioOutputChannel = 'notification';
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
  static const bool defaultNotifyQuietHours = false;
  static const String defaultReminderMessage = 'Not Enabled';
  static const String defaultInfoMessage = 'Uninitialized';
  static const String defaultControlMessage = '';
  static const String defaultTheme = 'Default';
  static const String defaultBellId = 'bell1';
  static const String defaultCustomBellPath = '';

  bool get enabled;
  bool get mute;
  bool get vibrate;
  String get audioOutputChannel;
  bool get useBackgroundService;
  bool get useStickyNotification;
  bool get includeDebugInfo;
  bool get hideNextReminder;
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
  String get jsonReminders;
  String get infoMessage;
  String get controlMessage;
  String get theme;
  String get bellId;
  String get customBellPath;

  // this is only here to support old reminders format
  bool reminderExists(String reminderText, {List jsonReminderList}) {
    jsonReminderList ??= json.decode(jsonReminders);
    for (Map reminder in jsonReminderList) {
      if (reminder.containsKey('text') && reminder['text'] == reminderText) {
        return true;
      }
    }
    return false;
  }
}

class InMemoryScheduleDataStore extends ScheduleDataStoreBase {
  bool enabled;
  bool mute;
  bool vibrate;
  String audioOutputChannel;
  bool useBackgroundService;
  bool useStickyNotification;
  bool includeDebugInfo;
  bool hideNextReminder;
  String scheduleTypeStr;
  int periodicHours;
  int periodicMinutes;
  int randomMinMinutes;
  int randomMaxMinutes;
  int quietHoursStartHour;
  int quietHoursStartMinute;
  int quietHoursEndHour;
  int quietHoursEndMinute;
  bool notifyQuietHours;
  String reminderMessage;
  String jsonReminders;
  String infoMessage;
  String controlMessage;
  String theme;
  String bellId;
  String customBellPath;

  InMemoryScheduleDataStore.fromDS(ScheduleDataStore ds)
      : this.enabled = ds.enabled,
        this.mute = ds.mute,
        this.vibrate = ds.vibrate,
        this.audioOutputChannel = ds.audioOutputChannel,
        this.useBackgroundService = ds.useBackgroundService,
        this.useStickyNotification = ds.useStickyNotification,
        this.includeDebugInfo = ds.includeDebugInfo,
        this.hideNextReminder = ds.hideNextReminder,
        this.scheduleTypeStr = ds.scheduleTypeStr,
        this.periodicHours = ds.periodicHours,
        this.periodicMinutes = ds.periodicMinutes,
        this.randomMinMinutes = ds.randomMinMinutes,
        this.randomMaxMinutes = ds.randomMaxMinutes,
        this.quietHoursStartHour = ds.quietHoursStartHour,
        this.quietHoursStartMinute = ds.quietHoursStartMinute,
        this.quietHoursEndHour = ds.quietHoursEndHour,
        this.quietHoursEndMinute = ds.quietHoursEndMinute,
        this.notifyQuietHours = ds.notifyQuietHours,
        this.reminderMessage = ds.reminderMessage,
        this.jsonReminders = ds.jsonReminders,
        this.infoMessage = ds.infoMessage,
        this.controlMessage = ds.controlMessage,
        this.theme = ds.theme,
        this.bellId = ds.bellId,
        this.customBellPath = ds.customBellPath;
}

abstract class ScheduleDataStore extends ScheduleDataStoreBase {
  static ScheduleDataStore _instance;
  // static SharedPrefDataStore _instance;
  // static HiveScheduleDataStore _instance;

  /// Public factory
  static Future<ScheduleDataStore> getInstance() async {
    if (_instance == null) {
      // SharedPrefDataStore i = SharedPrefDataStore._create();
      HiveScheduleDataStore i = HiveScheduleDataStore._create();
      await i._init();
      _instance = i;
    }
    return _instance;
  }

  static Future<InMemoryScheduleDataStore> getInMemoryInstance() async {
    return InMemoryScheduleDataStore.fromDS(await getInstance());
  }

  void reload() async {}

  Future<void> setSync(String key, dynamic val) async {}

  void merge(InMemoryScheduleDataStore mds) {
    logger.i("merge: $mds");
    _mergeVal(ScheduleDataStoreBase.enabledKey, mds.enabled);
    _mergeVal(ScheduleDataStoreBase.muteKey, mds.mute);
    _mergeVal(ScheduleDataStoreBase.vibrateKey, mds.vibrate);
    _mergeVal(
        ScheduleDataStoreBase.audioOutputChannelKey, mds.audioOutputChannel);
    _mergeVal(ScheduleDataStoreBase.useBackgroundServiceKey,
        mds.useBackgroundService);
    _mergeVal(ScheduleDataStoreBase.useStickyNotificationKey,
        mds.useStickyNotification);
    _mergeVal(ScheduleDataStoreBase.includeDebugInfoKey, mds.includeDebugInfo);
    _mergeVal(ScheduleDataStoreBase.hideNextReminderKey, mds.hideNextReminder);
    _mergeVal(ScheduleDataStoreBase.scheduleTypeKey, mds.scheduleTypeStr);
    _mergeVal(ScheduleDataStoreBase.periodicHoursKey, mds.periodicHours);
    _mergeVal(ScheduleDataStoreBase.periodicMinutesKey, mds.periodicMinutes);
    _mergeVal(ScheduleDataStoreBase.randomMinMinutesKey, mds.randomMinMinutes);
    _mergeVal(ScheduleDataStoreBase.randomMaxMinutesKey, mds.randomMaxMinutes);
    _mergeVal(
        ScheduleDataStoreBase.quietHoursStartHourKey, mds.quietHoursStartHour);
    _mergeVal(ScheduleDataStoreBase.quietHoursStartMinuteKey,
        mds.quietHoursStartMinute);
    _mergeVal(
        ScheduleDataStoreBase.quietHoursEndHourKey, mds.quietHoursEndHour);
    _mergeVal(
        ScheduleDataStoreBase.quietHoursEndMinuteKey, mds.quietHoursEndMinute);
    _mergeVal(ScheduleDataStoreBase.notifyQuietHoursKey, mds.notifyQuietHours);
    _mergeVal(ScheduleDataStoreBase.reminderMessageKey, mds.reminderMessage);
    // _mergeVal(remindersKey, mds.reminders);
    _mergeVal(ScheduleDataStoreBase.jsonRemindersKey, mds.jsonReminders);
    _mergeVal(ScheduleDataStoreBase.infoMessageKey, mds.infoMessage);
    _mergeVal(ScheduleDataStoreBase.controlMessageKey, mds.controlMessage);
    _mergeVal(ScheduleDataStoreBase.themeKey, mds.theme);
    _mergeVal(ScheduleDataStoreBase.bellIdKey, mds.bellId);
    _mergeVal(ScheduleDataStoreBase.customBellPathKey, mds.customBellPath);
  }

  void _mergeVal(String key, var val) {
    logger.e("Unsupported base call to _mergeVal");
  }

  set enabled(bool value) {
    setSync(ScheduleDataStoreBase.enabledKey, value);
  }

  set mute(bool value) {
    setSync(ScheduleDataStoreBase.muteKey, value);
  }

  set vibrate(bool value) {
    setSync(ScheduleDataStoreBase.vibrateKey, value);
  }

  set audioOutputChannel(String value) {
    setSync(ScheduleDataStoreBase.audioOutputChannelKey, value);
  }

  set useBackgroundService(bool value) {
    setSync(ScheduleDataStoreBase.useBackgroundServiceKey, value);
  }

  set useStickyNotification(bool value) {
    setSync(ScheduleDataStoreBase.useStickyNotificationKey, value);
  }

  set includeDebugInfo(bool value) {
    setSync(ScheduleDataStoreBase.includeDebugInfoKey, value);
  }

  set hideNextReminder(bool value) {
    setSync(ScheduleDataStoreBase.hideNextReminderKey, value);
  }

  set scheduleTypeStr(String value) {
    setSync(ScheduleDataStoreBase.scheduleTypeKey, value);
  }

  set periodicHours(int value) {
    setSync(ScheduleDataStoreBase.periodicHoursKey, value);
  }

  set periodicMinutes(int value) {
    setSync(ScheduleDataStoreBase.periodicMinutesKey, value);
  }

  set randomMinMinutes(int value) {
    setSync(ScheduleDataStoreBase.randomMinMinutesKey, value);
  }

  set randomMaxMinutes(int value) {
    setSync(ScheduleDataStoreBase.randomMaxMinutesKey, value);
  }

  set quietHoursStartHour(int value) {
    setSync(ScheduleDataStoreBase.quietHoursStartHourKey, value);
  }

  set quietHoursStartMinute(int value) {
    setSync(ScheduleDataStoreBase.quietHoursStartMinuteKey, value);
  }

  set quietHoursEndHour(int value) {
    setSync(ScheduleDataStoreBase.quietHoursEndHourKey, value);
  }

  set quietHoursEndMinute(int value) {
    setSync(ScheduleDataStoreBase.quietHoursEndMinuteKey, value);
  }

  set reminderMessage(String value) {
    setSync(ScheduleDataStoreBase.reminderMessageKey, value);
  }

  set infoMessage(String value) {
    setSync(ScheduleDataStoreBase.infoMessageKey, value);
  }

  set controlMessage(String value) {
    setSync(ScheduleDataStoreBase.controlMessageKey, value);
  }

  set theme(String value) {
    setSync(ScheduleDataStoreBase.themeKey, value);
  }

  set bellId(String value) {
    setSync(ScheduleDataStoreBase.bellIdKey, value);
  }

  set customBellPath(String value) {
    setSync(ScheduleDataStoreBase.customBellPathKey, value);
  }

  set jsonReminders(String jsonString) {
    // Validate. This will throw an exception if it doesn't parse
    Reminders.fromJson(jsonString);

    setSync(ScheduleDataStoreBase.jsonRemindersKey, jsonString);
  }

  String randomReminder({String tag}) {
    Reminders reminders = Reminders.fromJson(jsonReminders);
    return reminders.randomReminder(tag: tag);
  }
}

class SharedPrefDataStore extends ScheduleDataStore {
  static SharedPreferences _prefs;
  static SharedPrefDataStore _instance;

  /// Public factory
  static Future<SharedPrefDataStore> getInstance() async {
    if (_instance == null) {
      _instance = SharedPrefDataStore._create();
      await _instance._init();
    }
    return _instance;
  }

  /// Private constructor
  SharedPrefDataStore._create() {
    logger.i("Creating DataStore");
  }

  Future<void> _init() async {
    logger.i("Initializing SharedPreferences");
    _prefs = await SharedPreferences.getInstance();
  }

  void reload() async {
    await _prefs.reload();
  }

  void _mergeVal(String key, var val) {
    bool dirty = false;
    // check list equality differently:
    if (val is List<dynamic>) {
      if (!listEquals(_prefs.getStringList(key), val)) {
        dirty = true;
      }
    } else if (_prefs.get(key) != val) {
      dirty = true;
    }
    if (dirty) {
      logger.i("duh merging $key");
      // logger.d("merging $key => $val");
      setSync(key, val);
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
        List<String> newlist = [];
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

  @override
  bool get enabled {
    if (!_prefs.containsKey(ScheduleDataStoreBase.enabledKey)) {
      enabled = false;
    }
    return _prefs.getBool(ScheduleDataStoreBase.enabledKey);
  }

  @override
  bool get mute {
    if (!_prefs.containsKey(ScheduleDataStoreBase.muteKey)) {
      mute = false;
    }
    return _prefs.getBool(ScheduleDataStoreBase.muteKey);
  }

  @override
  bool get vibrate {
    if (!_prefs.containsKey(ScheduleDataStoreBase.vibrateKey)) {
      vibrate = false;
    }
    return _prefs.getBool(ScheduleDataStoreBase.vibrateKey);
  }

  @override
  String get audioOutputChannel {
    if (!_prefs.containsKey(ScheduleDataStoreBase.audioOutputChannelKey)) {
      audioOutputChannel = ScheduleDataStoreBase.defaultAudioOutputChannel;
    }
    return _prefs.getString(ScheduleDataStoreBase.audioOutputChannelKey);
  }

  @override
  bool get useBackgroundService {
    if (!_prefs.containsKey(ScheduleDataStoreBase.useBackgroundServiceKey)) {
      useBackgroundService = false;
    }
    return _prefs.getBool(ScheduleDataStoreBase.useBackgroundServiceKey);
  }

  @override
  bool get useStickyNotification {
    if (!_prefs.containsKey(ScheduleDataStoreBase.useStickyNotificationKey)) {
      useStickyNotification = true;
    }
    return _prefs.getBool(ScheduleDataStoreBase.useStickyNotificationKey);
  }

  @override
  bool get includeDebugInfo {
    if (!_prefs.containsKey(ScheduleDataStoreBase.includeDebugInfoKey)) {
      includeDebugInfo = false;
    }
    return _prefs.getBool(ScheduleDataStoreBase.includeDebugInfoKey);
  }

  @override
  bool get hideNextReminder {
    if (!_prefs.containsKey(ScheduleDataStoreBase.hideNextReminderKey)) {
      hideNextReminder = false;
    }
    return _prefs.getBool(ScheduleDataStoreBase.hideNextReminderKey);
  }

  @override
  String get scheduleTypeStr {
    if (!_prefs.containsKey(ScheduleDataStoreBase.scheduleTypeKey)) {
      scheduleTypeStr = ScheduleDataStoreBase.defaultScheduleTypeStr;
    }
    return _prefs.getString(ScheduleDataStoreBase.scheduleTypeKey);
  }

  @override
  int get periodicHours {
    if (!_prefs.containsKey(ScheduleDataStoreBase.periodicHoursKey)) {
      periodicHours = ScheduleDataStoreBase.defaultPeriodicHours;
    }
    return _prefs.getInt(ScheduleDataStoreBase.periodicHoursKey);
  }

  @override
  int get periodicMinutes {
    if (!_prefs.containsKey(ScheduleDataStoreBase.periodicMinutesKey)) {
      periodicMinutes = ScheduleDataStoreBase.defaultPeriodicMinutes;
    }
    return _prefs.getInt(ScheduleDataStoreBase.periodicMinutesKey);
  }

  @override
  int get randomMinMinutes {
    if (!_prefs.containsKey(ScheduleDataStoreBase.randomMinMinutesKey)) {
      randomMinMinutes = ScheduleDataStoreBase.defaultRandomMinMinutes;
    }
    return _prefs.getInt(ScheduleDataStoreBase.randomMinMinutesKey);
  }

  @override
  int get randomMaxMinutes {
    if (!_prefs.containsKey(ScheduleDataStoreBase.randomMaxMinutesKey)) {
      randomMaxMinutes = ScheduleDataStoreBase.defaultRandomMaxMinutes;
    }
    return _prefs.getInt(ScheduleDataStoreBase.randomMaxMinutesKey);
  }

  @override
  int get quietHoursStartHour {
    if (!_prefs.containsKey(ScheduleDataStoreBase.quietHoursStartHourKey)) {
      quietHoursStartHour = ScheduleDataStoreBase.defaultQuietHoursStartHour;
    }
    return _prefs.getInt(ScheduleDataStoreBase.quietHoursStartHourKey);
  }

  @override
  int get quietHoursStartMinute {
    if (!_prefs.containsKey(ScheduleDataStoreBase.quietHoursStartMinuteKey)) {
      quietHoursStartMinute =
          ScheduleDataStoreBase.defaultQuietHoursStartMinute;
    }
    return _prefs.getInt(ScheduleDataStoreBase.quietHoursStartMinuteKey);
  }

  @override
  int get quietHoursEndHour {
    if (!_prefs.containsKey(ScheduleDataStoreBase.quietHoursEndHourKey)) {
      quietHoursEndHour = ScheduleDataStoreBase.defaultQuietHoursEndHour;
    }
    return _prefs.getInt(ScheduleDataStoreBase.quietHoursEndHourKey);
  }

  @override
  int get quietHoursEndMinute {
    if (!_prefs.containsKey(ScheduleDataStoreBase.quietHoursEndMinuteKey)) {
      quietHoursEndMinute = ScheduleDataStoreBase.defaultQuietHoursEndMinute;
    }
    return _prefs.getInt(ScheduleDataStoreBase.quietHoursEndMinuteKey);
  }

  @override
  bool get notifyQuietHours {
    return ScheduleDataStoreBase.defaultNotifyQuietHours;
  }

  @override
  String get reminderMessage {
    if (!_prefs.containsKey(ScheduleDataStoreBase.reminderMessageKey)) {
      reminderMessage = ScheduleDataStoreBase.defaultReminderMessage;
    }
    return _prefs.getString(ScheduleDataStoreBase.reminderMessageKey);
  }

  @override
  String get infoMessage {
    if (!_prefs.containsKey(ScheduleDataStoreBase.infoMessageKey)) {
      infoMessage = ScheduleDataStoreBase.defaultInfoMessage;
    }
    return _prefs.getString(ScheduleDataStoreBase.infoMessageKey);
  }

  @override
  String get controlMessage {
    if (!_prefs.containsKey(ScheduleDataStoreBase.controlMessageKey)) {
      controlMessage = ScheduleDataStoreBase.defaultControlMessage;
    }
    return _prefs.getString(ScheduleDataStoreBase.controlMessageKey);
  }

  @override
  String get theme {
    if (!_prefs.containsKey(ScheduleDataStoreBase.themeKey)) {
      theme = ScheduleDataStoreBase.defaultTheme;
    }
    return _prefs.getString(ScheduleDataStoreBase.themeKey);
  }

  @override
  String get bellId {
    if (!_prefs.containsKey(ScheduleDataStoreBase.bellIdKey)) {
      bellId = ScheduleDataStoreBase.defaultBellId;
    }
    return _prefs.getString(ScheduleDataStoreBase.bellIdKey);
  }

  @override
  String get customBellPath {
    if (!_prefs.containsKey(ScheduleDataStoreBase.customBellPathKey)) {
      customBellPath = ScheduleDataStoreBase.defaultCustomBellPath;
    }
    return _prefs.getString(ScheduleDataStoreBase.customBellPathKey);
  }

  @override
  String get jsonReminders {
    // Check for migration to new format:
    if (_prefs.containsKey(ScheduleDataStoreBase.remindersKeyDeprecated)) {
      // old reminders list is still here: convert it to json and remove it
      List<String> remindersOrig =
          _prefs.getStringList(ScheduleDataStoreBase.remindersKeyDeprecated);
      jsonReminders = Reminders.migrateRemindersToJson(remindersOrig);
      _prefs.remove(ScheduleDataStoreBase.remindersKeyDeprecated);
      return jsonReminders;
    }
    if (!_prefs.containsKey(ScheduleDataStoreBase.jsonRemindersKey)) {
      // save the string pretty-printed so it will also be exported in this format
      JsonEncoder encoder = new JsonEncoder.withIndent('  ');
      jsonReminders = encoder.convert(defaultJsonReminderMap);
    }
    return _prefs.getString(ScheduleDataStoreBase.jsonRemindersKey);
  }
}

class HiveScheduleDataStore extends ScheduleDataStore {
  static HiveScheduleDataStore _instance;
  var _box;

  /// Public factory
  static Future<HiveScheduleDataStore> getInstance() async {
    if (_instance == null) {
      _instance = HiveScheduleDataStore._create();
      await _instance._init();
    }
    return _instance;
  }

  /// Private constructor
  HiveScheduleDataStore._create() {
    logger.i("Creating DataStore");
  }

  Future<void> _init() async {
    logger.i("Initializing Hive");
    await Hive.initFlutter();

    // TODO: why is this getting called twice? From two isolates??

    _box = await Hive.openBox('mindfulnotifier');
    bool testMigrate = true;
    if (testMigrate) {
      await _box.clear();
      testMigrate = false;
    }
    if (_box.isEmpty) {
      // Check if we need to convert from SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getKeys().length > 0) {
        logger.i("Converting SharedPreferences");
        for (String key in prefs.getKeys()) {
          var value = prefs.get(key);
          logger.i("Converting $key = $value");
          _box.put(key, value);
        }
      }
    }
  }

  @override
  Future<void> setSync(String key, dynamic val) async {
    _box.put(key, val);
  }

  @override
  void _mergeVal(String key, var val) {
    bool dirty = false;
    // check list equality differently:
    if (val is List<dynamic>) {
      if (!listEquals(_box.get(key), val)) {
        dirty = true;
      }
    } else if (_box.get(key) != val) {
      dirty = true;
    }
    if (dirty) {
      logger.i("merging $key = $val");
      // logger.d("merging $key => $val");
      _box.put(key, val);
    }
  }

  @override
  bool get enabled {
    if (_box.get(ScheduleDataStoreBase.enabledKey) == null) {
      enabled = false;
    }
    return _box.get(ScheduleDataStoreBase.enabledKey);
  }

  @override
  bool get mute {
    if (_box.get(ScheduleDataStoreBase.muteKey) == null) {
      mute = false;
    }
    return _box.get(ScheduleDataStoreBase.muteKey);
  }

  @override
  bool get vibrate {
    if (_box.get(ScheduleDataStoreBase.vibrateKey) == null) {
      vibrate = false;
    }
    return _box.get(ScheduleDataStoreBase.vibrateKey);
  }

  @override
  String get audioOutputChannel {
    if (_box.get(ScheduleDataStoreBase.audioOutputChannelKey) == null) {
      audioOutputChannel = ScheduleDataStoreBase.defaultAudioOutputChannel;
    }
    return _box.get(ScheduleDataStoreBase.audioOutputChannelKey);
  }

  @override
  bool get useBackgroundService {
    if (_box.get(ScheduleDataStoreBase.useBackgroundServiceKey) == null) {
      useBackgroundService = false;
    }
    return _box.get(ScheduleDataStoreBase.useBackgroundServiceKey);
  }

  @override
  bool get useStickyNotification {
    if (_box.get(ScheduleDataStoreBase.useStickyNotificationKey) == null) {
      useStickyNotification = true;
    }
    return _box.get(ScheduleDataStoreBase.useStickyNotificationKey);
  }

  @override
  bool get includeDebugInfo {
    if (_box.get(ScheduleDataStoreBase.includeDebugInfoKey) == null) {
      includeDebugInfo = false;
    }
    return _box.get(ScheduleDataStoreBase.includeDebugInfoKey);
  }

  @override
  bool get hideNextReminder {
    if (_box.get(ScheduleDataStoreBase.hideNextReminderKey) == null) {
      hideNextReminder = false;
    }
    return _box.get(ScheduleDataStoreBase.hideNextReminderKey);
  }

  @override
  String get scheduleTypeStr {
    if (_box.get(ScheduleDataStoreBase.scheduleTypeKey) == null) {
      scheduleTypeStr = ScheduleDataStoreBase.defaultScheduleTypeStr;
    }
    return _box.get(ScheduleDataStoreBase.scheduleTypeKey);
  }

  @override
  int get periodicHours {
    if (_box.get(ScheduleDataStoreBase.periodicHoursKey) == null) {
      periodicHours = ScheduleDataStoreBase.defaultPeriodicHours;
    }
    return _box.get(ScheduleDataStoreBase.periodicHoursKey);
  }

  @override
  int get periodicMinutes {
    if (_box.get(ScheduleDataStoreBase.periodicMinutesKey) == null) {
      periodicMinutes = ScheduleDataStoreBase.defaultPeriodicMinutes;
    }
    return _box.get(ScheduleDataStoreBase.periodicMinutesKey);
  }

  @override
  int get randomMinMinutes {
    if (_box.get(ScheduleDataStoreBase.randomMinMinutesKey) == null) {
      randomMinMinutes = ScheduleDataStoreBase.defaultRandomMinMinutes;
    }
    return _box.get(ScheduleDataStoreBase.randomMinMinutesKey);
  }

  @override
  int get randomMaxMinutes {
    if (_box.get(ScheduleDataStoreBase.randomMaxMinutesKey) == null) {
      randomMaxMinutes = ScheduleDataStoreBase.defaultRandomMaxMinutes;
    }
    return _box.get(ScheduleDataStoreBase.randomMaxMinutesKey);
  }

  @override
  int get quietHoursStartHour {
    if (_box.get(ScheduleDataStoreBase.quietHoursStartHourKey) == null) {
      quietHoursStartHour = ScheduleDataStoreBase.defaultQuietHoursStartHour;
    }
    return _box.get(ScheduleDataStoreBase.quietHoursStartHourKey);
  }

  @override
  int get quietHoursStartMinute {
    if (_box.get(ScheduleDataStoreBase.quietHoursStartMinuteKey) == null) {
      quietHoursStartMinute =
          ScheduleDataStoreBase.defaultQuietHoursStartMinute;
    }
    return _box.get(ScheduleDataStoreBase.quietHoursStartMinuteKey);
  }

  @override
  int get quietHoursEndHour {
    if (_box.get(ScheduleDataStoreBase.quietHoursEndHourKey) == null) {
      quietHoursEndHour = ScheduleDataStoreBase.defaultQuietHoursEndHour;
    }
    return _box.get(ScheduleDataStoreBase.quietHoursEndHourKey);
  }

  @override
  int get quietHoursEndMinute {
    if (_box.get(ScheduleDataStoreBase.quietHoursEndMinuteKey) == null) {
      quietHoursEndMinute = ScheduleDataStoreBase.defaultQuietHoursEndMinute;
    }
    return _box.get(ScheduleDataStoreBase.quietHoursEndMinuteKey);
  }

  @override
  bool get notifyQuietHours {
    return ScheduleDataStoreBase.defaultNotifyQuietHours;
  }

  @override
  String get reminderMessage {
    if (_box.get(ScheduleDataStoreBase.reminderMessageKey) == null) {
      reminderMessage = ScheduleDataStoreBase.defaultReminderMessage;
    }
    return _box.get(ScheduleDataStoreBase.reminderMessageKey);
  }

  @override
  String get infoMessage {
    if (_box.get(ScheduleDataStoreBase.infoMessageKey) == null) {
      infoMessage = ScheduleDataStoreBase.defaultInfoMessage;
    }
    return _box.get(ScheduleDataStoreBase.infoMessageKey);
  }

  @override
  String get controlMessage {
    if (_box.get(ScheduleDataStoreBase.controlMessageKey) == null) {
      controlMessage = ScheduleDataStoreBase.defaultControlMessage;
    }
    return _box.get(ScheduleDataStoreBase.controlMessageKey);
  }

  @override
  String get theme {
    if (_box.get(ScheduleDataStoreBase.themeKey) == null) {
      theme = ScheduleDataStoreBase.defaultTheme;
    }
    return _box.get(ScheduleDataStoreBase.themeKey);
  }

  @override
  String get bellId {
    if (_box.get(ScheduleDataStoreBase.bellIdKey) == null) {
      bellId = ScheduleDataStoreBase.defaultBellId;
    }
    return _box.get(ScheduleDataStoreBase.bellIdKey);
  }

  @override
  String get customBellPath {
    if (_box.get(ScheduleDataStoreBase.customBellPathKey) == null) {
      customBellPath = ScheduleDataStoreBase.defaultCustomBellPath;
    }
    return _box.get(ScheduleDataStoreBase.customBellPathKey);
  }

  @override
  String get jsonReminders {
    // Check for migration to new format:
    if (_box.get(ScheduleDataStoreBase.remindersKeyDeprecated) != null) {
      // old reminders list is still here: convert it to json and remove it
      List<String> remindersOrig =
          _box.get(ScheduleDataStoreBase.remindersKeyDeprecated);
      jsonReminders = Reminders.migrateRemindersToJson(remindersOrig);
      _box.delete(ScheduleDataStoreBase.remindersKeyDeprecated);
      return jsonReminders;
    }
    if (_box.get(ScheduleDataStoreBase.jsonRemindersKey) == null) {
      // save the string pretty-printed so it will also be exported in this format
      JsonEncoder encoder = new JsonEncoder.withIndent('  ');
      jsonReminders = encoder.convert(defaultJsonReminderMap);
    }
    return _box.get(ScheduleDataStoreBase.jsonRemindersKey);
  }
}

class Reminder extends Equatable {
  static const maxLength = 4096;
  static const truncLength = 256;
  static const truncLines = 5;
  static const defaultTagName = 'default';
  static const defaultCustomTagName = 'custom';
  final String text;
  final bool enabled;
  final String tag;

  Reminder(this.text, this.tag, this.enabled);

  Reminder.fromJson(int index, Map<String, dynamic> jsonMapEntry)
      : text = jsonMapEntry['text'],
        tag = jsonMapEntry['tag'],
        enabled = jsonMapEntry['enabled'];

  Map<String, dynamic> toJsonMapEntry() => {
        'text': text,
        'tag': tag,
        'enabled': enabled,
      };

  @override
  List<Object> get props => [text];

  static String truncateLines(String input, [int maxLines = truncLines]) {
    LineSplitter ls = new LineSplitter();
    List<String> lines = ls.convert(input);
    if (lines.length < maxLines) {
      return input;
    }
    return lines.sublist(0, maxLines).join("\n") + "...";
  }

  static String truncate(String input,
      [int length = maxLength, int maxLines = truncLines]) {
    if (input.length < truncLength) {
      return truncateLines(input, maxLines);
    }
    return truncateLines(input.substring(0, truncLength - 4) + '...');
  }

  String get truncated {
    return truncate(text);
  }

  @override
  String toString() {
    return "Reminder: text=$text, tag=$tag, enabled=$enabled";
  }
}

class Reminders {
  final List<Reminder> allReminders;

  Reminders.empty() : allReminders = [];

  Reminders.fromJson(String jsonReminders) : allReminders = [] {
    List jsonReminderList = json.decode(jsonReminders);
    int index = 0;
    for (Map<String, dynamic> jsonMapEntry in jsonReminderList) {
      Reminder reminder = Reminder.fromJson(index++, jsonMapEntry);
      allReminders.add(reminder);
    }
    _sortAllByText();
  }

  Reminders.fromDecodedJson(List<Map<String, dynamic>> decodedJson)
      : allReminders = [] {
    int index = 0;
    for (Map<String, dynamic> jsonMapEntry in decodedJson) {
      Reminder reminder = Reminder.fromJson(index++, jsonMapEntry);
      allReminders.add(reminder);
    }
    _sortAllByText();
  }

  String toJson() {
    List<Map<String, dynamic>> conversionList = [];
    for (Reminder reminder in allReminders) {
      conversionList.add(reminder.toJsonMapEntry());
    }
    String jsonReminders;
    // save the string pretty-printed so it will also be exported in this format
    JsonEncoder encoder = new JsonEncoder.withIndent('  ');
    jsonReminders = encoder.convert(conversionList);
    return jsonReminders;
  }

  static String migrateRemindersToJson(List<String> reminderList) {
    // old reminders list is still here: convert it to json and remove it
    logger.i("Migrating reminders to json");
    List<Map> conversionList = [];
    for (String rawReminder in reminderList) {
      Map<String, dynamic> mapForJson = Map();
      mapForJson['text'] = rawReminder;
      mapForJson['enabled'] = true;
      mapForJson['tag'] = Reminder.defaultTagName;
      conversionList.add(mapForJson);
    }
    String jsonReminders;
    // save the string pretty-printed so it will also be exported in this format
    JsonEncoder encoder = new JsonEncoder.withIndent('  ');
    jsonReminders = encoder.convert(conversionList);
    logger.i("Finished reminder migration to json: $jsonReminders");
    return jsonReminders;
  }

  Map<String, List<Reminder>> buildGroupedReminders() {
    // A map of reminders grouped by tag
    final Map<String, List<Reminder>> groupedReminders = Map();

    // Build groupedReminders from json data
    for (Reminder reminder in allReminders) {
      List<Reminder> group;
      if (!groupedReminders.containsKey(reminder.tag)) {
        group = [];
        groupedReminders[reminder.tag] = group;
      }
      groupedReminders[reminder.tag].add(reminder);
    }
    return groupedReminders;
  }

  String _stripFirstQuote(String s) {
    if (s != null && s.length > 0) {
      String firstChar = s.substring(0, 1);
      if (firstChar == '"' || firstChar == "'") {
        return s.substring(1);
      }
    }
    return s;
  }

  void _sortAllByText() {
    /// Sorts the allReminders list
    allReminders.sort(
        (a, b) => _stripFirstQuote(a.text).compareTo(_stripFirstQuote(b.text)));
  }

  List<Reminder> _sortByEnabled(List<Reminder> unsorted) {
    /// Sorts the *given* list, enabled first, then disabled
    List<Reminder> enabled = [];
    List<Reminder> disabled = [];
    for (Reminder reminder in unsorted) {
      if (reminder.enabled) {
        enabled.add(reminder);
      } else {
        disabled.add(reminder);
      }
    }
    enabled.addAll(disabled);
    return enabled;
  }

  List<Reminder> filter({bool enabled = true, String tag}) {
    /// Filters out either enabled or disabled, and optionally by tag
    List<Reminder> result = [];
    for (Reminder reminder in allReminders) {
      if (reminder.enabled == enabled) {
        if (tag == null || reminder.tag == tag) {
          result.add(reminder);
        }
      }
    }
    return result;
  }

  List<Reminder> getFilteredReminderList({String tag, bool sorted = true}) {
    if (tag == null || tag == '') {
      if (sorted) {
        return _sortByEnabled(allReminders);
      }
      return allReminders;
    }
    Map<String, List<Reminder>> groupedReminders = buildGroupedReminders();
    if (!groupedReminders.containsKey(tag)) {
      logger.e("tag '$tag' not in reminderGroups");
      return [];
    }
    if (sorted) {
      return _sortByEnabled(groupedReminders[tag]);
    }
    return groupedReminders[tag];
  }

  bool reminderExists(Reminder reminder) {
    return allReminders.contains(reminder);
  }

  void addReminder(Reminder reminder) {
    if (reminderExists(reminder)) {
      throw Exception("Reminder already exists: $reminder");
    }

    /// Add reminder to end of list
    allReminders.add(Reminder(reminder.text, reminder.tag, reminder.enabled));
    _sortAllByText();
  }

  void addReminders(List<Reminder> reminders) {
    /// Add all reminders to end of list
    for (Reminder newReminder in reminders) {
      if (!reminderExists(newReminder)) {
        allReminders.add(
            Reminder(newReminder.text, newReminder.tag, newReminder.enabled));
      }
    }
    _sortAllByText();
  }

  void updateReminder(int index, Reminder changedReminder) {
    logger.d("updateReminder: $index: ${allReminders[index]}");
    allReminders[index] = changedReminder;
    _sortAllByText();
  }

  void deleteReminder(Reminder reminder) {
    logger.d("deleteReminder: $reminder");
    if (!allReminders.remove(reminder)) {
      logger.e("deleteReminder: reminder not removed: $reminder");
    }
    _sortAllByText();
  }

  int findReminderIndex(Reminder reminder) {
    return allReminders.indexOf(reminder);
  }

  int findReminderIndexByText(String reminderText) {
    int index = 0;
    while (index < allReminders.length) {
      if (reminderText == allReminders[index].text) {
        return index;
      }
      ++index;
    }
    throw Exception("Reminder not found: $reminderText");
  }

  String randomReminder({String tag}) {
    List<Reminder> filteredList = filter(enabled: true, tag: tag);
    if (filteredList.isEmpty) {
      return tag == null
          ? "No reminders are enabled"
          : "No reminders are enabled for tag '$tag'";
    }
    return filteredList[random.nextInt(filteredList.length)].text;
  }

  @override
  String toString() {
    return allReminders.toString();
  }
}
