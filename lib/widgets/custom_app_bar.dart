import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Function(Locale) setLocale;
  final String username; // Define the username parameter

  // Add username parameter to the constructor
  CustomAppBar({required this.setLocale, required this.username});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight); // Standard AppBar height

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.black, // Set AppBar color to black
      elevation: 0, // Remove shadow
      title: Row(
        children: [
          SizedBox(width: 10), // Space between logo and title
          Text(
            'Welcome $username', // Display "Welcome Username"
            style: TextStyle(
              color: Colors.white, // White text color for contrast
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        // Language selection button
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'en') {
              setLocale(Locale('en'));
            } else if (value == 'ar') {
              setLocale(Locale('ar'));
            }
          },
          icon: Icon(Icons.language, color: Colors.white), // Language icon color
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(value: 'en', child: Text('English')),
            PopupMenuItem(value: 'ar', child: Text('العربية')),
          ],
        ),
        // Profile Button
        IconButton(
          icon: Icon(Icons.person, color: Colors.white),
          onPressed: () {
            // Handle profile navigation
          },
        ),
        // Logout Button
        IconButton(
          icon: Icon(Icons.logout, color: Colors.white),
          onPressed: () {
            // Handle logout action
          },
        ),
      ],
    );
  }
}
