import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_localizations.dart';
import '../widgets/client_app_bar.dart';
import '../widgets/animated_nav_bar.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _cartItems = [];
  late drive.DriveApi _driveApi;
  AuthClient? _authClient;
  bool _isInitialized = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  double _subtotal = 0.0;
  double _tax = 0.0;
  double _total = 0.0;
  final double _taxRate = 0.16; // 16% tax rate
  final Map<String, String> _itemNotes = {};

  @override
  void initState() {
    super.initState();
    _initializeDriveApi().then((_) {
      if (mounted) {
        _loadCartItems();
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

  void _calculateTotals() {
    _subtotal = _cartItems.fold(0.0, (sum, item) {
      final price = item['price'] as double;
      final quantity = item['cartQuantity'] as int;
      return sum + (price * quantity);
    });
    _tax = _subtotal * _taxRate;
    _total = _subtotal + _tax;
    setState(() {}); // Update the UI with new totals
  }

  Future<void> _loadCartItems() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _cartItems = [];
        });
        return;
      }

      final cartSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .orderBy('addedAt', descending: true)
          .get();

      final List<Map<String, dynamic>> items = [];
      
      for (var doc in cartSnapshot.docs) {
        final itemId = doc.data()['itemId'] as String;
        final cartQuantity = doc.data()['quantity'] as int;
        
        final itemDoc = await FirebaseFirestore.instance
            .collection('items')
            .doc(itemId)
            .get();
        
        if (itemDoc.exists) {
          final itemData = itemDoc.data()!;
          final availableQuantity = (itemData['quantity'] ?? 0) is int 
              ? itemData['quantity'] as int 
              : int.parse(itemData['quantity'].toString());
              
          items.add({
            'id': itemDoc.id,
            'cartDocId': doc.id,
            'cartQuantity': cartQuantity,
            'availableQuantity': availableQuantity,
            'price': (itemData['price'] ?? 0.0) is double 
                ? itemData['price'] as double 
                : double.parse(itemData['price'].toString()),
            'name': itemData['name'] ?? '',
            'category_en': itemData['category_en'] ?? '',
            'category_ar': itemData['category_ar'] ?? '',
            'images': itemData['images'] ?? [],
            'merchantId': itemData['merchantId'],
          });
        }
      }

      if (mounted) {
        setState(() {
          _cartItems = items;
          _isLoading = false;
          _calculateTotals();
        });
      }
    } catch (e) {
      print('Error loading cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_loading_cart')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateQuantity(String itemId, int newQuantity) async {
    if (newQuantity < 1) return;
    
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final cartItem = _cartItems.firstWhere((item) => item['id'] == itemId);
      final cartDocId = cartItem['cartDocId'];

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(cartDocId)
          .update({'quantity': newQuantity});

      setState(() {
        cartItem['cartQuantity'] = newQuantity;
        _calculateTotals();
      });
    } catch (e) {
      print('Error updating quantity: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('error_updating_cart')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeItem(String itemId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(itemId)
          .delete();

      setState(() {
        _cartItems.removeWhere((item) => item['id'] == itemId);
      });
      await _loadCartItems(); // Reload to update total

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('removed_from_cart')),
          ),
        );
      }
    } catch (e) {
      print('Error removing item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_updating_cart')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _placeOrder() async {
    try {
      setState(() => _isLoading = true);
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Create a new order document
      final orderRef = await FirebaseFirestore.instance.collection('orders').add({
        'userId': userId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'subtotal': _subtotal,
        'tax': _tax,
        'total': _total,
        'itemsCount': _cartItems.fold(0, (sum, item) => sum + (item['cartQuantity'] as int)),
      });

      // Add order items
      for (var item in _cartItems) {
        await orderRef.collection('items').add({
          'itemId': item['id'],
          'merchantId': item['merchantId'], // Make sure this is loaded in _loadCartItems
          'quantity': item['cartQuantity'],
          'price': item['price'],
          'name': item['name'],
          'category_en': item['category_en'],
          'category_ar': item['category_ar'],
          'images': item['images'],
          'note': _itemNotes[item['id']] ?? '',
        });
      }

      // Clear the cart
      final batch = FirebaseFirestore.instance.batch();
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart');
      
      for (var item in _cartItems) {
        batch.delete(cartRef.doc(item['cartDocId']));
      }
      await batch.commit();

      // Refresh cart
      await _loadCartItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('order_placed_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error placing order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_placing_order')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ClientAppBar(
        titleKey: AppLocalizations.of(context).translate('cart'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
              ? _buildEmptyCart()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cartItems.length,
                        itemBuilder: (context, index) => _buildCartItem(_cartItems[index]),
                      ),
                    ),
                    _buildOrderSummary(),
                  ],
                ),
      bottomNavigationBar: AnimatedNavBar(
        selectedIndex: 4,
        onItemSelected: (index) {
          if (index == 4) return;
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
              route = '/chat';
              break;
            case 5:
              route = '/profile';
              break;
            default:
              return;
          }
          Navigator.pushReplacementNamed(context, route);
        },
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('empty_cart'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF062f6e),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('start_shopping'),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/browse'),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(AppLocalizations.of(context).translate('browse_items')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final images = List<String>.from(item['images'] ?? []);
    final availableQuantity = item['availableQuantity'] as int;
    final cartQuantity = item['cartQuantity'] as int;

    return Container(
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
      child: Column(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFe2211c),
                                ),
                                onPressed: () => _showRemoveConfirmation(item['id']),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.note_add_outlined,
                                  color: _itemNotes.containsKey(item['id']) 
                                      ? const Color(0xFF062f6e)
                                      : Colors.grey,
                                ),
                                onPressed: () => _showNoteDialog(item['id']),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic ? (item['category_ar'] ?? '') : (item['category_en'] ?? ''),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$availableQuantity ${AppLocalizations.of(context).translate('items_available')}',
                        style: TextStyle(
                          color: availableQuantity > 0 ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item['price'].toStringAsFixed(2)} ${AppLocalizations.of(context).translate('currency')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF062f6e),
                                ),
                              ),
                            ],
                          ),
                          _buildQuantitySelector(item, availableQuantity),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRemoveConfirmation(String itemId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context).translate('remove_from_cart'),
            style: const TextStyle(
              color: Color(0xFF062f6e),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            AppLocalizations.of(context).translate('remove_confirmation'),
          ),
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
                _removeItem(itemId);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuantitySelector(Map<String, dynamic> item, int availableStock) {
    final controller = TextEditingController(
      text: item['cartQuantity'].toString()
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () {
              final currentValue = item['cartQuantity'] as int;
              if (currentValue > 1) {
                final newQuantity = currentValue - 1;
                _updateQuantity(item['id'], newQuantity);
                controller.text = newQuantity.toString();
              }
            },
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            color: const Color(0xFF062f6e),
          ),
          SizedBox(
            width: 40,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              onChanged: (value) {
                final newQuantity = int.tryParse(value) ?? 1;
                if (newQuantity >= 1 && newQuantity <= availableStock) {
                  _updateQuantity(item['id'], newQuantity);
                } else if (newQuantity > availableStock) {
                  controller.text = availableStock.toString();
                  _updateQuantity(item['id'], availableStock);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).translate('max_quantity_exceeded')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              final currentValue = item['cartQuantity'] as int;
              if (currentValue < availableStock) {
                final newQuantity = currentValue + 1;
                _updateQuantity(item['id'], newQuantity);
                controller.text = newQuantity.toString();
              }
            },
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            color: const Color(0xFF062f6e),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
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
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow(
              AppLocalizations.of(context).translate('items_count'),
              _cartItems.fold(0, (sum, item) => sum + (item['cartQuantity'] as int)),
              isCount: true,
              icon: Icons.shopping_bag_outlined,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              AppLocalizations.of(context).translate('subtotal'),
              _subtotal,
              icon: Icons.receipt_outlined,
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(
              AppLocalizations.of(context).translate('tax'),
              _tax,
              icon: Icons.account_balance_outlined,
            ),
            const Divider(height: 24),
            _buildSummaryRow(
              AppLocalizations.of(context).translate('total'),
              _total,
              isTotal: true,
              icon: Icons.paid_outlined,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cartItems.isEmpty ? null : _placeOrder,
                icon: const Icon(Icons.shopping_cart_checkout),
                label: Text(
                  AppLocalizations.of(context).translate('place_order'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF062f6e),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, dynamic value, {bool isTotal = false, bool isCount = false, IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: isTotal ? 24 : 20,
                color: isTotal ? const Color(0xFF062f6e) : Colors.grey[600],
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 18 : 16,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? const Color(0xFF062f6e) : null,
              ),
            ),
          ],
        ),
        Text(
          isCount 
              ? value.toString()
              : '${value.toStringAsFixed(2)} ${AppLocalizations.of(context).translate('currency')}',
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? const Color(0xFF062f6e) : null,
          ),
        ),
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
    } else if (imageUrl.contains('/d/')) {
      fileId = imageUrl.split('/d/').last.split('/').first;
    } else {
      // If URL is already in the correct format
      fileId = imageUrl;
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

  Future<void> _showNoteDialog(String itemId) async {
    final TextEditingController noteController = TextEditingController(
      text: _itemNotes[itemId] ?? ''
    );

    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.note_add_outlined,
                      color: Color(0xFF062f6e),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context).translate('item_note'),
                      style: const TextStyle(
                        color: Color(0xFF062f6e),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: noteController,
                    maxLines: 4,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).translate('item_note_hint'),
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text(
                        AppLocalizations.of(context).translate('cancel'),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (noteController.text.trim().isEmpty) {
                            _itemNotes.remove(itemId);
                          } else {
                            _itemNotes[itemId] = noteController.text.trim();
                          }
                        });
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF062f6e),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context).translate('save'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}