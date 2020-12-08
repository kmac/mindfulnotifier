import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mindfulnotifier/components/router.dart' as router;

import 'package:mindfulnotifier/screens/app/mindfulnotifier.dart';

void main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // GetMaterialApp(MindfulNotifierApp());
    GetMaterialApp(
      title: 'Mindful Notifier',
      debugShowCheckedModeBanner: false,
      defaultTransition: Transition.rightToLeft,
      getPages: router.Router.route,
      initialRoute: '/',
      theme: ThemeData(
        // primarySwatch: Colors.deepOrange,
        primarySwatch: Colors.indigo,
        appBarTheme: AppBarTheme(
          // color: Colors.deepOrange,
          color: Colors.indigo,
          // textTheme: TextTheme(
          //   headline6: GoogleFonts.exo2(
          //     color: Colors.white,
          //     fontSize: 18,
          //     fontWeight: FontWeight.bold,
          //   ),
        ),
      ),
    ),
  );
}
