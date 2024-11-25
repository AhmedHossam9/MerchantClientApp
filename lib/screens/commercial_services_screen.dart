import 'package:flutter/material.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';
import 'service_details_screen.dart';

class CommercialServicesScreen extends StatelessWidget {
  const CommercialServicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(
              titleKey: 'commercial_services',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildServiceCard(context,
                      icon: Icons.restaurant_rounded,
                      titleKey: 'restaurants',
                      descriptionKey: 'restaurants_desc',
                      color: const Color(0xFFE53935),
                      onTap: () => _launchService('restaurants', context),
                    ),
                    _buildServiceCard(
                      context,
                      icon: Icons.local_pharmacy_rounded,
                      titleKey: 'pharmacies',
                      descriptionKey: 'pharmacies_desc',
                      color: const Color(0xFF43A047),
                      onTap: () => _launchService('pharmacies', context),
                    ),
                    _buildServiceCard(
                      context,
                      icon: Icons.shopping_cart_rounded,
                      titleKey: 'supermarkets',
                      descriptionKey: 'supermarkets_desc',
                      color: const Color(0xFF1E88E5),
                      onTap: () => _launchService('supermarkets', context),
                    ),_buildServiceCard(
                      context,
                      icon: Icons.local_mall_rounded,
                      titleKey: 'shopping',
                      descriptionKey: 'shopping_desc',
                      color: const Color(0xFF8E24AA),
                      onTap: () => _launchService('shopping', context),
                    ),
                    _buildServiceCard(
                      context,
                      icon: Icons.local_gas_station_rounded,
                      titleKey: 'gas_stations',
                      descriptionKey: 'gas_stations_desc',
                      color: const Color(0xFFEF6C00),
                      onTap: () => _launchService('gas_stations', context),
                    ),
                    _buildServiceCard(
                      context,
                      icon: Icons.local_atm_rounded,
                      titleKey: 'banks_atms',
                      descriptionKey: 'banks_atms_desc',
                      color: const Color(0xFF00897B),
                      onTap: () => _launchService('banks', context),
                    ),                  ],
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
                  child: Icon(icon,
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
                      ),const SizedBox(height: 4),
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
      ),);
  }

  void _launchService(String service, BuildContext context) {
    final Map<String, Color> serviceColors = {
      'restaurants': const Color(0xFFE53935),
      'pharmacies': const Color(0xFF43A047),
      'supermarkets': const Color(0xFF1E88E5),
      'shopping': const Color(0xFF8E24AA),
      'gas_stations': const Color(0xFFEF6C00),
      'banks': const Color(0xFF00897B),
    };

    final Map<String, IconData> serviceIcons = {
      'restaurants': Icons.restaurant_rounded,
      'pharmacies': Icons.local_pharmacy_rounded,
      'supermarkets': Icons.shopping_cart_rounded,
      'shopping': Icons.local_mall_rounded,
      'gas_stations': Icons.local_gas_station_rounded,
      'banks': Icons.local_atm_rounded,
    };

    final Map<String, String> searchQueries = {
      'restaurants': 'restaurants in Sharm El Sheikh',
      'pharmacies': 'pharmacies in Sharm El Sheikh',
      'supermarkets': 'supermarkets in Sharm El Sheikh',
      'shopping': 'shopping malls in Sharm El Sheikh',
      'gas_stations': 'gas stations in Sharm El Sheikh',
      'banks': 'banks in Sharm El Sheikh',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceDetailsScreen(
          serviceKey: service,
          serviceColor: serviceColors[service]!,
          serviceIcon: serviceIcons[service]!,
          query: searchQueries[service]!,
        ),
      ),
    );
  }
}