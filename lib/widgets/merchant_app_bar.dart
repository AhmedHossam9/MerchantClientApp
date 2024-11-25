import 'package:flutter/material.dart';
import 'package:demo/utils/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MerchantAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleKey;
  final bool showBackButton;
  final bool isHomePage;
  
  const MerchantAppBar({
    Key? key,
    required this.titleKey,
    this.showBackButton = true,
    this.isHomePage = false,
  }) : super(key: key);

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        // Navigate to welcome screen and clear the navigation stack
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/welcome', 
          (Route<dynamic> route) => false
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('error_logging_out'),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFFe2211c)),
              onPressed: () => Navigator.pop(context),
            )
          else
            const SizedBox(width: 48),
          
          Row(
            children: [
              Image.asset(
                'assets/efinance.png',
                height: 55,
                width: 55,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).translate(titleKey),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF062f6e),
                ),
              ),
            ],
          ),
          if (isHomePage)
            IconButton(
              icon: const Icon(
                Icons.logout,
                color: Color(0xFFe2211c),
              ),
              onPressed: () => _handleLogout(context),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}