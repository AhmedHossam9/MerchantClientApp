import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import '../theme/theme_provider.dart';

class EntertainmentScreen extends StatelessWidget {
  const EntertainmentScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(
              titleKey: 'entertainment',
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildOptionCard(
                        context: context,
                        title: AppLocalizations.of(context).translate('diving_activities'),
                        description: AppLocalizations.of(context).translate('diving_activities_desc'),
                        icon: Icons.water_rounded,
                        onTap: () => Navigator.pushNamed(context, '/diving'),
                      ),
                      _buildOptionCard(
                        context: context,
                        title: AppLocalizations.of(context).translate('snorkeling_activities'),
                        description: AppLocalizations.of(context).translate('snorkeling_activities_desc'),
                        icon: Icons.scuba_diving,
                        onTap: () => Navigator.pushNamed(context, '/snorkeling'),
                      ),
                      _buildOptionCard(
                        context: context,
                        title: AppLocalizations.of(context).translate('safari_activities'),
                        description: AppLocalizations.of(context).translate('safari_activities_desc'),
                        icon: Icons.terrain_rounded,
                        onTap: () => Navigator.pushNamed(context, '/safari'),
                      ),
                      _buildOptionCard(
                        context: context,
                        title: AppLocalizations.of(context).translate('nightlife_activities'),
                        description: AppLocalizations.of(context).translate('nightlife_activities_desc'),
                        icon: Icons.music_note_rounded,
                        onTap: () => Navigator.pushNamed(context, '/nightlife'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
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
            Icon(
              icon,
              size: 80,
              color: const Color(0xFFe2211c),
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