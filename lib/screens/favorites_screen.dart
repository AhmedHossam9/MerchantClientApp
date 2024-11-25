import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_localizations.dart';
import '../widgets/client_app_bar.dart';
import '../widgets/loading_overlay.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../widgets/animated_nav_bar.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _favoriteItems = [];
  late drive.DriveApi _driveApi;
  AuthClient? _authClient;
  bool _isInitialized = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeDriveApi().then((_) {
      if (mounted) {
        _loadFavorites();
      }
    });
  }

  @override
  void dispose() {
    _authClient?.close();
    super.dispose();
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

  Future<void> _loadFavorites() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _favoriteItems = [];
        });
        return;
      }

      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      final List<Map<String, dynamic>> items = [];
      
      for (var doc in favoritesSnapshot.docs) {
        final itemId = doc.data()['itemId'] as String;
        final itemDoc = await FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .get();
        
        if (itemDoc.exists) {
          items.add({
            'id': itemDoc.id,
            ...itemDoc.data()!,
          });
        }
      }

      if (mounted) {
        setState(() {
          _favoriteItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_loading_favorites')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeFavorite(String itemId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(itemId)
          .delete();

      setState(() {
        _favoriteItems.removeWhere((item) => item['id'] == itemId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('removed_from_favorites')),
          ),
        );
      }
    } catch (e) {
      print('Error removing favorite: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ClientAppBar(titleKey: 'favorites'),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _favoriteItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.favorite_outline,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                AppLocalizations.of(context).translate('no_favorites'),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF062f6e),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  AppLocalizations.of(context).translate('no_favorites_description'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _favoriteItems.length,
                          itemBuilder: (context, index) {
                            final item = _favoriteItems[index];
                            return _buildFavoriteItem(item);
                          },
                        ),
            ),
            AnimatedNavBar(
              selectedIndex: 2, // Favorites tab index
              onItemSelected: (index) {
                if (index == 2) return; // Already on favorites
                String route;
                switch (index) {
                  case 0:
                    route = '/services_home_page'; // Changed from '/home'
                    break;
                  case 1:
                    route = '/browse';
                    break;
                  case 3:
                    route = '/chat';
                    break;
                  case 4:
                    route = '/cart';
                    break;
                  case 5:
                    route = '/profile';
                    break;
                  default:
                    return; // Don't navigate for unknown indices
                }
                Navigator.pushReplacementNamed(context, route);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteItem(Map<String, dynamic> item) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final images = List<String>.from(item['images'] ?? []);

    return Dismissible(
      key: Key(item['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) => _removeFavorite(item['id']),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(
          context,
          '/item_details',
          arguments: {
            'itemId': item['id'],
            'item': item,
          },
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: images.isNotEmpty
                          ? _buildItemImage(context, images.first)
                          : _buildImagePlaceholder(),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isArabic == true
                                ? (item['category_ar'] ?? '')
                                : (item['category_en'] ?? ''),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${item['quantity']} ${AppLocalizations.of(context).translate('items_available')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFe2211c),
                                ),
                              ),
                              Text(
                                '${item['price']?.toString() ?? '0'} ${AppLocalizations.of(context).translate('currency')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF062f6e),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showRemoveConfirmation(item['id']),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite,
                        color: const Color(0xFFe2211c),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRemoveConfirmation(String itemId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('remove_from_favorites')),
          content: Text(AppLocalizations.of(context).translate('remove_favorite_confirmation')),
          actions: <Widget>[
            TextButton(
              child: Text(
                AppLocalizations.of(context).translate('cancel'),
                style: const TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                AppLocalizations.of(context).translate('remove'),
                style: const TextStyle(color: Color(0xFFe2211c)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _removeFavorite(itemId);
              },
            ),
          ],
        );
      },
    );
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
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}