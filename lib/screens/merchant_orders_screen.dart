import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_localizations.dart';
import '../widgets/merchant_app_bar.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:typed_data';

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({Key? key}) : super(key: key);

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  late drive.DriveApi _driveApi;
  AuthClient? _authClient;

  @override
  void initState() {
    super.initState();
    _initializeDriveApi().then((_) {
      _loadOrders();
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
    } catch (e) {
      print('Error initializing Drive API: $e');
    }
  }

  Future<void> _loadOrders() async {
    try {
      final merchantId = _auth.currentUser?.uid;
      
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();

      final orders = await Future.wait(
        ordersSnapshot.docs.map((doc) async {
          final orderData = doc.data();
          
          final itemsSnapshot = await doc.reference.collection('items').get();
          final merchantItems = itemsSnapshot.docs.where((item) {
            final itemData = item.data();
            return itemData['merchantId'] == merchantId;
          }).toList();
          
          if (merchantItems.isEmpty) {
            return null;
          }
          
          final customerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(orderData['userId'])
              .get();
          
          final customerData = customerDoc.data() ?? {};
          
          final items = merchantItems.map((item) {
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
            'total': items.fold(0.0, (sum, item) => 
              sum + (item['price'] * item['quantity'])),
            'items': items,
            'notes': orderData['notes'],
            'customer': {
              'name': customerData['name'] ?? 'N/A',
              'email': customerData['email'] ?? 'N/A',
              'phone': customerData['phone'] ?? 'N/A',
              'address': customerData['address'] ?? 'N/A',
            },
          };
        }),
      );

      final validOrders = orders.where((order) => order != null).toList();
      
      validOrders.sort((a, b) {
        final Map<String, int> statusPriority = {
          'pending': 0,
          'merchant_accepted': 1,
          'payment_pending': 2,
          'processing': 3,
          'completed': 4,
          'cancelled': 5,
        };

        final statusA = (a?['status'] as String).toLowerCase();
        final statusB = (b?['status'] as String).toLowerCase();

        return (statusPriority[statusA] ?? 6)
            .compareTo(statusPriority[statusB] ?? 6);
      });

      if (mounted) {
        setState(() {
          _orders = validOrders.cast<Map<String, dynamic>>();
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

  Future<void> _updateOrderStatus(String orderId, String status, {String? rejectionReason}) async {
    try {
      setState(() => _isLoading = true);
      
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(updateData);

      await _loadOrders();

      if (mounted) {
        String message;
        if (status == 'processing') {
          message = AppLocalizations.of(context).translate('order_processing');
        } else if (status == 'completed') {
          message = AppLocalizations.of(context).translate('order_completed');
        } else {
          message = AppLocalizations.of(context).translate('order_status_updated');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('error_updating_order')),
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

  Future<void> _showRejectionDialog(String orderId) async {
    final TextEditingController reasonController = TextEditingController();
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context).translate('rejection_reason_title'),
            style: const TextStyle(
              color: Color(0xFF062f6e),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context).translate('rejection_reason_description'),
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).translate('rejection_reason_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFF062f6e),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                AppLocalizations.of(context).translate('cancel'),
                style: const TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                AppLocalizations.of(context).translate('submit'),
                style: const TextStyle(
                  color: Color(0xFFe2211c),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).translate('rejection_reason_required')),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop();
                _updateOrderStatus(orderId, 'rejected', rejectionReason: reasonController.text.trim());
              },
            ),
          ],
        );
      },
    ).then((_) {
      reasonController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MerchantAppBar(
        titleKey: 'merchant_orders',
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
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final bool isPending = order['status'].toLowerCase() == 'pending';
    final bool isInactive = order['status'].toLowerCase() == 'cancelled' || 
                           order['status'].toLowerCase() == 'completed';
    final bool canProcess = order['status'].toLowerCase() == 'payment_pending';
    final bool canComplete = order['status'].toLowerCase() == 'processing';
    
    return Opacity(
      opacity: isInactive ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: isInactive ? 1 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order['id'].substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      AppLocalizations.of(context).translate('status_${order['status'].toLowerCase()}'),
                      style: TextStyle(
                        color: _getStatusColor(order['status']),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              
              // Customer Details Section
              Text(
                AppLocalizations.of(context).translate('customer_details'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF062f6e),
                ),
              ),
              const SizedBox(height: 8),
              _buildCustomerDetail(Icons.person, 'name', order['customer']['name']),
              _buildCustomerDetail(Icons.email, 'email', order['customer']['email']),
              _buildCustomerDetail(Icons.phone, 'phone', order['customer']['phone']),
              _buildCustomerDetail(Icons.location_on, 'address', order['customer']['address']),
              
              const Divider(height: 24),
              
              // Order Items
              ...List.generate(
                (order['items'] as List).length,
                (index) => _buildOrderItem(order['items'][index]),
              ),
              
              const Divider(height: 24),
              
              // Total and Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('total'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${order['total'].toStringAsFixed(2)} ${AppLocalizations.of(context).translate('currency')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF062f6e),
                    ),
                  ),
                ],
              ),
              
              // Action Buttons for Pending Orders
              if (isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _showRejectionDialog(order['id']),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFe2211c)),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('reject'),
                          style: const TextStyle(
                            color: Color(0xFFe2211c),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateOrderStatus(order['id'], 'merchant_accepted'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF062f6e),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('accept'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (canProcess) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateOrderStatus(order['id'], 'processing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF062f6e),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).translate('out_for_shipping'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              if (canComplete) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateOrderStatus(order['id'], 'completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).translate('mark_as_complete'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerDetail(IconData icon, String labelKey, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '${AppLocalizations.of(context).translate(labelKey)}: ',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: FutureBuilder<Widget>(
                future: _buildItemImage(context, item['images'][0]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  return snapshot.data ?? _buildImagePlaceholder();
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
                  item['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item['note'] != null && item['note'].isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item['note'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${item['quantity']} × ${item['price']} ${AppLocalizations.of(context).translate('currency')}',
                  style: const TextStyle(
                    color: Color(0xFF062f6e),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reuse the same helper methods from OrdersScreen
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
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
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
            AppLocalizations.of(context).translate('no_merchant_orders'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF062f6e),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('waiting_for_orders'),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
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
}