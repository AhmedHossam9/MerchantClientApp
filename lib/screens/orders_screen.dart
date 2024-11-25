import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/app_localizations.dart';
import '../widgets/client_app_bar.dart';
import '../widgets/animated_nav_bar.dart';
import 'dart:typed_data';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  late drive.DriveApi _driveApi;
  AuthClient? _authClient;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeDriveApi().then((_) {
      if (mounted) {
        _loadOrders();
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

  Future<void> _loadOrders() async {
    try {
      final userId = _auth.currentUser?.uid;

      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final orders = await Future.wait(
        ordersSnapshot.docs.map((doc) async {
          final orderData = doc.data();
          final itemsSnapshot = await doc.reference.collection('items').get();
          
          final items = itemsSnapshot.docs.map((item) {
            final itemData = item.data();
            return {
              ...itemData,
              'itemId': itemData['itemId'],
            };
          }).toList();

          return {
            'id': doc.id,
            'status': orderData['status'],
            'createdAt': orderData['createdAt'],
            'total': orderData['total'],
            'items': items,
            'notes': orderData['notes'],
            'rejectionReason': orderData['rejectionReason'],
            'isRated': orderData['isRated'] ?? false,
            'ratedAt': orderData['ratedAt'],
          };
        }),
      );

      // Sort orders by status priority
      orders.sort((a, b) {
        final Map<String, int> statusPriority = {
          'pending': 0,
          'merchant_accepted': 1,
          'payment_pending': 2,
          'processing': 3,
          'out_for_shipping': 4,
          'completed_and_rated': 5,
          'completed': 6,
          'cancelled': 7,
          'rejected': 8,
        };

        final statusA = (a['status'] as String).toLowerCase();
        final statusB = (b['status'] as String).toLowerCase();

        return (statusPriority[statusA] ?? 9)
            .compareTo(statusPriority[statusB] ?? 9);
      });

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_loading_orders')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'merchant_accepted':
        return Colors.purple;
      case 'payment_pending':
        return Colors.blue;
      case 'processing':
        return Colors.green;
      case 'out_for_shipping':
        return Colors.amber;
      case 'completed':
        return Colors.teal;
      case 'completed_and_rated':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ClientAppBar(
        titleKey: 'orders',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _buildEmptyOrders()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
                ),
      bottomNavigationBar: AnimatedNavBar(
        selectedIndex: 3,
        onItemSelected: (index) {
          if (index == 3) return;
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
            case 4:
              route = '/cart';
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

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final bool canCancel = order['status'].toLowerCase() == 'pending' || 
                          order['status'].toLowerCase() == 'processing';
    final bool canPay = order['status'].toLowerCase() == 'merchant_accepted';
    final bool canRate = order['status'].toLowerCase() == 'completed';
    final bool isInactive = order['status'].toLowerCase() == 'cancelled' || 
                           order['status'].toLowerCase() == 'rejected';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isInactive ? Colors.grey[300]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Opacity(
        opacity: isInactive ? 0.7 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Bar
            Container(
              decoration: BoxDecoration(
                color: _getStatusColor(order['status']).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).translate(order['status'].toLowerCase()),
                    style: TextStyle(
                      color: _getStatusColor(order['status']),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatDate(order['createdAt'] as Timestamp),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Order Items
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items List
                  ...List.generate(
                    (order['items'] as List).length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: FutureBuilder<Widget>(
                                future: _buildItemImage(
                                  context,
                                  order['items'][index]['images'][0],
                                ),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return snapshot.data!;
                                  }
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order['items'][index]['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Quantity: ${order['items'][index]['quantity']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${order['items'][index]['price']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 24),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('total'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '\$${order['total']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF062f6e),
                        ),
                      ),
                    ],
                  ),

                  // Action Buttons
                  if (!isInactive) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (canCancel)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _cancelOrder(order['id']),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context).translate('cancel_order'),
                              ),
                            ),
                          ),
                        if (canPay || canRate) ...[
                          if (canCancel) const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => canPay
                                  ? _confirmPayment(order['id'])
                                  : _showRatingDialog(order['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF062f6e),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                AppLocalizations.of(context).translate(
                                  canPay ? 'confirm_payment' : 'rate_order',
                                ),
                              ),
                            ),
                          ),
                        ],
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

  String _getGoogleDriveUrl(String url) {
    // Extract file ID from the uc URL
    final RegExp regExp = RegExp(r'id=([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(url);
    
    if (match != null && match.groupCount >= 1) {
      final fileId = match.group(1);
      // Use the direct download URL format
      return 'https://drive.google.com/uc?export=download&id=$fileId';
    }
    
    return url;
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('no_orders'),
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
        ],
      ),
    );
  }

  Future<void> _showCancelConfirmation(String orderId) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context).translate('cancel_order_title'),
            style: const TextStyle(
              color: Color(0xFF062f6e),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            AppLocalizations.of(context).translate('cancel_order_confirmation'),
          ),
          actions: [
            TextButton(
              child: Text(
                AppLocalizations.of(context).translate('no'),
                style: const TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                AppLocalizations.of(context).translate('yes'),
                style: const TextStyle(color: Color(0xFFe2211c)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _cancelOrder(orderId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      setState(() => _isLoading = true);
      
      // Update order status to cancelled
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Refresh orders list
      await _loadOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('order_cancelled_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error cancelling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_cancelling_order')),
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

  Future<Widget> _buildItemImage(BuildContext context, String imageUrl) async {
    try {
      final RegExp regExp = RegExp(r'id=([a-zA-Z0-9_-]+)');
      final match = regExp.firstMatch(imageUrl);
      
      final fileId = match?.group(1);
      if (fileId == null) {
        return _buildImagePlaceholder();
      }
      
      final media = await _driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      
      final List<int> dataBytes = [];
      await for (var data in media.stream) {
        dataBytes.addAll(data);
      }
      
      return Image.memory(
        Uint8List.fromList(dataBytes),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildImagePlaceholder();
        },
      );
    } catch (e) {
      return _buildImagePlaceholder();
    }
  }

  Future<void> _confirmPayment(String orderId) async {
    try {
      setState(() => _isLoading = true);
      
      // Update order status to payment_pending
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'payment_pending',
        'paymentConfirmedAt': FieldValue.serverTimestamp(),
      });

      // Refresh orders list
      await _loadOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('payment_confirmed')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error confirming payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_confirming_payment')),
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

  Future<void> _showRatingDialog(String orderId) async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      
      if (!orderDoc.exists || !mounted) return;

      final orderData = orderDoc.data();
      if (orderData == null) return;

      final itemsSnapshot = await orderDoc.reference.collection('items').get();
      final items = itemsSnapshot.docs.map((doc) => {
        ...doc.data(),
        'itemId': doc.data()['itemId'],
        'name': doc.data()['name'],
      }).toList();

      if (items.isEmpty || !mounted) return;

      final merchantId = items.first['merchantId'] as String?;
      if (merchantId == null) return;

      double merchantRating = 3.0;
      final merchantCommentController = TextEditingController();
      final Map<String, double> itemRatings = {};
      final Map<String, TextEditingController> itemCommentControllers = {};
      
      for (var item in items) {
        itemRatings[item['itemId']] = 3.0;
        itemCommentControllers[item['itemId']] = TextEditingController();
      }

      bool? result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context).translate('rate_order'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF062f6e),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Container(
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
                            AppLocalizations.of(context).translate('rate_merchant'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF062f6e),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: RatingBar.builder(
                              initialRating: merchantRating,
                              minRating: 1,
                              direction: Axis.horizontal,
                              allowHalfRating: true,
                              itemCount: 5,
                              itemSize: 40,
                              unratedColor: Colors.grey[300],
                              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                              itemBuilder: (context, _) => const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                              ),
                              onRatingUpdate: (rating) {
                                merchantRating = rating;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: merchantCommentController,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context).translate('merchant_comment_hint'),
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ...items.map((item) {
                      final itemId = item['itemId'] as String;
                      return Column(
                        children: [
                          Container(
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
                                  '${AppLocalizations.of(context).translate('rate_item')}: ${item['name']}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF062f6e),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: RatingBar.builder(
                                    initialRating: itemRatings[itemId]!,
                                    minRating: 1,
                                    direction: Axis.horizontal,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    itemSize: 40,
                                    unratedColor: Colors.grey[300],
                                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    itemBuilder: (context, _) => const Icon(
                                      Icons.star_rounded,
                                      color: Colors.amber,
                                    ),
                                    onRatingUpdate: (rating) {
                                      itemRatings[itemId] = rating;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: itemCommentControllers[itemId],
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context).translate('item_comment_hint'),
                                    hintStyle: TextStyle(color: Colors.grey[400]),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }).toList(),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (merchantCommentController.text.trim().isEmpty ||
                              itemCommentControllers.values.any((controller) => 
                                  controller.text.trim().isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)
                                    .translate('comment_required')),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          try {
                            // Show loading indicator
                            if (!mounted) return;
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            // Save all ratings
                            await FirebaseFirestore.instance
                                .collection('merchants')
                                .doc(merchantId)
                                .collection('ratings')
                                .add({
                              'orderId': orderId,
                              'rating': merchantRating,
                              'comment': merchantCommentController.text.trim(),
                              'userId': _auth.currentUser?.uid,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                            for (var item in items) {
                              final itemId = item['itemId'] as String;
                              await FirebaseFirestore.instance
                                  .collection('items')
                                  .doc(itemId)
                                  .collection('ratings')
                                  .add({
                                'orderId': orderId,
                                'rating': itemRatings[itemId],
                                'comment': itemCommentControllers[itemId]!.text.trim(),
                                'userId': _auth.currentUser?.uid,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            }

                            await FirebaseFirestore.instance
                                .collection('orders')
                                .doc(orderId)
                                .update({
                              'merchantRating': merchantRating,
                              'merchantComment': merchantCommentController.text.trim(),
                              'itemRatings': items.map((item) => {
                                'itemId': item['itemId'],
                                'rating': itemRatings[item['itemId']],
                                'comment': itemCommentControllers[item['itemId']]!
                                    .text.trim(),
                              }).toList(),
                              'ratedAt': FieldValue.serverTimestamp(),
                              'status': 'completed_and_rated',
                            });

                            if (!mounted) return;
                            Navigator.of(context).pop(); // Close loading
                            Navigator.of(context).pop(true); // Close dialog with success
                          } catch (e) {
                            if (!mounted) return;
                            Navigator.of(context).pop(); // Close loading
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(AppLocalizations.of(context)
                                    .translate('error_saving_rating')),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF062f6e),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('submit'),
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
          );
        },
      );

      // Clean up
      merchantCommentController.dispose();
      for (var controller in itemCommentControllers.values) {
        controller.dispose();
      }

      // Handle result
      if (result == true && mounted) {
        await _loadOrders();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).translate('rating_submitted')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).translate('error_loading_rating_form')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsComplete(String orderId) async {
    try {
      setState(() => _isLoading = true);
      
      // Fetch the order details
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      
      final orderData = orderDoc.data();
      if (orderData == null) return;

      // Update stock quantities
      final items = orderData['items'] as List<dynamic>;
      for (var item in items) {
        final itemId = item['itemId'];
        final quantity = item['quantity'];

        // Decrement the stock quantity
        final itemDoc = FirebaseFirestore.instance
            .collection('items')
            .doc(itemId);

        await itemDoc.update({
          'quantity': FieldValue.increment(-quantity),
        });
      }

      // Update order status to completed
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        // Show rating dialog first
        await _showRatingDialog(orderId);
        
        // Then refresh orders and show completion message
        await _loadOrders();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('order_completed')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error marking order as complete: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_marking_complete')),
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

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return AppLocalizations.of(context).translate('just_now');
        }
        return '${difference.inMinutes} ${AppLocalizations.of(context).translate('minutes_ago')}';
      }
      return '${difference.inHours} ${AppLocalizations.of(context).translate('hours_ago')}';
    } else if (difference.inDays == 1) {
      return AppLocalizations.of(context).translate('yesterday');
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${AppLocalizations.of(context).translate('days_ago')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}