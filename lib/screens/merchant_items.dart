import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/merchant_app_bar.dart';
import '../utils/app_localizations.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../widgets/loading_overlay.dart';

class MerchantItemsScreen extends StatefulWidget {
  const MerchantItemsScreen({Key? key}) : super(key: key);

  @override
  State<MerchantItemsScreen> createState() => _MerchantItemsScreenState();
}

class _MerchantItemsScreenState extends State<MerchantItemsScreen> {
  late drive.DriveApi _driveApi;
  AuthClient? _authClient;
  bool _isInitialized = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeDriveApi();
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

  Future<void> _navigateWithLoading(String route, [Map<String, dynamic>? arguments]) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      
      try {
        if (arguments != null) {
          await Navigator.pushNamed(context, route, arguments: arguments);
        } else {
          await Navigator.pushNamed(context, route);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Empty state illustration
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 100,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),
            
            // Empty state title
            Text(
              AppLocalizations.of(context).translate('no_items_yet'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF062f6e),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Empty state description
            Text(
              AppLocalizations.of(context).translate('no_items_description'),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Add first item button
            ElevatedButton.icon(
              onPressed: () => _navigateWithLoading('/merchant_add'),
              icon: const Icon(Icons.add),
              label: Text(
                AppLocalizations.of(context).translate('add_first_item'),
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF062f6e),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context, String itemId, String itemName) async {
    // Store the context for later use
    final scaffoldContext = context;
    
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('confirm_delete')),
          content: Text(
            AppLocalizations.of(context).translate('delete_item_confirmation')
              .replaceAll('{itemName}', itemName),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                AppLocalizations.of(context).translate('cancel'),
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Close the dialog first
                Navigator.of(dialogContext).pop();
                
                // Show loading overlay
                if (mounted) {
                  setState(() => _isLoading = true);
                }
                
                try {
                  // Get the item data first to get the image URLs
                  final itemDoc = await FirebaseFirestore.instance
                      .collection('items')
                      .doc(itemId)
                      .get();
                  
                  final itemData = itemDoc.data();
                  final List<String> imageUrls = itemData?['images']?.cast<String>() ?? [];

                  // Delete images from Google Drive
                  for (String url in imageUrls) {
                    try {
                      String fileId;
                      if (url.contains('id=')) {
                        fileId = url.split('id=').last;
                      } else {
                        fileId = url.split('/d/').last.split('/').first;
                      }
                      await _driveApi.files.delete(fileId);
                    } catch (e) {
                      print('Error deleting file from Drive: $e');
                    }
                  }

                  // Delete the item from Firestore
                  await FirebaseFirestore.instance
                      .collection('items')
                      .doc(itemId)
                      .delete();
                  
                  if (mounted) {
                    setState(() => _isLoading = false);
                    
                    // Use the stored context to show SnackBar
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).translate('item_deleted')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('Error deleting item: $e');
                  if (mounted) {
                    setState(() => _isLoading = false);
                    
                    // Use the stored context to show error SnackBar
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).translate('error_deleting_item')
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(
                AppLocalizations.of(context).translate('delete'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('no_image'),
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemImage(BuildContext context, String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildImagePlaceholder(context);
    }

    if (!_isInitialized || _authClient == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Extract file ID from Google Drive URL
    String fileId;
    if (imageUrl.contains('id=')) {
      fileId = imageUrl.split('id=').last;
    } else {
      fileId = imageUrl.split('/d/').last.split('/').first;
    }

    final mediaUrl = 'https://www.googleapis.com/drive/v3/files/$fileId?alt=media';
    final token = _authClient?.credentials.accessToken.data;

    // Directly use the media URL with authentication
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(12),
      ),
      child: Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'image/*',
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image: $error');
          print('Error URL: $mediaUrl');
          print('Stack trace: $stackTrace');
          return _buildImagePlaceholder(context);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / 
                    loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, String itemId) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final categoryName = isArabic 
        ? (item['category_ar'] as String?) 
        : (item['category_en'] as String?);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              color: Colors.grey[100],
            ),
            child: (item['images'] != null && 
                   (item['images'] as List).isNotEmpty)
              ? _buildImageGallery(context, (item['images'] as List).cast<String>())
              : _buildImagePlaceholder(context),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String? ?? 'Unnamed Item',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF062f6e),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.category_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      categoryName ?? AppLocalizations.of(context).translate('uncategorized'),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (item['description'] != null && item['description'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['description'] as String,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, 
                            size: 16, 
                            color: Colors.grey[600]
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${AppLocalizations.of(context).translate('quantity')}: ${item['quantity'] as int? ?? 0}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.attach_money, 
                            size: 16, 
                            color: Colors.grey[600]
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item['price']?.toString() ?? '0'} ${AppLocalizations.of(context).translate('currency')}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _navigateWithLoading(
                          '/merchant_edit',
                          {'itemId': itemId},
                        ),
                        icon: const Icon(Icons.edit),
                        label: Text(AppLocalizations.of(context).translate('edit')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF062f6e),
                          side: const BorderSide(color: Color(0xFF062f6e)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteConfirmation(
                          context,
                          itemId,
                          item['name'] as String? ?? 'Unnamed Item',
                        ),
                        icon: const Icon(Icons.delete),
                        label: Text(AppLocalizations.of(context).translate('delete')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _buildImageGallery(BuildContext context, List<String> images) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(12),
      ),
      child: Row(
        children: [
          // Main (larger) image
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 200,
              child: _buildItemImage(context, images[0]),
            ),
          ),
          // Only show second column if there are additional images
          if (images.length > 1)
            Expanded(
              child: Column(
                children: [
                  // Second image
                  SizedBox(
                    height: 100,
                    child: _buildItemImage(context, images[1]),
                  ),
                  // Third image or more indicator
                  SizedBox(
                    height: 100,
                    child: images.length > 2
                      ? Stack(
                          children: [
                            _buildItemImage(context, images[2]),
                            if (images.length > 3)
                              Container(
                                color: Colors.black.withOpacity(0.5),
                                child: Center(
                                  child: Text(
                                    '+${images.length - 3}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Container(
                          color: Colors.grey[100],
                          child: _buildImagePlaceholder(context),
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: Column(
              children: [
                MerchantAppBar(
                  titleKey: 'my_items',
                  showBackButton: true,
                  isHomePage: false,
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('items')
                        .where('merchantId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final items = snapshot.data?.docs ?? [];

                      if (items.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          try {
                            final doc = items[index];
                            final item = doc.data() as Map<String, dynamic>;
                            return _buildItemCard(item, doc.id);
                          } catch (e) {
                            print('Error rendering item at index $index: $e');
                            return const SizedBox.shrink();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _navigateWithLoading('/merchant_add'),
            backgroundColor: const Color(0xFF062f6e),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
        if (_isLoading)
          const LoadingOverlay(),
      ],
    );
  }
}