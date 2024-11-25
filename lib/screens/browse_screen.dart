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
import 'package:demo/screens/item_details.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  int _selectedIndex = 1;
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
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    
    await _initializeDriveApi();
    if (!mounted) return;

    _authStateSubscription = _auth.authStateChanges().listen((User? user) {
      if (!mounted) return;
      
      if (user == null) {
        setState(() {
          _favoriteItems.clear();
        });
      } else {
        _loadItems();
      }
    });

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

      Query query = FirebaseFirestore.instance.collection('items');
      
      if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
        query = query.where('categoryId', isEqualTo: _selectedCategoryId);
      }
      
      final QuerySnapshot itemsSnapshot = await query.get();

      if (!mounted) return;

      final List<Map<String, dynamic>> items = await Future.wait(
        itemsSnapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          
          // Fetch ratings for this item
          final ratingsSnapshot = await FirebaseFirestore.instance
              .collection('items')
              .doc(doc.id)
              .collection('ratings')
              .get();
          
          // Calculate average rating
          double averageRating = 0;
          if (ratingsSnapshot.docs.isNotEmpty) {
            final totalRating = ratingsSnapshot.docs
                .map((doc) => doc.data()['rating'] as num)
                .reduce((a, b) => a + b);
            averageRating = totalRating / ratingsSnapshot.docs.length;
          }

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
            'rating': averageRating,
            'ratingCount': ratingsSnapshot.docs.length,
          };
        }),
      );

      if (!mounted) return;

      setState(() {
        _allItems = items;
        _filteredItems = items;
        _isLoading = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('error_loading_items')),
          backgroundColor: Colors.red,
        ),
      );
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
      // Handle error silently or show a user-friendly message if needed
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _searchController.dispose();
    _authClient?.close();
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
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
    );
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredItems = _allItems;
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
          .toList();

      setState(() {
        _filteredItems = results;
      });
    } catch (e) {
      print('Error performing search: $e');
      setState(() {
        _filteredItems = [];
      });
    }
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

  void _onCategorySelected(String? categoryId) {
    print('Category selected: $categoryId');
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _loadItems();
  }

  Widget _buildProductCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _navigateToItemDetails(item),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  children: [
                    _buildItemImage(item),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _buildActionButton(item),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if ((item['rating'] as num) > 0) ...[
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item['rating'].toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${item['ratingCount']})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                      ],
                      Text(
                        '${item['price']} ${AppLocalizations.of(context).translate('currency')}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
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

  Widget _buildActionButton(Map<String, dynamic> item) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white,
      child: IconButton(
        icon: Icon(
          _favoriteItems[item['id']] == true
              ? Icons.favorite
              : Icons.favorite_border,
          size: 16,
          color: _favoriteItems[item['id']] == true ? Colors.red : Colors.grey,
        ),
        onPressed: () => _toggleFavorite(item['id']),
      ),
    );
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

  Widget _buildItemImage(Map<String, dynamic> item) {
    final List<dynamic> images = item['images'] ?? [];
    if (images.isEmpty) {
      return _buildImagePlaceholder();
    }

    if (!_isInitialized || _authClient == null) {
      return _buildImagePlaceholder();
    }

    String fileId;
    if (images[0].contains('id=')) {
      fileId = images[0].split('id=').last;
    } else {
      fileId = images[0].split('/d/').last.split('/').first;
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

  void _onItemSelected(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/services_home_page');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ClientAppBar(titleKey: 'browse'),
            Expanded(
              child: _isLoading
                  ? const LoadingOverlay()
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchBar(),
                          _buildCategories(),
                          _buildItemsGrid(),
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

  Widget _buildItemsGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _filteredItems.isEmpty
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
          : GridView.builder(
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
    );
  }
}