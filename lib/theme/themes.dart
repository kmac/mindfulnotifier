import 'package:flutter/material.dart';

ThemeData indigoTheme = ThemeData(
  // primarySwatch: Colors.deepOrange,
  primarySwatch: Colors.indigo,
  brightness: Brightness.dark,
  appBarTheme: AppBarTheme(
    color: Colors.indigo,
    // textTheme: TextTheme(
    //   headline6: GoogleFonts.exo2(
    //     color: Colors.white,
    //     fontSize: 18,
    //     fontWeight: FontWeight.bold,
  ),
  // ),
);

ThemeData defaultTheme = indigoTheme;

Map<String, ThemeData> allThemes = {
  'Default': defaultTheme,
  'Light': ThemeData.light(),
  'Dark': ThemeData.dark(),
  'Blue': ThemeData(
    primarySwatch: Colors.blue,
    appBarTheme: AppBarTheme(
      color: Colors.blue,
    ),
  ),
  'BlueGrey': ThemeData(
    primarySwatch: Colors.blueGrey,
    appBarTheme: AppBarTheme(
      color: Colors.blueGrey,
    ),
  ),
  'Grey': ThemeData(
    primarySwatch: Colors.grey,
    appBarTheme: AppBarTheme(
      color: Colors.grey,
    ),
  ),
  'Red': ThemeData(
    primarySwatch: Colors.red,
    appBarTheme: AppBarTheme(
      color: Colors.red,
    ),
  ),
  'Orange': ThemeData(
    primarySwatch: Colors.deepOrange,
    appBarTheme: AppBarTheme(
      color: Colors.deepOrange,
    ),
  ),
  'Green': ThemeData(
    primarySwatch: Colors.green,
    appBarTheme: AppBarTheme(
      color: Colors.green,
    ),
  ),
};
