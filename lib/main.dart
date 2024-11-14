import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Import firebase_core
import 'firebase_options.dart'; // Import firebase_options.dart
import 'utils/app_localizations.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Pass Firebase options
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = Locale('en'); // Default language is English

  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Merchant-Client App',
      locale: _locale,
      theme: AppTheme.customTheme,
      supportedLocales: [
        Locale('en'), // English
        Locale('ar'), // Arabic
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: WelcomeScreen(setLocale: _setLocale), // Directly pass the setLocale function
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/welcome': (context) => WelcomeScreen(setLocale: _setLocale)
      },
    );
  }
}
