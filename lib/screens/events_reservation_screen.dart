import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import '../utils/event.dart';
import '../theme/theme_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class EventsReservationScreen extends StatefulWidget {
  const EventsReservationScreen({Key? key}) : super(key: key);

  @override
  _EventsReservationScreenState createState() => _EventsReservationScreenState();
}

class _EventsReservationScreenState extends State<EventsReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _error;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _numberOfTicketsController = TextEditingController();
  
  List<Event> events = [];
  Event? _selectedEvent;
  double _totalPrice = 0;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _initUserData();
  }

  Future<void> _initUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      // Try to get user's display name
      if (user.displayName?.isNotEmpty ?? false) {
        _nameController.text = user.displayName!;
      }
    }
  }

  Future<void> _loadEvents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('date', isGreaterThan: DateTime.now())
          .orderBy('date')
          .get();

      setState(() {
        events = snapshot.docs
            .map((doc) => Event.fromMap(doc.id, doc.data()))
            .toList();
        _isLoading = false;
        if (events.isNotEmpty) {
          _selectedEvent = events.first;
          _updateTotalPrice();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading events';
        _isLoading = false;
      });
    }
  }

  void _updateTotalPrice() {
    if (_selectedEvent != null && _numberOfTicketsController.text.isNotEmpty) {
      final tickets = int.tryParse(_numberOfTicketsController.text) ?? 0;
      setState(() {
        _totalPrice = _selectedEvent!.price * tickets;
      });
    } else {
      setState(() {
        _totalPrice = 0;
      });
    }
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
            ServiceAppBar(titleKey: 'reserve_event_ticket'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEventDropdown(),
                      if (_selectedEvent != null) ...[
                        const SizedBox(height: 16),
                        _buildEventDetails(),
                      ],
                      const SizedBox(height: 24),
                      _buildTextField(
                        controller: _nameController,
                        label: 'full_name',
                        icon: Icons.person_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context).translate('name_required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: 'email',
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context).translate('email_required');
                          }
                          if (!value.contains('@')) {
                            return AppLocalizations.of(context).translate('invalid_email');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'phone',
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context).translate('phone_required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _numberOfTicketsController,
                        label: 'number_of_tickets',
                        icon: Icons.confirmation_number_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context).translate('tickets_required');
                          }
                          final number = int.tryParse(value);
                          if (number == null || number < 1) {
                            return AppLocalizations.of(context).translate('invalid_ticket_number');
                          }
                          if (_selectedEvent != null && number > _selectedEvent!.availableSeats) {
                            return AppLocalizations.of(context).translate('not_enough_seats');
                          }
                          return null;
                        },
                        onChanged: (value) => _updateTotalPrice(),
                      ),
                      const SizedBox(height: 24),
                      if (_selectedEvent != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(context).translate('total_price'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '${_totalPrice.toStringAsFixed(2)} EGP',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFe2211c),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
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
            ServiceAppBar(titleKey: 'reserve_event_ticket'),
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
            ServiceAppBar(titleKey: 'reserve_event_ticket'),
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

  Widget _buildEventDropdown() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return DropdownButtonFormField<Event>(
      dropdownColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      value: _selectedEvent,
      items: events.map((event) {
        return DropdownMenuItem<Event>(
          value: event,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    event.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${event.price.toStringAsFixed(2)} EGP',
                  style: const TextStyle(
                    color: Color(0xFFe2211c),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: (Event? value) {
        setState(() {
          _selectedEvent = value;
          _updateTotalPrice();
        });
      },
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate('select_event'),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixIcon: const Icon(Icons.event_rounded, color: Color(0xFFe2211c)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      isExpanded: true,
    );
  }

  Widget _buildEventDetails() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final dateFormat = DateFormat('EEEE, MMMM d, y - HH:mm');
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: CachedNetworkImage(
              imageUrl: _selectedEvent!.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedEvent!.description != null) ...[
                  Text(
                    _selectedEvent!.description!,
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildInfoRow(
                  Icons.calendar_today_rounded,
                  dateFormat.format(_selectedEvent!.date),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.location_on_rounded,
                  _selectedEvent!.location,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.event_seat_rounded,
                  '${_selectedEvent!.availableSeats} ${AppLocalizations.of(context).translate('available_seats')}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFe2211c),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate(label),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFe2211c)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      validator: validator,
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmission,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFe2211c),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                AppLocalizations.of(context).translate('submit_reservation'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Future<void> _handleSubmission() async {
    if (!_formKey.currentState!.validate() || _selectedEvent == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final tickets = int.parse(_numberOfTicketsController.text);
      
      await FirebaseFirestore.instance.collection('event_reservations').add({
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'eventId': _selectedEvent!.id,
        'eventName': _selectedEvent!.name,
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'numberOfTickets': tickets,
        'pricePerTicket': _selectedEvent!.price,
        'totalPrice': _totalPrice,
        'status': 'pending',
        'submissionDate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('reservation_submitted')),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('submission_failed')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}