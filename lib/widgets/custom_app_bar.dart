import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Function(Locale) setLocale;
  final String username;

  const CustomAppBar({
    Key? key,
    required this.setLocale,
    required this.username,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.logout_rounded,
          color: Colors.white,
          size: 24,
        ),
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/welcome',
            (route) => false,
          );
        },
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a237e),
              Color(0xFF534bae),
            ],
          ),
        ),
      ),
      title: Text(
        AppLocalizations.of(context).translate('welcome_user').replaceAll('{username}', username),
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () {
            // Profile functionality will be added later
          },
        ),
        SizedBox(width: 8),
      ],
    );
  }
}