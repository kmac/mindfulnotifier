import 'package:shared_preferences/shared_preferences.dart';

class Reminders {
  SharedPreferences _prefs;
  static final String reminderKey = 'reminders';
  static final String reminderInitializedKey = 'remindersInitialized';

  // This is the initial list of reminders. It will only be used until the reminders are persisted...
  List<String> reminders = [
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
    "Sitting quietly, Doing nothing, Spring comes, and the grass grows, by itself.",
    // "If this fear is with me the rest of my life, that is okay.",
  ];
  List<String> shuffledReminders;

  Reminders() {
    init();
  }

  void init() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs.containsKey(reminderInitializedKey)) {
      load();
    } else {
      print("Initial reminders persistence");
      persist();
    }
    shuffledReminders = reminders.toList();
  }

  String randomReminder() {
    shuffledReminders.shuffle();
    return shuffledReminders.first;
  }

  void persist() {
    print("Persisting reminders into storage");
    _prefs.setStringList(reminderKey, reminders);
    _prefs.setBool(reminderInitializedKey, true);
  }

  void load() {
    print("Loading reminders from storage");
    reminders = _prefs.getStringList(reminderKey);
  }
}
