import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = Logger(printer: SimpleLogPrinter('reminders'));

class Reminders {
  static const String reminderKey = 'reminders';
  static const String reminderInitializedKey = 'remindersInitialized';

  // This is the initial list of reminders. It will only be used until the reminders are persisted...
  static const List<String> defaultReminders = [
    "Are you aware?",
    "Breathe deeply. There is only the present moment.",
    "Be present in this moment.",
    "Let go of greed, aversion, and delusion.",
    "Trust the universe.",
    "Respond, not react.",
    "All of this is impermanent.",
    "Connect, then correct.",
    "Accept the feeling of what is happening in this moment. Don't struggle against it. Instead, notice it. Take it in.",
    // "Remember RAIN: Recognize / Allow / Invesigate with interest and care / Nurture with self-compassion",
    "Note feeling tones (flavour): Pleasant / Unpleasant / Neutral",
    "What is the attitude in the mind right now?",
    "May you be safe and free from harm. May you be healthy and free from suffering. May you be happy. May you be peaceful and live with ease.",
    "Whatever it is that has the nature to arise will also pass away; therefore, there is nothing to want.",
    "Sitting quietly, Doing nothing, Spring comes, and the grass grows, by itself. -- Bashō",
    // "If this fear is with me the rest of my life, that is okay.",
  ];
  static SharedPreferences _prefs;

  List<String> reminders;
  List<String> shuffledReminders;

  /// Public factory
  static Future<Reminders> create() async {
    var component = Reminders._create();
    await component._init();
    return component;
  }

  /// Private constructor
  Reminders._create() {
    logger.i("Creating Reminders");
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    reload();
    if (_prefs.containsKey(reminderInitializedKey)) {
      load();
    } else {
      print("Creating initial default reminders");
      persist(defaultReminders);
    }
    shuffledReminders = reminders.toList();
  }

  String randomReminder() {
    shuffledReminders.shuffle();
    return shuffledReminders.first;
  }

  void persist([List<String> newReminderList]) async {
    if (newReminderList == null) {
      newReminderList = reminders;
    }
    print("Persisting reminders into storage");
    await _prefs.setStringList(reminderKey, newReminderList);
    await _prefs.setBool(reminderInitializedKey, true);
  }

  void reload() async {
    await _prefs.reload();
  }

  void load() {
    print("Loading reminders from storage");
    reminders = _prefs.getStringList(reminderKey);
  }
}
