import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';

const String appName = 'Mindful Notifier';

void main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  RemindfulApp app = RemindfulApp(appName);
  app.init();
  runApp(app);
}
