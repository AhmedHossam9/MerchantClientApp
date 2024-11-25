import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/client_app_bar.dart';
import '../widgets/animated_nav_bar.dart';
import '../widgets/loading_overlay.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class ServicesHomePage extends StatefulWidget {
  final String username;
  final Function(Locale) setLocale;

  const ServicesHomePage({
    Key? key, 
    required this.username,
    required this.setLocale,
  }) : super(key: key);

  @override
  State<ServicesHomePage> createState() => _ServicesHomePageState();
}

class _ServicesHomePageState extends State<ServicesHomePage> {
  int _selectedIndex = 0;
  bool _isLoading = false;

  Future<void> _navigateWithLoading(String route) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      try {
        await Navigator.pushNamed(context, route);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _launchTaxiApp(BuildContext context) async {
    setState(() => _isLoading = true);
    
    try {
      // Android - Google Play Store
      if (Platform.isAndroid) {
        // Try Google Play Store first
        const playStoreUrl = 'market://details?id=sharm.taxi.passenger';
        if (await canLaunch(playStoreUrl)) {
          await launch(playStoreUrl);
        } else {
          // Fallback to browser URL for Play Store
          const webUrl = 'https://play.google.com/store/apps/details?id=sharm.taxi.passenger&hl=en-US';
          if (await canLaunch(webUrl)) {
            await launch(webUrl);
          } else {
            throw 'Could not launch store';
          }
        }
      } 
      // iOS - App Store
      else if (Platform.isIOS) {
        const appStoreUrl = 'https://apps.apple.com/us/app/sharmtaxi/id1611534759';
        if (await canLaunch(appStoreUrl)) {
          await launch(appStoreUrl);
        } else {
          throw 'Could not launch store';
        }
      }
      // Web or other platforms - Fallback to Play Store web URL
      else {
        const webUrl = 'https://play.google.com/store/apps/details?id=sharm.taxi.passenger&hl=en-US';
        if (await canLaunch(webUrl)) {
          await launch(webUrl);
        } else {
          throw 'Could not launch store';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('store_error'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
          body: SafeArea(
            child: Column(
              children: [
                ClientAppBar(
                  titleKey: '',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildServices(isDarkMode),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: AnimatedNavBar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
        ),
        if (_isLoading)
          const LoadingOverlay(),
      ],
    );
  }

  Widget _buildServices(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate('discover_sharm'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildServiceCard(
              icon: 'assets/entertainment.png',
              title: AppLocalizations.of(context).translate('entertainment'),
              onTap: () => _navigateWithLoading('/entertainment'),
              isDarkMode: isDarkMode,
            ),
            _buildServiceCard(
              icon: 'assets/events.png',
              title: AppLocalizations.of(context).translate('events'),
              onTap: () => _navigateWithLoading('/events'),
              isDarkMode: isDarkMode,
            ),
            _buildServiceCard(
              icon: 'assets/museums.png',
              title: AppLocalizations.of(context).translate('egypt_museums'),
              onTap: () => _navigateWithLoading('/museums'),
              isDarkMode: isDarkMode,
            ),
            _buildServiceCard(
              icon: 'assets/services.png',
              title: AppLocalizations.of(context).translate('sharm_services'),
              onTap: () => _navigateWithLoading('/services'),
              isDarkMode: isDarkMode,
            ),
            _buildServiceCard(
              icon: 'assets/visa.png',
              title: AppLocalizations.of(context).translate('visa_arrival'),
              onTap: () => _navigateWithLoading('/visa'),
              isDarkMode: isDarkMode,
            ),
            _buildServiceCard(
              icon: 'assets/taxi.png',
              title: AppLocalizations.of(context).translate('sharm_taxi'),
              onTap: () => _launchTaxiApp(context),
              isDarkMode: isDarkMode,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required String icon,
    required String title,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              icon,
              height: 80,
              width: 80,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
              ),
            ),
          ],
        ),
      ),
    );
  }
}