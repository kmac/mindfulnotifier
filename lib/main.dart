import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:remindfulbell/screens/app/remindfulbell.dart';

const String appName = 'ReMindful Bell';

void main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  runApp(RemindfulApp(appName));
}
