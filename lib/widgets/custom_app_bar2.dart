import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Function(Locale) setLocale;

  const CustomAppBar({Key? key, required this.setLocale}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      title: Row(
        children: [
          const SizedBox(width: 10),
          Text(
            'Sharm Super App',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        // Theme Toggle Button
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return RotationTransition(
                turns: animation,
                child: child,
              );
            },
            child: Icon(
              isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey<bool>(isDarkMode),
              color: const Color(0xFF062f6e),
            ),
          ),
          onPressed: () {
            themeProvider.toggleTheme();
          },
          tooltip: isDarkMode ? 'Light Mode' : 'Dark Mode',
        ),
        // Language Selector
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'en') {
              setLocale(const Locale('en'));
            } else if (value == 'ar') {
              setLocale(const Locale('ar'));
            }
          },
          icon: const Icon(
            Icons.language, 
            color: Color(0xFF062f6e),
          ),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'en',
              child: Row(
                children: [
                  const Icon(Icons.language, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'English',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'ar',
              child: Row(
                children: [
                  const Icon(Icons.language, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'العربية',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8), // Add some padding at the end
      ],
    );
  }
}
