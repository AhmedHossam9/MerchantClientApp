import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import 'package:flutter/services.dart';

class GovernmentalServiceDetailsScreen extends StatelessWidget {
  final String serviceKey;
  final Color serviceColor;
  final IconData serviceIcon;
  final String query;
  final String emergencyNumber;

  const GovernmentalServiceDetailsScreen({
    Key? key,
    required this.serviceKey,
    required this.serviceColor,
    required this.serviceIcon,
    required this.query,
    required this.emergencyNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(
              titleKey: serviceKey,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Service Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: isDarkMode ? [] : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Icon Container
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDarkMode 
                                  ? serviceColor.withOpacity(0.15)
                                  : serviceColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              serviceIcon,
                              size: 56,
                              color: serviceColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Service Title
                          Text(
                            AppLocalizations.of(context).translate(serviceKey),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.grey[800],
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (emergencyNumber.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode 
                                        ? serviceColor.withOpacity(0.15)
                                        : serviceColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    emergencyNumber,
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: serviceColor,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDarkMode 
                                        ? serviceColor.withOpacity(0.15)
                                        : serviceColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _copyToClipboard(context),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(
                                          Icons.copy_rounded,
                                          color: serviceColor,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Action Buttons
                    Column(
                      children: [
                        // Map Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isDarkMode ? [] : [
                              BoxShadow(
                                color: serviceColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _openMaps(query),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: serviceColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.map_rounded, size: 24),
                            label: Text(
                              AppLocalizations.of(context).translate('view_on_map'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        if (emergencyNumber.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          // Emergency Call Button
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isDarkMode ? [] : [
                                BoxShadow(
                                  color: serviceColor.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _makePhoneCall(emergencyNumber),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: serviceColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 20,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.phone_rounded, size: 24),
                              label: Text(
                                AppLocalizations.of(context).translate('call_now'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMaps(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://www.google.com/maps/search/?api=1&query=$encodedQuery';
    
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final url = 'tel:$phoneNumber';
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: emergencyNumber)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).translate('number_copied'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: serviceColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }
} 