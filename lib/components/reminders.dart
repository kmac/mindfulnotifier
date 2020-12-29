import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindfulnotifier/components/logging.dart';

var logger = createLogger('reminders');

class Reminders {
  static const String reminderKey = 'reminders';
  static const String reminderInitializedKey = 'remindersInitialized';

  // This is the initial list of reminders. It will only be used until the reminders are persisted...
  static const List<String> defaultReminders = [
    "Are you aware?",
    "Breathe deeply. This is the present moment.",
    "Take a moment to pause, and come back to the present.",
    "Bring awareness into this moment.",
    "Let go of greed, aversion, and delusion.",
    "Respond, not react.",
    "All of this is impermanent.",
    "Accept the feeling of what is happening in this moment. Don't struggle against it. Instead, notice it. Take it in.",
    // "RAIN: Recognize / Allow / Invesigate with interest and care / Nurture with self-compassion",
    "Note any feeling tones in the moment: Pleasant / Unpleasant / Neutral.",
    "What is the attitude in the mind right now?",
    "May you be happy. May you be healthy. May you be free from harm. May you be peaceful.",
    "Whatever it is that has the nature to arise will also pass away; therefore, there is nothing to want.",
    "Sitting quietly, Doing nothing, Spring comes, and the grass grows, by itself. -- Bashō",
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
      persist();
    }
    shuffledReminders = reminders.toList();
  }

  String randomReminder() {
    shuffledReminders.shuffle();
    return shuffledReminders.first;
  }

  void persist() async {
    if (reminders == null) {
      reminders = defaultReminders.toList();
    }
    print("Persisting reminders into storage");
    await _prefs.setStringList(reminderKey, reminders);
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
