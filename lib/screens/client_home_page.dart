import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/animated_nav_bar.dart';
import '../widgets/client_app_bar.dart';
import '../widgets/loading_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:demo/utils/app_localizations.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis_auth/googleapis_auth.dart' show ServiceAccountCredentials;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:demo/screens/item_details.dart';  // Update with your actual path
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = true;
  late drive.DriveApi _driveApi;
  AuthClient? _authClient;
  bool _isInitialized = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, bool> _favoriteItems = {};
  String? _selectedCategoryId;
  StreamSubscription<User?>? _authStateSubscription;
  List<Map<String, dynamic>> _allItems = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus) {
        _removeOverlay();
      }
    });
    _checkForUnratedOrders(); // Check for unrated orders on init
  }

  Future<void> _checkForUnratedOrders() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .where('merchantRating', isNull: true)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final orderId = querySnapshot.docs.first.id;
      await _showRatingDialog(orderId);
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    
    await _initializeDriveApi();
    if (!mounted) return;

    // Setup auth state listener
    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      if (!mounted) return;
      
      if (user == null) {
        setState(() {
          _favoriteItems.clear();
        });
      } else {
        _loadFavorites(); // Load favorites when user logs in
        _loadItems();
      }
    });

    // Initial load
    await _loadFavorites(); // Load favorites first
    await _loadItems();
    await _loadCategories();
  }

  Future<void> _initializeDriveApi() async {
    try {
      final jsonString = await rootBundle.loadString('assets/credentials/cobalt-ion-442107-b8-f8666a191395.json');
      final credentials = ServiceAccountCredentials.fromJson(json.decode(jsonString));
      _authClient = await clientViaServiceAccount(credentials, [drive.DriveApi.driveFileScope]);
      _driveApi = drive.DriveApi(_authClient!);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing Drive API: $e');
    }
  }

  Future<void> _loadItems() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Start with the base query
      Query itemsQuery = FirebaseFirestore.instance
          .collection('items')
          .orderBy('createdAt', descending: true);

      // Add category filter if a category is selected
      if (_selectedCategoryId != null) {
        itemsQuery = itemsQuery.where('categoryId', isEqualTo: _selectedCategoryId);
      }

      // Get the filtered items
      final QuerySnapshot itemsSnapshot = await itemsQuery.get();

      final List<Map<String, dynamic>> items = await Future.wait(
        itemsSnapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          
          // Fetch merchant data and ratings
          final merchantDoc = await FirebaseFirestore.instance
              .collection('merchants')
              .doc(data['merchantId'])
              .get();
          
          final merchantRatingsSnapshot = await FirebaseFirestore.instance
              .collection('merchants')
              .doc(data['merchantId'])
              .collection('ratings')
              .get();

          // Calculate merchant's average rating
          double merchantRating = 0;
          if (merchantRatingsSnapshot.docs.isNotEmpty) {
            final totalRating = merchantRatingsSnapshot.docs
                .map((doc) => doc.data()['rating'] as num)
                .reduce((a, b) => a + b);
            merchantRating = totalRating / merchantRatingsSnapshot.docs.length;
          }
          
          // Fetch item ratings
          final itemRatingsSnapshot = await FirebaseFirestore.instance
              .collection('items')
              .doc(doc.id)
              .collection('ratings')
              .get();
          
          // Calculate item's average rating
          double itemRating = 0;
          if (itemRatingsSnapshot.docs.isNotEmpty) {
            final totalRating = itemRatingsSnapshot.docs
                .map((doc) => doc.data()['rating'] as num)
                .reduce((a, b) => a + b);
            itemRating = totalRating / itemRatingsSnapshot.docs.length;
          }

          // Calculate item score
          final DateTime createdAt = (data['createdAt'] as Timestamp).toDate();
          final int daysOld = DateTime.now().difference(createdAt).inDays;
          final double newnessScore = daysOld <= 30 ? (30 - daysOld) / 30 * 5 : 0;
          final double score = (merchantRating * 0.5) + (newnessScore * 0.5);

          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'name_en': data['name_en'] ?? '',
            'name_ar': data['name_ar'] ?? '',
            'price': data['price']?.toString() ?? '0',
            'categoryId': data['categoryId'] ?? '',
            'images': data['images'] ?? [],
            'description': data['description'] ?? '',
            'createdAt': data['createdAt'],
            'merchantId': data['merchantId'],
            'merchantRating': merchantRating,
            'itemRating': itemRating,
            'ratingCount': itemRatingsSnapshot.docs.length,
            'score': score,
          };
        }),
      );

      if (!mounted) return;

      // Sort items by score and take top 6
      items.sort((a, b) => b['score'].compareTo(a['score']));
      final topItems = items.take(6).toList();

      setState(() {
        _allItems = items;
        _filteredItems = topItems;
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading items: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;

    try {
      final categoriesSnapshot = await FirebaseFirestore.instance
          .collection('categories')
          .orderBy('order')
          .get();

      if (!mounted) return;

      final categories = categoriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name_en': data['name_en'] ?? '',
          'name_ar': data['name_ar'] ?? '',
        };
      }).toList();

      setState(() {
        _categories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _searchController.dispose();
    _authClient?.close();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ClientAppBar(titleKey: 'home'),
            Expanded(
              child: _isLoading
                  ? const LoadingOverlay()
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchBar(),
                          _buildCategories(),
                          _buildNewlyAddedSection(),
                        ],
                      ),
                    ),
            ),
            AnimatedNavBar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onItemSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).translate('search'),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              if (_debounce?.isActive ?? false) _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                _performSearch(value);
              });
            },
          ),
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxHeight: 300,
                maxWidth: MediaQuery.of(context).size.width - 32,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: Colors.grey[200],
                ),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _searchResults = [];
                          _searchController.clear();
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ItemDetailsScreen(),
                            settings: RouteSettings(
                              arguments: {
                                'itemId': item['id'],
                                'item': item,
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item['images'] != null && (item['images'] as List).isNotEmpty
                                    ? _buildItemImage(context, item['images'][0])
                                    : Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.grey[400],
                                        size: 24,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['price']} ${AppLocalizations.of(context).translate('currency')}',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('items')
          .get();

      final results = snapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'name_en': data['name_en'] ?? '',
              'name_ar': data['name_ar'] ?? '',
              'price': data['price']?.toString() ?? '0',
              'images': data['images'] ?? [],
              'description': data['description'] ?? '',
              'categoryId': data['categoryId'] ?? '',
            };
          })
          .where((item) {
            final searchQuery = query.toLowerCase();
            final name = item['name']?.toString().toLowerCase() ?? '';
            final nameEn = item['name_en']?.toString().toLowerCase() ?? '';
            final nameAr = item['name_ar']?.toString().toLowerCase() ?? '';
            
            return name.contains(searchQuery) ||
                   nameEn.contains(searchQuery) ||
                   nameAr.contains(searchQuery);
          })
          .take(10)
          .toList();

      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
      });
    }
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFe2211c),
            const Color(0xFF062f6e),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            top: 30,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Offer placeholder',
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(height: 8),
                Text(
                  'X% OFF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            AppLocalizations.of(context).translate('categories'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length + 1,
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final category = isAll ? null : _categories[index - 1];
              final isSelected = isAll 
                  ? _selectedCategoryId == null 
                  : _selectedCategoryId == category?['id'];

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => _onCategorySelected(isAll ? null : category?['id']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF062f6e) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isAll 
                          ? AppLocalizations.of(context).translate('all')
                          : isArabic 
                              ? (category?['name_ar'] ?? '')
                              : (category?['name_en'] ?? ''),
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _onCategorySelected(String? categoryId) async {
    if (_selectedCategoryId == categoryId) return; // Don't reload if same category

    setState(() {
      _selectedCategoryId = categoryId;
      _isLoading = true;
    });
    
    await _loadItems();
  }

  Widget _buildPopularSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'New Additions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'View All',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _filteredItems.length,
            itemBuilder: (context, index) {
              return _buildProductCard(_filteredItems[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    final List<dynamic> images = item['images'] ?? [];
    final double itemRating = item['itemRating'] ?? 0.0;
    final int ratingCount = item['ratingCount'] ?? 0;
    
    return GestureDetector(
      onTap: () => _navigateToItemDetails(item),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      child: images.isNotEmpty
                          ? _buildItemImage(context, images.first)
                          : _buildImagePlaceholder(),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            _favoriteItems[item['id']] == true 
                                ? Icons.favorite 
                                : Icons.favorite_border,
                            size: 18,
                            color: _favoriteItems[item['id']] == true 
                                ? Colors.red 
                                : Colors.grey,
                          ),
                          onPressed: () => _toggleFavorite(item['id']),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Item Rating
                  if (itemRating > 0) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          itemRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($ratingCount)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${item['price']} ${AppLocalizations.of(context).translate('currency')}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF062f6e),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${item['price']} ${AppLocalizations.of(context).translate('currency')}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF062f6e),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewLabel() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFe2211c),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          AppLocalizations.of(context).translate('new'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  bool _isNewItem(dynamic createdAt) {
    if (createdAt == null) return false;
    
    final itemDate = (createdAt as Timestamp).toDate();
    final now = DateTime.now();
    final difference = now.difference(itemDate);
    
    // Consider items added in the last 7 days as new
    return difference.inDays <= 7;
  }

  Future<void> _toggleFavorite(String itemId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('login_required')),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final favoriteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(itemId);

      final doc = await favoriteRef.get();
      
      if (doc.exists) {
        await favoriteRef.delete();
        if (mounted) {
          setState(() {
            _favoriteItems.remove(itemId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).translate('removed_from_favorites')),
            ),
          );
        }
      } else {
        await favoriteRef.set({
          'itemId': itemId,
          'addedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _favoriteItems[itemId] = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).translate('added_to_favorites')),
            ),
          );
        }
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_updating_favorites')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildItemImage(BuildContext context, String imageUrl) {
    if (!_isInitialized || _authClient == null) {
      return _buildImagePlaceholder();
    }

    String fileId;
    if (imageUrl.contains('id=')) {
      fileId = imageUrl.split('id=').last;
    } else {
      fileId = imageUrl.split('/d/').last.split('/').first;
    }

    final mediaUrl = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
    final token = _authClient!.credentials.accessToken.data;

    return Image.network(
      mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'image/*',
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image: $error');
        return _buildImagePlaceholder();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
          ),
        );
      },
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 32,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).translate('no_image'),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewlyAddedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context).translate('featured_items'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/browse');
                },
                child: Text(
                  AppLocalizations.of(context).translate('view_all'),
                  style: const TextStyle(
                    color: Color(0xFF062f6e),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        _filteredItems.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).translate('no_items_available'),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    return _buildProductCard(item);
                  },
                ),
              ),
      ],
    );
  }

  void _onItemSelected(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
      Navigator.pushReplacementNamed(context, '/services_home_page');// Home
        break;
      case 1: // Browse
        Navigator.pushReplacementNamed(context, '/browse');
        break;
      case 2: // Favorites
        Navigator.pushReplacementNamed(context, '/favorites');
        break;
      case 3: // Chat
        Navigator.pushReplacementNamed(context, '/chat');
        break;
      case 4: // Cart
        Navigator.pushReplacementNamed(context, '/cart');
        break;
      case 5: // Profile
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  void _navigateToItemDetails(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ItemDetailsScreen(),
        settings: RouteSettings(
          arguments: {
            'itemId': item['id'],
            'item': item,
          },
        ),
      ),
    );
  }

  Future<void> _showRatingDialog(String orderId) async {
    double merchantRating = 3.0;
    double itemRating = 3.0;
    final TextEditingController merchantCommentController = TextEditingController();
    final TextEditingController itemCommentController = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false, // User must complete the rating
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context).translate('rate_order'),
            style: const TextStyle(
              color: Color(0xFF062f6e),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context).translate('rate_merchant'),
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                RatingBar.builder(
                  initialRating: merchantRating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (rating) {
                    merchantRating = rating;
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: merchantCommentController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate('merchant_comment_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).translate('rate_item'),
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                RatingBar.builder(
                  initialRating: itemRating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (rating) {
                    itemRating = rating;
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: itemCommentController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate('item_comment_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                AppLocalizations.of(context).translate('submit'),
                style: const TextStyle(
                  color: Color(0xFFe2211c),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                if (merchantCommentController.text.trim().isEmpty || itemCommentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).translate('comment_required')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Save ratings and comments to Firestore
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(orderId)
                    .update({
                  'merchantRating': merchantRating,
                  'merchantComment': merchantCommentController.text.trim(),
                  'itemRating': itemRating,
                  'itemComment': itemCommentController.text.trim(),
                });

                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    ).then((_) {
      merchantCommentController.dispose();
      itemCommentController.dispose();
    });
  }

  Future<void> _loadFavorites() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      if (!mounted) return;

      setState(() {
        _favoriteItems = {
          for (var doc in favoritesSnapshot.docs)
            doc.id: true
        };
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }
}