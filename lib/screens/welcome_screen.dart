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
      appBar: CustomAppBar(setLocale: setLocale),
      body: Stack(
        children: [
          // Keep your existing SlideshowBackground
          SlideshowBackground(
            imagePaths: [
              'assets/background1.png',
              'assets/background2.png',
              'assets/background3.png',
              'assets/background4.png'
            ],
            blurAmount: 5.0,
          ),
          
          // Improved content layout
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: Hero(
                      tag: 'logo',
                      child: Container(
                        constraints: BoxConstraints(maxWidth: 280),
                        margin: EdgeInsets.only(top: 40),
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/efinance.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: _buildButton(
                            context: context,
                            icon: Icons.login_rounded,
                            label: AppLocalizations.of(context).translate('login'),
                            isPrimary: true,
                            onPressed: () => Navigator.pushNamed(context, '/login'),
                          ),
                        ),
                        SizedBox(height: 16),
                        Center(
                          child: _buildButton(
                            context: context,
                            icon: Icons.person_add_rounded,
                            label: AppLocalizations.of(context).translate('register'),
                            isPrimary: false,
                            onPressed: () => Navigator.pushNamed(context, '/register'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.7,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? Theme.of(context).primaryColor
              : Theme.of(context).colorScheme.secondary,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
