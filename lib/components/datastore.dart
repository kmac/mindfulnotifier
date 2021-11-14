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

bool testMigrateApp = false;
bool testMigrateSched = false;

// A list for the initial json string. Each entry has keys: text, enabled, tag, weight
//
// Idea: add optional weight to support weighing reminders differently
//
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
];

Future<void> checkMigrateSharedPreferences(var box,
    {List<String> excludeKeys, List<String> includeKeys}) async {
  if (!box.isEmpty) {
    return;
  }
  // Check if we need to convert from SharedPreferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getKeys().length > 0) {
    logger.i("Migrating SharedPreferences to Hive box ${box.name}");

    for (String key in prefs.getKeys()) {
      bool ignoreKey = false;
      if (excludeKeys != null && excludeKeys.contains(key)) {
        ignoreKey = true;
      } else if (includeKeys != null && !includeKeys.contains(key)) {
        ignoreKey = true;
      }
      if (ignoreKey) {
        logger.i("${box.name}: Ignoring $key");
      } else {
        var value = prefs.get(key);
        logger.i("${box.name}: Converting $key = $value");
        box.put(key, value);
        // logger.i("Removing key: $key from SharedPreferences");
        // prefs.remove(key);
      }
    }
  }
}

// ISSUE sharing data across the UI and the alarm/scheduler isolate:
//  https://github.com/flutter/flutter/issues/61529

/// Data store for app-level data. This store is accessed only via the
/// UI isolate.
///
class AppDataStore {
  static const String themeKey = 'theme';
  static const String useBackgroundServiceKey = 'useBackgroundService';

  static const String defaultTheme = 'Default';
  static const bool defaultUseBackgroundService = false;

  static AppDataStore _instance;

  Box _box;

  /// Public factory
  static Future<AppDataStore> getInstance() async {
    if (_instance == null) {
      _instance = AppDataStore._create();
      await _instance._init();
    }
    return _instance;
  }

  /// Private constructor
  AppDataStore._create() {
    logger.i("Creating AppDataStore");
  }

  Future<void> _init() async {
    logger.i("Initializing AppDataStore (hive)");
    await Hive.initFlutter();

    _box = await Hive.openBox('appdata');
    if (testMigrateApp) {
      await _box.clear();
      testMigrateApp = false;
    }
    await checkMigrateSharedPreferences(_box, includeKeys: [
      ScheduleDataStoreBase.themeKey,
      ScheduleDataStoreBase.useBackgroundServiceKey
    ]);
  }

  Future<void> setSync(String key, dynamic val) async {
    await _box.put(key, val);
  }

  String get theme {
    if (_box.get(ScheduleDataStoreBase.themeKey) == null) {
      theme = ScheduleDataStoreBase.defaultTheme;
    }
    return _box.get(ScheduleDataStoreBase.themeKey);
  }

  set theme(String value) {
    setSync(ScheduleDataStoreBase.themeKey, value);
  }

  bool get useBackgroundService {
    if (_box.get(ScheduleDataStoreBase.useBackgroundServiceKey) == null) {
      useBackgroundService = false;
    }
    return _box.get(ScheduleDataStoreBase.useBackgroundServiceKey);
  }

  set useBackgroundService(bool value) {
    setSync(ScheduleDataStoreBase.useBackgroundServiceKey, value);
  }
}

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
  static const String nextAlarmKey = 'nextAlarm';

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
  static const String defaultInfoMessage = 'Disabled';
  static const String defaultControlMessage = '';
  static const String defaultTheme = 'Default';
  static const String defaultBellId = 'bell1';
  static const String defaultCustomBellPath = '';

  bool get enabled;
  bool get mute;
  bool get vibrate;
  String get audioOutputChannel;
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
  String get bellId;
  String get customBellPath;
  String get nextAlarm;

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

  String randomReminder({String tag}) {
    Reminders reminders = Reminders.fromJson(jsonReminders);
    return reminders.randomReminder(tag: tag);
  }
}

/// In-memory data store. Created from the scheduler/alarm service and passed
/// into the UI isolate as a read-only store.
///
class InMemoryScheduleDataStore extends ScheduleDataStoreBase {
  bool enabled;
  bool mute;
  bool vibrate;
  String audioOutputChannel;
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
  String bellId;
  String customBellPath;
  String nextAlarm;

  InMemoryScheduleDataStore.fromDS(ScheduleDataStore ds)
      : this.enabled = ds.enabled,
        this.mute = ds.mute,
        this.vibrate = ds.vibrate,
        this.audioOutputChannel = ds.audioOutputChannel,
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
        this.bellId = ds.bellId,
        this.customBellPath = ds.customBellPath,
        this.nextAlarm = ds.nextAlarm;
}

/// Data store for the scheduler/alarm service. This data store is accessed
/// from the alarm isolate.
///
class ScheduleDataStore extends ScheduleDataStoreBase {
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
    logger.i("Creating ScheduleDataStore");
  }

  InMemoryScheduleDataStore getInMemoryInstance() {
    return InMemoryScheduleDataStore.fromDS(this);
  }

  Box _box;

  Future<void> _init() async {
    logger.i("Initializing ScheduleDataStore (hive");
    await Hive.initFlutter();

    _box = await Hive.openBox('scheduledata');
    if (testMigrateSched) {
      await _box.clear();
      testMigrateSched = false;
    }
    await checkMigrateSharedPreferences(_box, excludeKeys: [
      ScheduleDataStoreBase.themeKey,
      ScheduleDataStoreBase.useBackgroundServiceKey
    ]);
  }

  Future<void> setSync(String key, dynamic val) async {
    await _box.put(key, val);
  }

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

  void mergeIntoPermanentDS(InMemoryScheduleDataStore mds) {
    logger.i("merge: $mds");
    _mergeVal(ScheduleDataStoreBase.enabledKey, mds.enabled);
    _mergeVal(ScheduleDataStoreBase.muteKey, mds.mute);
    _mergeVal(ScheduleDataStoreBase.vibrateKey, mds.vibrate);
    _mergeVal(
        ScheduleDataStoreBase.audioOutputChannelKey, mds.audioOutputChannel);
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
    _mergeVal(ScheduleDataStoreBase.bellIdKey, mds.bellId);
    _mergeVal(ScheduleDataStoreBase.customBellPathKey, mds.customBellPath);
    _mergeVal(ScheduleDataStoreBase.nextAlarmKey, mds.nextAlarm);
  }

  bool get enabled {
    if (_box.get(ScheduleDataStoreBase.enabledKey) == null) {
      enabled = false;
    }
    return _box.get(ScheduleDataStoreBase.enabledKey);
  }

  set enabled(bool value) {
    setSync(ScheduleDataStoreBase.enabledKey, value);
  }

  bool get mute {
    if (_box.get(ScheduleDataStoreBase.muteKey) == null) {
      mute = false;
    }
    return _box.get(ScheduleDataStoreBase.muteKey);
  }

  set mute(bool value) {
    setSync(ScheduleDataStoreBase.muteKey, value);
  }

  bool get vibrate {
    if (_box.get(ScheduleDataStoreBase.vibrateKey) == null) {
      vibrate = false;
    }
    return _box.get(ScheduleDataStoreBase.vibrateKey);
  }

  set vibrate(bool value) {
    setSync(ScheduleDataStoreBase.vibrateKey, value);
  }

  String get audioOutputChannel {
    if (_box.get(ScheduleDataStoreBase.audioOutputChannelKey) == null) {
      audioOutputChannel = ScheduleDataStoreBase.defaultAudioOutputChannel;
    }
    return _box.get(ScheduleDataStoreBase.audioOutputChannelKey);
  }

  set audioOutputChannel(String value) {
    setSync(ScheduleDataStoreBase.audioOutputChannelKey, value);
  }

  bool get useStickyNotification {
    if (_box.get(ScheduleDataStoreBase.useStickyNotificationKey) == null) {
      useStickyNotification = true;
    }
    return _box.get(ScheduleDataStoreBase.useStickyNotificationKey);
  }

  set useStickyNotification(bool value) {
    setSync(ScheduleDataStoreBase.useStickyNotificationKey, value);
  }

  bool get includeDebugInfo {
    if (_box.get(ScheduleDataStoreBase.includeDebugInfoKey) == null) {
      includeDebugInfo = false;
    }
    return _box.get(ScheduleDataStoreBase.includeDebugInfoKey);
  }

  set includeDebugInfo(bool value) {
    setSync(ScheduleDataStoreBase.includeDebugInfoKey, value);
  }

  bool get hideNextReminder {
    if (_box.get(ScheduleDataStoreBase.hideNextReminderKey) == null) {
      hideNextReminder = false;
    }
    return _box.get(ScheduleDataStoreBase.hideNextReminderKey);
  }

  set hideNextReminder(bool value) {
    setSync(ScheduleDataStoreBase.hideNextReminderKey, value);
  }

  String get scheduleTypeStr {
    if (_box.get(ScheduleDataStoreBase.scheduleTypeKey) == null) {
      scheduleTypeStr = ScheduleDataStoreBase.defaultScheduleTypeStr;
    }
    return _box.get(ScheduleDataStoreBase.scheduleTypeKey);
  }

  set scheduleTypeStr(String value) {
    setSync(ScheduleDataStoreBase.scheduleTypeKey, value);
  }

  int get periodicHours {
    if (_box.get(ScheduleDataStoreBase.periodicHoursKey) == null) {
      periodicHours = ScheduleDataStoreBase.defaultPeriodicHours;
    }
    return _box.get(ScheduleDataStoreBase.periodicHoursKey);
  }

  set periodicHours(int value) {
    setSync(ScheduleDataStoreBase.periodicHoursKey, value);
  }

  int get periodicMinutes {
    if (_box.get(ScheduleDataStoreBase.periodicMinutesKey) == null) {
      periodicMinutes = ScheduleDataStoreBase.defaultPeriodicMinutes;
    }
    return _box.get(ScheduleDataStoreBase.periodicMinutesKey);
  }

  set periodicMinutes(int value) {
    setSync(ScheduleDataStoreBase.periodicMinutesKey, value);
  }

  int get randomMinMinutes {
    if (_box.get(ScheduleDataStoreBase.randomMinMinutesKey) == null) {
      randomMinMinutes = ScheduleDataStoreBase.defaultRandomMinMinutes;
    }
    return _box.get(ScheduleDataStoreBase.randomMinMinutesKey);
  }

  set randomMinMinutes(int value) {
    setSync(ScheduleDataStoreBase.randomMinMinutesKey, value);
  }

  int get randomMaxMinutes {
    if (_box.get(ScheduleDataStoreBase.randomMaxMinutesKey) == null) {
      randomMaxMinutes = ScheduleDataStoreBase.defaultRandomMaxMinutes;
    }
    return _box.get(ScheduleDataStoreBase.randomMaxMinutesKey);
  }

  set randomMaxMinutes(int value) {
    setSync(ScheduleDataStoreBase.randomMaxMinutesKey, value);
  }

  int get quietHoursStartHour {
    if (_box.get(ScheduleDataStoreBase.quietHoursStartHourKey) == null) {
      quietHoursStartHour = ScheduleDataStoreBase.defaultQuietHoursStartHour;
    }
    return _box.get(ScheduleDataStoreBase.quietHoursStartHourKey);
  }

  set quietHoursStartHour(int value) {
    setSync(ScheduleDataStoreBase.quietHoursStartHourKey, value);
  }

  int get quietHoursStartMinute {
    if (_box.get(ScheduleDataStoreBase.quietHoursStartMinuteKey) == null) {
      quietHoursStartMinute =
          ScheduleDataStoreBase.defaultQuietHoursStartMinute;
    }
    return _box.get(ScheduleDataStoreBase.quietHoursStartMinuteKey);
  }

  set quietHoursStartMinute(int value) {
    setSync(ScheduleDataStoreBase.quietHoursStartMinuteKey, value);
  }

  int get quietHoursEndHour {
    if (_box.get(ScheduleDataStoreBase.quietHoursEndHourKey) == null) {
      quietHoursEndHour = ScheduleDataStoreBase.defaultQuietHoursEndHour;
    }
    return _box.get(ScheduleDataStoreBase.quietHoursEndHourKey);
  }

  set quietHoursEndHour(int value) {
    setSync(ScheduleDataStoreBase.quietHoursEndHourKey, value);
  }

  int get quietHoursEndMinute {
    if (_box.get(ScheduleDataStoreBase.quietHoursEndMinuteKey) == null) {
      quietHoursEndMinute = ScheduleDataStoreBase.defaultQuietHoursEndMinute;
    }
    return _box.get(ScheduleDataStoreBase.quietHoursEndMinuteKey);
  }

  set quietHoursEndMinute(int value) {
    setSync(ScheduleDataStoreBase.quietHoursEndMinuteKey, value);
  }

  bool get notifyQuietHours {
    return ScheduleDataStoreBase.defaultNotifyQuietHours;
  }

  String get reminderMessage {
    if (_box.get(ScheduleDataStoreBase.reminderMessageKey) == null) {
      reminderMessage = ScheduleDataStoreBase.defaultReminderMessage;
    }
    return _box.get(ScheduleDataStoreBase.reminderMessageKey);
  }

  set reminderMessage(String value) {
    setSync(ScheduleDataStoreBase.reminderMessageKey, value);
  }

  String get infoMessage {
    if (_box.get(ScheduleDataStoreBase.infoMessageKey) == null) {
      infoMessage = ScheduleDataStoreBase.defaultInfoMessage;
    }
    return _box.get(ScheduleDataStoreBase.infoMessageKey);
  }

  set infoMessage(String value) {
    setSync(ScheduleDataStoreBase.infoMessageKey, value);
  }

  String get controlMessage {
    if (_box.get(ScheduleDataStoreBase.controlMessageKey) == null) {
      controlMessage = ScheduleDataStoreBase.defaultControlMessage;
    }
    return _box.get(ScheduleDataStoreBase.controlMessageKey);
  }

  set controlMessage(String value) {
    setSync(ScheduleDataStoreBase.controlMessageKey, value);
  }

  String get bellId {
    if (_box.get(ScheduleDataStoreBase.bellIdKey) == null) {
      bellId = ScheduleDataStoreBase.defaultBellId;
    }
    return _box.get(ScheduleDataStoreBase.bellIdKey);
  }

  set bellId(String value) {
    setSync(ScheduleDataStoreBase.bellIdKey, value);
  }

  String get customBellPath {
    if (_box.get(ScheduleDataStoreBase.customBellPathKey) == null) {
      customBellPath = ScheduleDataStoreBase.defaultCustomBellPath;
    }
    return _box.get(ScheduleDataStoreBase.customBellPathKey);
  }

  set customBellPath(String value) {
    setSync(ScheduleDataStoreBase.customBellPathKey, value);
  }

  String get nextAlarm {
    if (_box.get(ScheduleDataStoreBase.nextAlarmKey) == null) {
      nextAlarm = '';
    }
    return _box.get(ScheduleDataStoreBase.nextAlarmKey);
  }

  set nextAlarm(String value) {
    setSync(ScheduleDataStoreBase.nextAlarmKey, value);
  }

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

  set jsonReminders(String jsonString) {
    // Validate. This will throw an exception if it doesn't parse
    Reminders.fromJson(jsonString);

    setSync(ScheduleDataStoreBase.jsonRemindersKey, jsonString);
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
