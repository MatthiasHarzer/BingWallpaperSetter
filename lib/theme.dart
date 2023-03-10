import 'package:flutter/material.dart';

const primaryColor = Colors.deepPurple;
const primaryTextColor = Colors.purple;
const accentColor = Colors.deepPurpleAccent;

const TextStyle snackBarLinkStyle = TextStyle(color: accentColor);



final _appTheme = ThemeData(
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith((states) =>
    states.contains(MaterialState.selected) ? accentColor : null),
    trackColor: MaterialStateProperty.resolveWith((states) =>
    states.contains(MaterialState.selected) ? primaryColor[500] : null),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: Colors.grey.shade900,
    contentTextStyle: const TextStyle(color: Colors.white),
    actionTextColor: accentColor,
  ),
  appBarTheme: AppBarTheme(backgroundColor: primaryColor[400]),
  primarySwatch: primaryColor,
  brightness: Brightness.dark,

  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      textStyle: MaterialStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w500, color: primaryColor),
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      textStyle: MaterialStateProperty.all(
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  ),
);

final appTheme = _appTheme.copyWith(
  textTheme: _appTheme.textTheme.apply(
    bodyColor: Colors.grey[200],

    // displayColor: Colors.black
  ),
  colorScheme: _appTheme.colorScheme.copyWith(secondary: primaryTextColor[700]),
);
