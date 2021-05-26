import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mindfulnotifier/components/logging.dart';

var logger = createLogger('datastore');

const defaultTag = 'default';
const customTag = 'custom';

// A list for the initial json string. Each entry has keys: text, enabled, tag, weight
// Idea: add optional weight to support weighing reminders differently
const List<Map<String, dynamic>> defaultJsonReminderMap = [
  {"text": "Are you aware?", "enabled": true, "tag": "$defaultTag"},
  {
    "text": "Breathe deeply. This is the present moment.",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {
    "text": "Take a moment to pause, and come back to the present.",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {
    "text": "Bring awareness into this moment.",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {
    "text": "Let go of greed, aversion, and delusion.",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {"text": "Respond, not react.", "enabled": true, "tag": "$defaultTag"},
  {
    "text": "All of this is impermanent.",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {
    "text":
        "Accept the feeling of what is happening in this moment. Don't struggle against it. Instead, notice it. Take it in.",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {
    "text":
        "RAIN: Recognize / Allow / Invesigate with interest and care / Nurture with self-compassion",
    "enabled": false,
    "tag": "$defaultTag"
  },
  {
    "text":
        "Note any feeling tones in the moment: Pleasant / Unpleasant / Neutral.",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {
    "text": "What is the attitude in the mind right now?",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {
    "text":
        "May you be happy. May you be healthy. May you be free from harm. May you be peaceful.",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {
    "text":
        "\"Whatever it is that has the nature to arise will also pass away; therefore, there is nothing to want.\" -- Joseph Goldstein",
    "enabled": true,
    "tag": "$defaultTag"
  },
  {
    "text":
        "\"Sitting quietly, Doing nothing, Spring comes, and the grass grows, by itself.\" -- Bashō",
    "enabled": true,
    "tag": "$defaultTag"
  },
];

// ISSUE sharing data across the UI and the alarm/scheduler isolate:
//  https://github.com/flutter/flutter/issues/61529

abstract class ScheduleDataStoreBase {
  bool get enabled;
  bool get mute;
  bool get vibrate;
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
  // @deprecated
  // List<String> get remindersDeprecated;
  String get jsonReminders;
  String get infoMessage;
  String get controlMessage;
  String get theme;
  String get bellId;
  String get customBellPath;

  bool reminderExists(String reminderText, {List jsonReminderList}) {
    jsonReminderList ??= jsonDecode(jsonReminders);
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
  // @deprecated
  // List<String> remindersDeprecated;
  String jsonReminders;
  String infoMessage;
  String controlMessage;
  String theme;
  String bellId;
  String customBellPath;

  InMemoryScheduleDataStore.fromDS(ScheduleDataStoreBase ds)
      : this.enabled = ds.enabled,
        this.mute = ds.mute,
        this.vibrate = ds.vibrate,
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

class ScheduleDataStore extends ScheduleDataStoreBase {
  static const String enabledKey = 'enabled';
  static const String muteKey = 'mute';
  static const String vibrateKey = 'vibrate';
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
  static const String remindersKeyDeprecated = 'reminders';
  static const String jsonRemindersKey = 'jsonReminders';
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
  static const bool defaultNotifyQuietHours = false;
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

  static Future<InMemoryScheduleDataStore> getInMemoryInstance() async {
    ScheduleDataStore ds = await getInstance();
    return InMemoryScheduleDataStore.fromDS(ds);
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

  static void backup(File backupFile) {
    var jsonData = _toJson(backup: true);
    logger.d('backup, tofile:${backupFile.path}: $jsonData');
    backupFile.writeAsStringSync(jsonData, flush: true);
  }

  static void exportReminders(File toFile) {
    var jsonData = _prefs.getString(ScheduleDataStore.jsonRemindersKey);
    logger.d('export, tofile:${toFile.path}: $jsonData');
    toFile.writeAsStringSync(jsonData, flush: true);
  }

  static void importReminders(File importFile) async {
    String jsonData = importFile.readAsStringSync();
    logger.d('restore, file=${importFile.path}: $jsonData');
    _prefs.setString(ScheduleDataStore.jsonRemindersKey, jsonData);
  }

  static Future<InMemoryScheduleDataStore> restore(File backupFile) async {
    String jsonData = backupFile.readAsStringSync();
    logger.d('restore, file=${backupFile.path}: $jsonData');
    Map<String, dynamic> jsonMap = json.decoder.convert(jsonData);
    return await _initFromJson(jsonMap);
  }

  static Future<InMemoryScheduleDataStore> restoreFromJson(
      String jsonData) async {
    logger.d('restore, : $jsonData');
    Map<String, dynamic> jsonMap = json.decoder.convert(jsonData);
    return await _initFromJson(jsonMap);
  }

  // ISSUE maybe change this to use InMemoryScheduleDataStore
  static String _toJson({bool backup = false}) {
    Map<String, dynamic> toMap = Map();
    for (var key in _prefs.getKeys()) {
      if (backup && key == enabledKey) {
        // always backup as disabled:
        toMap[key] = false;
      } else {
        toMap[key] = _prefs.get(key);
      }
    }
    return json.encoder.convert(toMap);
  }

  static Future<InMemoryScheduleDataStore> _initFromJson(
      Map<String, dynamic> jsonMap) async {
    for (var key in jsonMap.keys) {
      setSync(key, jsonMap[key]);
    }
    return ScheduleDataStore.getInMemoryInstance();
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
      logger.i("merging $key => $val");
      setSync(key, val);
    }
  }

  void merge(InMemoryScheduleDataStore mds) {
    logger.i("merge: $mds");
    _mergeVal(enabledKey, mds.enabled);
    _mergeVal(muteKey, mds.mute);
    _mergeVal(vibrateKey, mds.vibrate);
    _mergeVal(useBackgroundServiceKey, mds.useBackgroundService);
    _mergeVal(useStickyNotificationKey, mds.useStickyNotification);
    _mergeVal(includeDebugInfoKey, mds.includeDebugInfo);
    _mergeVal(hideNextReminderKey, mds.hideNextReminder);
    _mergeVal(scheduleTypeKey, mds.scheduleTypeStr);
    _mergeVal(periodicHoursKey, mds.periodicHours);
    _mergeVal(periodicMinutesKey, mds.periodicMinutes);
    _mergeVal(randomMinMinutesKey, mds.randomMinMinutes);
    _mergeVal(randomMaxMinutesKey, mds.randomMaxMinutes);
    _mergeVal(quietHoursStartHourKey, mds.quietHoursStartHour);
    _mergeVal(quietHoursStartMinuteKey, mds.quietHoursStartMinute);
    _mergeVal(quietHoursEndHourKey, mds.quietHoursEndHour);
    _mergeVal(quietHoursEndMinuteKey, mds.quietHoursEndMinute);
    _mergeVal(notifyQuietHoursKey, mds.notifyQuietHours);
    _mergeVal(reminderMessageKey, mds.reminderMessage);
    // _mergeVal(remindersKey, mds.reminders);
    _mergeVal(jsonRemindersKey, mds.jsonReminders);
    _mergeVal(infoMessageKey, mds.infoMessage);
    _mergeVal(controlMessageKey, mds.controlMessage);
    _mergeVal(themeKey, mds.theme);
    _mergeVal(bellIdKey, mds.bellId);
    _mergeVal(customBellPathKey, mds.customBellPath);
  }

  void dumpToLog() {
    logger.d("ScheduleDataStore: ${_toJson()}");
  }

  static Future<void> setSync(String key, dynamic val) async {
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

  set includeDebugInfo(bool value) {
    setSync(ScheduleDataStore.includeDebugInfoKey, value);
  }

  @override
  bool get hideNextReminder {
    if (!_prefs.containsKey(ScheduleDataStore.hideNextReminderKey)) {
      hideNextReminder = false;
    }
    return _prefs.getBool(ScheduleDataStore.hideNextReminderKey);
  }

  set hideNextReminder(bool value) {
    setSync(ScheduleDataStore.hideNextReminderKey, value);
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

  // set notifyQuietHours(bool value) {
  //   setSync(notifyQuietHoursKey, value);
  // }

  @override
  bool get notifyQuietHours {
    return defaultNotifyQuietHours;
    // if (!_prefs.containsKey(ScheduleDataStore.notifyQuietHoursKey)) {
    //   notifyQuietHours = defaultNotifyQuietHours;
    // }
    // return _prefs.getBool(ScheduleDataStore.notifyQuietHoursKey);
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

  // @deprecated
  // set remindersDeprecated(List<String> value) {
  //   setSync(remindersKeyDeprecated, value);
  // }

  // @override
  // List<String> get remindersDeprecated {
  //   if (_prefs.containsKey(ScheduleDataStore.remindersKeyDeprecated)) {
  //     return _prefs.getStringList(ScheduleDataStore.remindersKeyDeprecated);
  //   }
  //   return [];
  // }

  set jsonReminders(String jsonString) {
    setSync(jsonRemindersKey, jsonString);
  }

  @override
  String get jsonReminders {
    // Check for migration to new format:
    if (_prefs.containsKey(ScheduleDataStore.remindersKeyDeprecated)) {
      // old reminders list is still here: convert it to json and remove it
      List<String> remindersOrig =
          _prefs.getStringList(ScheduleDataStore.remindersKeyDeprecated);
      jsonReminders = Reminders.migrateToJson(remindersOrig);
      _prefs.remove(ScheduleDataStore.remindersKeyDeprecated);
      return jsonReminders;
    }
    if (!_prefs.containsKey(ScheduleDataStore.jsonRemindersKey)) {
      // save the string pretty-printed so it will also be exported in this format
      JsonEncoder encoder = new JsonEncoder.withIndent('  ');
      jsonReminders = encoder.convert(defaultJsonReminderMap);
    }
    return _prefs.getString(ScheduleDataStore.jsonRemindersKey);
  }

  // In future it's probably worth moving json reminders into their own class
  String randomReminder({String tag}) {
    List jsonReminderList = json.decode(jsonReminders);
    jsonReminderList.shuffle();
    for (Map<String, dynamic> reminder in jsonReminderList) {
      if (tag != null) {
        if (!reminder.containsKey('tag') || reminder['tag'] != tag) {
          continue;
        }
      }
      // enabled entry is optional
      if (!reminder.containsKey('enabled') || reminder['enabled']) {
        return reminder['text'];
      }
    }
    return tag == null
        ? "No reminders are enabled"
        : "No reminders are enabled for tag '$tag'";
  }
}

class Reminder {
  final int index;
  String text;
  bool enabled;
  String tag;

  Reminder(this.index, this.text, this.tag, this.enabled);

  Reminder.fromJson(int index, Map<String, dynamic> jsonMapEntry)
      : index = index,
        text = jsonMapEntry['text'],
        tag = jsonMapEntry['tag'],
        enabled = jsonMapEntry['enabled'];

  Map<String, dynamic> toJsonMapEntry() => {
        'index': index,
        'text': text,
        'tag': tag,
        'enabled': enabled,
      };

  @override
  String toString() {
    return "Reminder: index=$index, tag=$tag, enabled=$enabled, text=$text";
  }
}

class Reminders {
  final List<Reminder> allReminders;
  Reminders(this.allReminders);

  // ReminderList.fromJson(List<Map<String, dynamic>> json)
  //     : reminders = json.map((e) => Reminder.fromJson(index++, e));

  Reminders.fromDecodedJson(List<Map<String, dynamic>> decodedJson)
      : allReminders = [] {
    int index = 0;
    for (Map<String, dynamic> jsonMapEntry in decodedJson) {
      Reminder reminder = Reminder.fromJson(index++, jsonMapEntry);
      allReminders.add(reminder);
    }
  }

  Reminders.fromJsonString(String jsonData) : allReminders = [] {
    // List<Map<String, dynamic>> jsonReminderList = jsonDecode(jsonData);
    List jsonReminderList = json.decode(jsonData);
    int index = 0;
    for (Map<String, dynamic> jsonMapEntry in jsonReminderList) {
      Reminder reminder = Reminder.fromJson(index++, jsonMapEntry);
      allReminders.add(reminder);
    }
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

  List<Reminder> getFilteredReminderList({String tag}) {
    if (tag == null || tag == '') {
      return allReminders;
    }
    Map<String, List<Reminder>> groupedReminders = buildGroupedReminders();
    if (!groupedReminders.containsKey(tag)) {
      logger.e("tag '$tag' not in reminderGroups");
      return [];
    }
    return groupedReminders[tag];
  }

  void addReminder(Reminder reminder) {
    // apply new index, which is at the end of the list
    allReminders.add(Reminder(
        allReminders.length, reminder.text, reminder.tag, reminder.enabled));
  }

  void updateReminder(Reminder changedReminder) {
    allReminders[changedReminder.index] = changedReminder;
  }

  void deleteReminder(int index) {
    allReminders.removeAt(index);
    // Now re-index all the reminders
    index = 0;
    for (int index = 0; index < allReminders.length; index++) {
      allReminders[index] = Reminder(index, allReminders[index].text,
          allReminders[index].tag, allReminders[index].enabled);
    }
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
    // logger.d("Reminders toJson: $jsonReminders");
    return jsonReminders;
  }

  static String migrateToJson(List<String> reminderList) {
    // old reminders list is still here: convert it to json and remove it
    logger.i("Migrating reminders to json");
    List<Map> conversionList = [];
    for (String rawReminder in reminderList) {
      Map<String, dynamic> mapForJson = Map();
      mapForJson['text'] = rawReminder;
      mapForJson['enabled'] = true;
      mapForJson['tag'] = "default";
      conversionList.add(mapForJson);
    }
    String jsonReminders;
    // save the string pretty-printed so it will also be exported in this format
    JsonEncoder encoder = new JsonEncoder.withIndent('  ');
    jsonReminders = encoder.convert(conversionList);
    logger.i("Finished reminder migration to json: $jsonReminders");
    return jsonReminders;
  }

  String randomReminder({String tag}) {
    allReminders.shuffle();
    for (Reminder reminder in allReminders) {
      if (tag != null) {
        if (reminder.tag != tag) {
          continue;
        }
      }
      // enabled entry is optional
      if (reminder.enabled) {
        return reminder.text;
      }
    }
    return tag == null
        ? "No reminders are enabled"
        : "No reminders are enabled for tag '$tag'";
  }
}
