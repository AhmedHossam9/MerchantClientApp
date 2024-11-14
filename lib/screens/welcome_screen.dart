import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import '../widgets/custom_app_bar2.dart'; // Import the custom app bar
import '../widgets/slideshow_background.dart'; // Import the slideshow background

class WelcomeScreen extends StatelessWidget {
  final Function(Locale) setLocale;

  // Constructor now expects the setLocale parameter
  WelcomeScreen({required this.setLocale});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(setLocale: setLocale), // Use the custom app bar
      body: Stack(
        children: [
          // Slideshow Background Widget
          SlideshowBackground(
            imagePaths: [
              'assets/background1.png',
              'assets/background2.png',
              'assets/background3.png',
              'assets/background4.png'
            ],
            blurAmount: 5.0, // Adjust the blur level as desired
          ),
          
          // Main Content with Centered Column
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with a semi-transparent white background and black stroke
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7), // Adjusted opacity for cleaner look
                    border: Border.all(
                      color: Colors.black, // Black stroke around the logo
                      width: 3.0, // Stroke width
                    ),
                    borderRadius: BorderRadius.circular(8.0), // Optional: rounded corners
                  ),
                  padding: EdgeInsets.all(10), // Add padding to give space around the logo
                  child: Image.asset(
                    'assets/efinance.png',
                    height: 150,
                    width: 150,
                    fit: BoxFit.cover, // Adjust the fit if needed
                  ),
                ),
                SizedBox(height: 40), // Space between logo and buttons

                // Login Button
                ElevatedButton.icon(
                  icon: Icon(Icons.login, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  label: Text(
                    AppLocalizations.of(context).translate('login'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                SizedBox(height: 20),  // Space between buttons

                // Register Button
                ElevatedButton.icon(
                  icon: Icon(Icons.app_registration, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  label: Text(
                    AppLocalizations.of(context).translate('register'),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
