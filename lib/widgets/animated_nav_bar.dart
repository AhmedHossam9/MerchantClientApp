import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class AnimatedNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AnimatedNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(context, 0, Icons.home_outlined, Icons.home, 'home'),
              _buildNavItem(context, 1, Icons.grid_view_outlined, Icons.grid_view, 'browse'),
              _buildNavItem(context, 2, Icons.favorite_outline, Icons.favorite, 'favorites'),
              _buildNavItem(context, 3, Icons.receipt_long_outlined, Icons.receipt_long, 'orders'),
              _buildNavItem(context, 4, Icons.shopping_cart_outlined, Icons.shopping_cart, 'cart'),
              _buildNavItem(context, 5, Icons.person_outline, Icons.person, 'profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData activeIcon, String labelKey) {
    final isSelected = selectedIndex == index;
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return GestureDetector(
      onTap: () {
        onItemSelected(index);
        _handleNavigation(context, index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? const Color(0xFFe2211c).withOpacity(isDarkMode ? 0.2 : 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                isSelected ? activeIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected 
                    ? const Color(0xFFe2211c)
                    : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isSelected 
                  ? const Color(0xFFe2211c)
                  : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            child: Text(
              AppLocalizations.of(context).translate(labelKey),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    String route;
    switch (index) {
      case 0:
        route = '/services_home_page';
        break;
      case 1:
        route = '/browse';
        break;
      case 2:
        route = '/favorites';
        break;
      case 3:
        route = '/orders';
        break;
      case 4:
        route = '/cart';
        break;
      case 5:
        route = '/profile';
        break;
      default:
        route = '/home';
    }
    Navigator.pushReplacementNamed(context, route);
  }
}