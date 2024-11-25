import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import '../theme/theme_provider.dart';

class DivingActivitiesScreen extends StatefulWidget {
  final DivingActivity? activity;

  const DivingActivitiesScreen({
    Key? key,
    this.activity,
  }) : super(key: key);

  @override
  State<DivingActivitiesScreen> createState() => _DivingActivitiesScreenState();
}

class _DivingActivitiesScreenState extends State<DivingActivitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'rating'; // Default sort option
  List<DivingActivity> _activities = []; // Will be populated from database
  List<DivingActivity> _filteredActivities = [];

  @override
  void initState() {
    super.initState();
    // TODO: Fetch diving activities from database
    _loadActivities();
    _searchController.addListener(_filterActivities);
  }

  Future<void> _loadActivities() async {
    // TODO: Implement database fetch
    // Temporary mock data
    _activities = [
      DivingActivity(
        id: '1',
        name: 'Ras Mohammed Diving',
        description: 'Experience the beautiful coral reefs',
        price: 75.0,
        rating: 4.5,
        available: true,
        imageUrl: 'assets/diving/ras_mohammed.jpg',
      ),
      // Add more mock data as needed
    ];
    _filterActivities();
  }

  void _filterActivities() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredActivities = _activities.where((activity) {
        return activity.name.toLowerCase().contains(query) ||
               activity.description.toLowerCase().contains(query);
      }).toList();

      // Apply sorting
      _filteredActivities.sort((a, b) {
        switch (_sortBy) {
          case 'rating':
            return b.rating.compareTo(a.rating);
          case 'price_low':
            return a.price.compareTo(b.price);
          case 'price_high':
            return b.price.compareTo(a.price);
          default:
            return b.rating.compareTo(a.rating);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(
              titleKey: 'diving_activities',
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).translate('search'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sort Options
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('sort_by'),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _sortBy,
                        items: [
                          DropdownMenuItem(
                            value: 'rating',
                            child: Text(AppLocalizations.of(context).translate('rating')),
                          ),
                          DropdownMenuItem(
                            value: 'price_low',
                            child: Text(AppLocalizations.of(context).translate('price_low_high')),
                          ),
                          DropdownMenuItem(
                            value: 'price_high',
                            child: Text(AppLocalizations.of(context).translate('price_high_low')),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _sortBy = value!;
                            _filterActivities();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Activities List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredActivities.length,
                itemBuilder: (context, index) {
                  final activity = _filteredActivities[index];
                  return _buildActivityCard(activity);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(DivingActivity activity) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: () {
          // TODO: Navigate to activity details
          Navigator.pushNamed(
            context,
            '/diving-detail',
            arguments: activity,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.asset(
                activity.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        activity.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                        ),
                      ),
                      Text(
                        '\$${activity.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFe2211c),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.description,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activity.rating.toString(),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: activity.available ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          activity.available
                              ? AppLocalizations.of(context).translate('available')
                              : AppLocalizations.of(context).translate('unavailable'),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class DivingActivity {
  final String id;
  final String name;
  final String description;
  final double price;
  final double rating;
  final bool available;
  final String imageUrl;

  DivingActivity({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.rating,
    required this.available,
    required this.imageUrl,
  });

  // TODO: Add fromJson constructor for database integration
}