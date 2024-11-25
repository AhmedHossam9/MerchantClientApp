import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class VisaDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> visaData;

  const VisaDetailsScreen({
    Key? key,
    required this.visaData,
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
              titleKey: 'visa_details',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // QR Code Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white, // Keep white for QR readability
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: visaData['visaReference'] ?? '',
                              version: QrVersions.auto,
                              size: 200.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context).translate('scan_qr_info'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Visa Information Section
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).translate('visa_information'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildInfoRow(
                            context,
                            'full_name',
                            visaData['fullName'] ?? '',
                            icon: Icons.person_rounded,
                          ),
                          _buildInfoRow(
                            context,
                            'nationality',
                            visaData['nationality'] ?? '',
                            icon: Icons.flag_rounded,
                          ),
                          _buildInfoRow(
                            context,
                            'visa_ref',
                            visaData['visaReference'] ?? '',
                            icon: Icons.numbers_rounded,
                          ),
                          _buildInfoRow(
                            context,
                            'visa_type',
                            visaData['visaEntry'] ?? '',
                            icon: Icons.credit_card_rounded,
                          ),
                          _buildInfoRow(
                            context,
                            'valid_until',
                            _calculateValidUntil(visaData['dateOfEntrance'], visaData['visaDuration']),
                            icon: Icons.calendar_today_rounded,
                          ),
                        ],
                      ),
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

  Widget _buildInfoRow(BuildContext context, String label, String value, {required IconData icon}) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFe2211c).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFFe2211c),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate(label),
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateValidUntil(dynamic entryDate, dynamic duration) {
    if (entryDate == null || duration == null) return 'N/A';
    try {
      final entry = DateTime.parse(entryDate.toString());
      final durationInDays = int.tryParse(duration.toString()) ?? 30;
      final validUntil = entry.add(Duration(days: durationInDays));
      return '${validUntil.year}-${validUntil.month.toString().padLeft(2, '0')}-${validUntil.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}