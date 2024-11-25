import 'package:flutter/material.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import 'governmental_service_details_screen.dart';

class GovernmentalServicesScreen extends StatelessWidget {
  const GovernmentalServicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(
              titleKey: 'governmental_services',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildServiceCard(
                      context,
                      icon: Icons.local_police_rounded,
                      titleKey: 'police',
                      descriptionKey: 'police_desc',
                      color: const Color(0xFF062f6e),
                      onTap: () => _launchService('police', context),
                    ),
                    _buildServiceCard(
                      context,
                      icon: Icons.emergency_rounded,
                      titleKey: 'ambulance',
                      descriptionKey: 'ambulance_desc',
                      color: const Color(0xFFe2211c),
                      onTap: () => _launchService('ambulance', context),
                    ),
                    _buildServiceCard(
                      context,
                      icon: Icons.location_city_rounded,
                      titleKey: 'city_council',
                      descriptionKey: 'city_council_desc',
                      color: const Color(0xFF1565C0),
                      onTap: () => _launchService('city', context),
                    ),
                    _buildServiceCard(
                      context,
                      icon: Icons.local_hospital_rounded,
                      titleKey: 'hospital',
                      descriptionKey: 'hospital_desc',
                      color: const Color(0xFF2E7D32),
                      onTap: () => _launchService('hospital', context),
                    ),
                    _buildServiceCard(
                      context,
                      icon: Icons.electric_bolt_rounded,
                      titleKey: 'electricity',
                      descriptionKey: 'electricity_desc',
                      color: const Color(0xFFED6C02),
                      onTap: () => _launchService('electricity', context),
                    ),
                    _buildServiceCard(
                      context,
                      icon: Icons.water_drop_rounded,
                      titleKey: 'water',
                      descriptionKey: 'water_desc',
                      color: const Color(0xFF0288D1),
                      onTap: () => _launchService('water', context),
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

  Widget _buildServiceCard(
    BuildContext context, {
    required IconData icon,
    required String titleKey,
    required String descriptionKey,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? color.withOpacity(0.15)
                        : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: isDarkMode 
                        ? color.withOpacity(0.9)
                        : color,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate(titleKey),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).translate(descriptionKey),
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 20,
                  color: isDarkMode ? Colors.grey[400] : color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchService(String service, BuildContext context) {
    final Map<String, Color> serviceColors = {
      'police': const Color(0xFF062f6e),
      'ambulance': const Color(0xFFe2211c),
      'city': const Color(0xFF1565C0),
      'hospital': const Color(0xFF2E7D32),
      'electricity': const Color(0xFFED6C02),
      'water': const Color(0xFF0288D1),
    };

    final Map<String, IconData> serviceIcons = {
      'police': Icons.local_police_rounded,
      'ambulance': Icons.emergency_rounded,
      'city': Icons.location_city_rounded,
      'hospital': Icons.local_hospital_rounded,
      'electricity': Icons.electric_bolt_rounded,
      'water': Icons.water_drop_rounded,
    };

    final Map<String, String> searchQueries = {
      'police': 'police station Sharm El Sheikh',
      'ambulance': 'hospitals in Sharm El Sheikh',
      'city': 'Sharm El Sheikh City Council',
      'hospital': 'hospitals in Sharm El Sheikh',
      'electricity': 'electricity company Sharm El Sheikh',
      'water': 'water company Sharm El Sheikh',
    };

    final Map<String, String> emergencyNumbers = {
      'police': '122',
      'ambulance': '123',
      'city': '',
      'hospital': '123',
      'electricity': '',
      'water': '',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GovernmentalServiceDetailsScreen(
          serviceKey: service,
          serviceColor: serviceColors[service]!,
          serviceIcon: serviceIcons[service]!,
          query: searchQueries[service]!,
          emergencyNumber: emergencyNumbers[service]!,
        ),
      ),
    );
  }
}