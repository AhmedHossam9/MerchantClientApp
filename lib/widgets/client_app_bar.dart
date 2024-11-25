import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:demo/utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class ClientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleKey;
  
  const ClientAppBar({
    Key? key,
    required this.titleKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121212) : Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.logout, 
              color: const Color(0xFFe2211c),
              size: 28
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/welcome', 
                (route) => false
              );
            },
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Image.asset(
                  'assets/sharmlogo.png',
                  height: 64,
                  width: 64,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppLocalizations.of(context).translate(titleKey),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                  letterSpacing: 0.5,
                  shadows: isDarkMode ? [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ] : [],
                ),
              ),
            ],
          ),
          CircleAvatar(
            backgroundColor: isDarkMode 
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFe2211c).withOpacity(0.1),
            radius: 24,
            child: Icon(
              Icons.person,
              color: const Color(0xFFe2211c),
              size: 28
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}