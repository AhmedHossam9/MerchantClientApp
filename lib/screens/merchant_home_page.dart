import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/merchant_app_bar.dart';
import '../widgets/merchant_nav_bar.dart';
import 'package:demo/utils/app_localizations.dart';
import '../widgets/loading_overlay.dart';

class MerchantHomePage extends StatefulWidget {
  final String username;
  final Function(Locale) setLocale;

  const MerchantHomePage({
    Key? key, 
    required this.username,
    required this.setLocale,
  }) : super(key: key);

  @override
  State<MerchantHomePage> createState() => _MerchantHomePageState();
}

class _MerchantHomePageState extends State<MerchantHomePage> {
  int _selectedIndex = 0;
  bool _isLoading = false;

  Future<void> _navigateWithLoading(String route) async {
    if (_isLoading) return; // Prevent multiple clicks

    setState(() => _isLoading = true);

    // Use Timer instead of Future.delayed to keep UI responsive
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    
    return Stack(
      children: [
        Scaffold(
          backgroundColor: brightness == Brightness.light 
              ? Colors.white 
              : colorScheme.background,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  color: brightness == Brightness.light 
                      ? Colors.white 
                      : colorScheme.background,
                  child: MerchantAppBar(
                    titleKey: 'dashboard',
                    showBackButton: false,
                    isHomePage: true,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildRecentOrders(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: MerchantNavBar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
          ),
        ),
        if (_isLoading)
          Container(
            color: (brightness == Brightness.light 
                ? Colors.white 
                : colorScheme.background).withOpacity(0.7),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate('quick_actions'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: brightness == Brightness.light 
                ? colorScheme.primary 
                : Colors.white,
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
            _buildActionCard(
              icon: Icons.add_box,
              title: AppLocalizations.of(context).translate('add_services'),
              onTap: () => _navigateWithLoading('/merchant_add'),
            ),
            _buildActionCard(
              icon: Icons.business_center,
              title: AppLocalizations.of(context).translate('view_services'),
              onTap: () => _navigateWithLoading('/merchant_services'),
            ),
            _buildActionCard(
              icon: Icons.shopping_bag,
              title: AppLocalizations.of(context).translate('view_orders'),
              onTap: () => _navigateWithLoading('/merchant_orders'),  // Assuming you'll add this route
            ),
            _buildActionCard(
              icon: Icons.analytics,
              title: AppLocalizations.of(context).translate('analytics'),
              onTap: () => _navigateWithLoading('/merchant_analytics'),  // Assuming you'll add this route
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon, 
                  size: 32, 
                  color: colorScheme.secondary,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.light 
                        ? colorScheme.primary 
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrders() {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).translate('recent_orders'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: brightness == Brightness.light 
                ? colorScheme.primary 
                : Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        // Add your recent orders list here
      ],
    );
  }
}
