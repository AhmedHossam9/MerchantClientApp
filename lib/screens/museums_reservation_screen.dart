import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import '../utils/museum.dart';
import '../theme/theme_provider.dart';

class MuseumsReservationScreen extends StatefulWidget {
  const MuseumsReservationScreen({Key? key}) : super(key: key);

  @override
  _MuseumsReservationScreenState createState() => _MuseumsReservationScreenState();
}

class _MuseumsReservationScreenState extends State<MuseumsReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _error;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nationalityController = TextEditingController();
  final TextEditingController _visitDateController = TextEditingController();
  final TextEditingController _numberOfTicketsController = TextEditingController();
  
  List<Museum> museums = [];
  Museum? _selectedMuseum;
  double _totalPrice = 0;

  @override
  void initState() {
    super.initState();
    _loadMuseums();
  }

  Future<void> _loadMuseums() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('museums')
          .orderBy('name')
          .get();

      setState(() {
        museums = snapshot.docs
            .map((doc) => Museum.fromMap(doc.id, doc.data()))
            .toList();
        _isLoading = false;
        if (museums.isNotEmpty) {
          _selectedMuseum = museums.first;
          _updateTotalPrice();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading museums';
        _isLoading = false;
      });
    }
  }

  void _updateTotalPrice() {
    if (_selectedMuseum != null && _numberOfTicketsController.text.isNotEmpty) {
      final tickets = int.tryParse(_numberOfTicketsController.text) ?? 0;
      setState(() {
        _totalPrice = _selectedMuseum!.price * tickets;
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
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              ServiceAppBar(titleKey: 'reserve_museum_ticket'),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              ServiceAppBar(titleKey: 'reserve_museum_ticket'),
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

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(titleKey: 'reserve_museum_ticket'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMuseumDropdown(),
                      if (_selectedMuseum?.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _selectedMuseum!.description!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
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
                        controller: _nationalityController,
                        label: 'nationality',
                        icon: Icons.flag_rounded,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context).translate('nationality_required');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildDateField(
                        controller: _visitDateController,
                        label: 'visit_date',
                        icon: Icons.calendar_today_rounded,
                        onTap: () => _selectDate(context),
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
                          return null;
                        },
                        onChanged: (value) => _updateTotalPrice(),
                      ),
                      const SizedBox(height: 24),
                      if (_totalPrice > 0)
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

  Widget _buildMuseumDropdown() {
    return DropdownButtonFormField<Museum>(
      dropdownColor: Provider.of<ThemeProvider>(context).isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      style: TextStyle(
        color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.white : Colors.black87,
      ),
      value: _selectedMuseum,
      items: museums.map((museum) {
        return DropdownMenuItem<Museum>(
          value: museum,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    museum.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${museum.price.toStringAsFixed(2)} EGP',
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
      onChanged: (Museum? value) {
        setState(() {
          _selectedMuseum = value;
          _updateTotalPrice();
        });
      },
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate('select_museum'),
        labelStyle: TextStyle(
          color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixIcon: const Icon(Icons.museum_rounded, color: Color(0xFFe2211c)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        filled: true,
        fillColor: Provider.of<ThemeProvider>(context).isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      isExpanded: true,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    VoidCallback? onTap,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate(label),
        labelStyle: TextStyle(
          color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFe2211c)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        filled: true,
        fillColor: Provider.of<ThemeProvider>(context).isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      validator: validator,
      keyboardType: keyboardType,
      onTap: onTap,
      readOnly: onTap != null,
      onChanged: onChanged,
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(
        color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate(label),
        labelStyle: TextStyle(
          color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFe2211c)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Provider.of<ThemeProvider>(context).isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        filled: true,
        fillColor: Provider.of<ThemeProvider>(context).isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      readOnly: true,
      onTap: onTap,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).translate('date_required');
        }
        return null;
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() {
        _visitDateController.text = picked.toLocal().toString().split(' ')[0];
      });
    }
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
    if (!_formKey.currentState!.validate() || _selectedMuseum == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      final tickets = int.parse(_numberOfTicketsController.text);
      
      await FirebaseFirestore.instance.collection('museum_reservations').add({
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'museumId': _selectedMuseum!.id,
        'museumName': _selectedMuseum!.name,
        'fullName': _nameController.text.trim(),
        'nationality': _nationalityController.text.trim(),
        'visitDate': _visitDateController.text,
        'numberOfTickets': tickets,
        'pricePerTicket': _selectedMuseum!.price,
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