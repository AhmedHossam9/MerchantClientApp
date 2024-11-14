import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData customTheme = ThemeData(
    brightness: Brightness.light, // Ensure it's light mode
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: Color(0xFFe2211c),
      secondary: Color(0xFF062f6e),
    ),
    scaffoldBackgroundColor: Colors.white, // Set white background for light mode
    fontFamily: 'Roboto',
  );
}
