import 'package:flutter/material.dart';
import '../utils/app_localizations.dart';
import '../widgets/loading_overlay.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class ItemDetailsScreen extends StatefulWidget {
  const ItemDetailsScreen({Key? key}) : super(key: key);

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _itemData;
  late drive.DriveApi _driveApi;
  AuthClient? _authClient;
  bool _isInitialized = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isFavorite = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeDriveApi().then((_) {
      if (mounted) {
        _loadItemData();
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

  Future<void> _loadItemData() async {
    try {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final itemId = args?['itemId'];
      
      if (itemId == null) {
        Navigator.pop(context);
        return;
      }

      // Load the full item data from Firestore
      final itemDoc = await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .get();

      if (!itemDoc.exists) {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Fetch merchant and item ratings
      final merchantId = itemDoc.data()?['merchantId'];
      double merchantRatingAvg = 0.0;
      double itemRatingAvg = 0.0;
      List<Map<String, dynamic>> merchantComments = [];
      List<Map<String, dynamic>> itemComments = [];

      if (merchantId != null) {
        final merchantRatings = await FirebaseFirestore.instance
            .collection('merchants')
            .doc(merchantId)
            .collection('ratings')
            .get();

        if (merchantRatings.docs.isNotEmpty) {
          double totalRating = 0.0;
          for (var doc in merchantRatings.docs) {
            final rating = doc.data()['rating'];
            if (rating != null) {
              totalRating += (rating is int ? rating.toDouble() : rating as double);
            }
          }
          merchantRatingAvg = totalRating / merchantRatings.docs.length;
          
          merchantComments = merchantRatings.docs
              .map((doc) => {
                    'rating': doc.data()['rating'] is int 
                        ? (doc.data()['rating'] as int).toDouble() 
                        : doc.data()['rating'] as double,
                    'comment': doc.data()['comment'] as String,
                    'createdAt': doc.data()['createdAt'] as Timestamp,
                  })
              .toList();
        }
      }

      final itemRatings = await FirebaseFirestore.instance
          .collection('items')
          .doc(itemId)
          .collection('ratings')
          .get();

      if (itemRatings.docs.isNotEmpty) {
        double totalRating = 0.0;
        for (var doc in itemRatings.docs) {
          final rating = doc.data()['rating'];
          if (rating != null) {
            totalRating += (rating is int ? rating.toDouble() : rating as double);
          }
        }
        itemRatingAvg = totalRating / itemRatings.docs.length;
        
        itemComments = itemRatings.docs
            .map((doc) => {
                  'rating': doc.data()['rating'] is int 
                      ? (doc.data()['rating'] as int).toDouble() 
                      : doc.data()['rating'] as double,
                  'comment': doc.data()['comment'] as String,
                  'createdAt': doc.data()['createdAt'] as Timestamp,
                })
            .toList();
      }

      print('Merchant Rating Avg: $merchantRatingAvg'); // Debug print
      print('Item Rating Avg: $itemRatingAvg'); // Debug print
      print('Merchant Comments: ${merchantComments.length}'); // Debug print
      print('Item Comments: ${itemComments.length}'); // Debug print

      if (mounted) {
        setState(() {
          _itemData = {
            'id': itemDoc.id,
            ...itemDoc.data() ?? {},
            'merchantRatingAvg': merchantRatingAvg,
            'itemRatingAvg': itemRatingAvg,
            'merchantComments': merchantComments,
            'itemComments': itemComments,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading item data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_loading_item')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
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

    try {
      final itemId = _itemData?['id'];
      final favoriteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(itemId);

      setState(() => _isFavorite = !_isFavorite);

      if (_isFavorite) {
        await favoriteRef.set({
          'itemId': itemId,
          'addedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await favoriteRef.delete();
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      // Revert state on error
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('error_updating_favorites')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addToCart() async {
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

    try {
      final itemId = _itemData?['id'];
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(itemId);

      await cartRef.set({
        'itemId': itemId,
        'quantity': 1, // Default quantity
        'addedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('added_to_cart')),
            action: SnackBarAction(
              label: AppLocalizations.of(context).translate('view_cart'),
              onPressed: () => Navigator.pushNamed(context, '/cart'),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error adding to cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_adding_to_cart')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: const Color(0xFFe2211c),
                  ),
                  onPressed: _toggleFavorite,
                ),
              ),
            ],
          ),
          body: _isLoading
              ? const SizedBox()
              : Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image Carousel
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: PageView.builder(
                              itemCount: (_itemData?['images'] as List?)?.length ?? 0,
                              onPageChanged: (index) {
                                setState(() => _currentImageIndex = index);
                              },
                              itemBuilder: (context, index) {
                                final images = _itemData?['images'] as List?;
                                return images != null && images.isNotEmpty
                                    ? _buildItemImage(context, images[index])
                                    : _buildImagePlaceholder();
                              },
                            ),
                          ),
                          // Content Container
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image Indicators
                                if ((_itemData?['images'] as List?)?.isNotEmpty ?? false)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        (_itemData?['images'] as List?)?.length ?? 0,
                                        (index) => Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _currentImageIndex == index
                                                ? const Color(0xFF062f6e)
                                                : Colors.grey[300],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                // Item Details
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _itemData?['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        isArabic == true
                                            ? (_itemData?['category_ar'] ?? '')
                                            : (_itemData?['category_en'] ?? ''),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildInfoSection(
                                        title: AppLocalizations.of(context).translate('manufacturer'),
                                        content: _itemData?['manufacturer'] ?? '',
                                        icon: Icons.business_outlined,
                                      ),
                                      const SizedBox(height: 24),
                                      _buildInfoSection(
                                        title: AppLocalizations.of(context).translate('description'),
                                        content: _itemData?['description'] ?? '',
                                        icon: Icons.description_outlined,
                                      ),
                                      const SizedBox(height: 24),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFe2211c).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.inventory_2_outlined,
                                              color: Color(0xFFe2211c),
                                              size: 28,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '${_itemData?['quantity'] ?? 0} ${AppLocalizations.of(context).translate('items_available')}',
                                              style: const TextStyle(
                                                color: Color(0xFFe2211c),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildRatingsSection(),
                                      const SizedBox(height: 100), // Space for bottom buttons
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom Buttons
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _contactMerchant,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF062f6e),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  side: const BorderSide(
                                    color: Color(0xFF062f6e),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.message_outlined),
                                label: Text(
                                  AppLocalizations.of(context).translate('contact'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _addToCart,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF062f6e),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.shopping_cart_outlined),
                                label: Text(
                                  AppLocalizations.of(context).translate('add_to_cart'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        if (_isLoading)
          const LoadingOverlay(),
      ],
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

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.45,
      child: Image.network(
        mediaUrl,
        fit: BoxFit.contain,
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
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF062f6e),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062f6e),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRatingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        // Ratings Overview
        Row(
          children: [
            Expanded(
              child: _buildRatingCard(
                title: AppLocalizations.of(context).translate('merchant_rating'),
                rating: _itemData?['merchantRatingAvg'] ?? 0.0,
                commentsCount: (_itemData?['merchantComments'] as List?)?.length ?? 0,
                onViewComments: () => _showCommentsDialog(true),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildRatingCard(
                title: AppLocalizations.of(context).translate('item_rating'),
                rating: _itemData?['itemRatingAvg'] ?? 0.0,
                commentsCount: (_itemData?['itemComments'] as List?)?.length ?? 0,
                onViewComments: () => _showCommentsDialog(false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingCard({
    required String title,
    required double rating,
    required int commentsCount,
    required VoidCallback onViewComments,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF062f6e),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Colors.amber,
                size: 24,
              ),
              const SizedBox(width: 4),
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : '0.0',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onViewComments,
            child: Text(
              '${AppLocalizations.of(context).translate('view_comments')} ($commentsCount)',
              style: const TextStyle(
                color: Color(0xFF062f6e),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentsDialog(bool isMerchantComments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        List<Map<String, dynamic>> comments = [];
        
        if (isMerchantComments) {
          comments = (_itemData?['merchantComments'] as List? ?? [])
              .map((comment) => comment as Map<String, dynamic>)
              .toList();
        } else {
          comments = (_itemData?['itemComments'] as List? ?? [])
              .map((comment) => comment as Map<String, dynamic>)
              .toList();
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMerchantComments
                        ? AppLocalizations.of(context).translate('merchant_comments')
                        : AppLocalizations.of(context).translate('item_comments'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062f6e),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: comments.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context).translate('no_comments_yet'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.separated(
                        itemCount: comments.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ...List.generate(
                                      5,
                                      (i) => Icon(
                                        i < (comment['rating'] as double).floor()
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment['comment'] as String,
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _contactMerchant() {
    // TODO: Implement contact functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).translate('contact_coming_soon')),
      ),
    );
  }

  void _placeOrder() {
    // TODO: Implement order functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).translate('order_coming_soon')),
      ),
    );
  }
}