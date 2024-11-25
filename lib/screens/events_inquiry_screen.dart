import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import '../theme/theme_provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EventsInquiryScreen extends StatefulWidget {
  const EventsInquiryScreen({Key? key}) : super(key: key);

  @override
  _EventsInquiryScreenState createState() => _EventsInquiryScreenState();
}

class _EventsInquiryScreenState extends State<EventsInquiryScreen> {
  bool _isLoading = true;
  String? _error;
  List<QueryDocumentSnapshot> _reservations = [];

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'user_not_authenticated';
          _isLoading = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('event_reservations')
          .where('userId', isEqualTo: user.uid)
          .orderBy('submissionDate', descending: true)
          .get();

      setState(() {
        _reservations = snapshot.docs;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      print('Error loading reservations: $e');
      setState(() {
        _error = 'error_loading_reservations';
        _isLoading = false;
      });
    }
  }

  void _showQRCode(BuildContext context, String reservationReference) {
    final isDarkMode = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFe2211c).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.qr_code_rounded,
                      color: Color(0xFFe2211c),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).translate('event_qr'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: reservationReference,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).translate('scan_at_event'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    if (_isLoading) {
      return _buildLoadingScreen(isDarkMode);
    }

    if (_error != null) {
      return _buildErrorScreen(isDarkMode);
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(titleKey: 'event_reservations'),
            Expanded(
              child: _reservations.isEmpty
                  ? _buildEmptyState(isDarkMode)
                  : _buildReservationsList(isDarkMode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(titleKey: 'event_reservations'),
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(titleKey: 'event_reservations'),
            Expanded(
              child: Center(
                child: Text(AppLocalizations.of(context).translate(_error!)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 64,
            color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).translate('no_event_reservations'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).translate('no_event_reservations_desc'),
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsList(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reservations.length,
      itemBuilder: (context, index) {
        final reservation = _reservations[index].data() as Map<String, dynamic>;
        final status = reservation['status'] as String;
        final submissionDate = (reservation['submissionDate'] as Timestamp).toDate();
        final dateFormat = DateFormat('MMM d, y - HH:mm');

        Color statusColor;
        switch (status.toLowerCase()) {
          case 'approved':
            statusColor = Colors.green;
            break;
          case 'pending':
            statusColor = Colors.orange;
            break;
          case 'rejected':
            statusColor = Colors.red;
            break;
          default:
            statusColor = Colors.grey;
        }

        return Card(
          elevation: 0,
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey.withOpacity(0.2),
            ),
          ),
          margin: const EdgeInsets.only(bottom: 16),
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
                        reservation['eventName'] as String,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                        ),
                      ),
                    ),
                    if (status.toLowerCase() == 'approved')
                      GestureDetector(
                        onTap: () => _showQRCode(
                          context,
                          'EVENT-${_reservations[index].id}',
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFe2211c).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.qr_code_rounded,
                            color: Color(0xFFe2211c),
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.confirmation_number_rounded,
                  '${reservation['numberOfTickets']} ${AppLocalizations.of(context).translate('tickets')}',
                  isDarkMode,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.attach_money_rounded,
                  '${reservation['totalPrice'].toStringAsFixed(2)} EGP',
                  isDarkMode,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.access_time_rounded,
                  dateFormat.format(submissionDate),
                  isDarkMode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDarkMode) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFe2211c),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}