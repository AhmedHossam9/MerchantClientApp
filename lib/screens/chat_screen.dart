import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import 'package:demo/widgets/client_app_bar.dart';
import 'package:demo/widgets/animated_nav_bar.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ClientAppBar(titleKey: 'chat'),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context).translate('chat_coming_soon'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF062f6e),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        AppLocalizations.of(context).translate('chat_description'),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedNavBar(
              selectedIndex: 3, // Chat tab index
              onItemSelected: (index) {
                if (index == 3) return; // Already on chat
                switch (index) {
                  case 0:
                    Navigator.pushReplacementNamed(context, '/services_home_page');
                    break;
                  case 1:
                    Navigator.pushReplacementNamed(context, '/browse');
                    break;
                  case 2:
                    Navigator.pushReplacementNamed(context, '/favorites');
                    break;
                  case 4:
                    Navigator.pushReplacementNamed(context, '/cart');
                    break;
                  case 5:
                    Navigator.pushReplacementNamed(context, '/profile');
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}