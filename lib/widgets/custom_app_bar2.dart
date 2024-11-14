import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Function(Locale) setLocale;

  CustomAppBar({required this.setLocale});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight); // AppBar height

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white, // Light theme AppBar color
      elevation: 0, // Remove shadow
      title: Row(
        children: [
          SizedBox(width: 10), // Space between logo and title
          Text(
            'MerchantClientApp',
            style: TextStyle(
              color: Color.fromARGB(255, 0, 0, 0), // Set dark color for title text
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'en') {
              setLocale(Locale('en'));
            } else if (value == 'ar') {
              setLocale(Locale('ar'));
            }
          },
          icon: Icon(Icons.language, color: Color(0xFF062f6e)), // Dark color for icon
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(value: 'en', child: Text('English')),
            PopupMenuItem(value: 'ar', child: Text('العربية')),
          ],
        ),
      ],
    );
  }
}
