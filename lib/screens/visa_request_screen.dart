import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/service_app_bar.dart';
import '../utils/app_localizations.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class VisaRequestScreen extends StatefulWidget {
  const VisaRequestScreen({Key? key}) : super(key: key);

  @override
  _VisaRequestScreenState createState() => _VisaRequestScreenState();
}

class _VisaRequestScreenState extends State<VisaRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nationalityController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _passportIdController = TextEditingController();
  final TextEditingController _visaDurationController = TextEditingController();
  final TextEditingController _dateOfEntranceController = TextEditingController();
  final TextEditingController _visaReasonController = TextEditingController();
  
  String _visaEntry = 'Single'; // Default value

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(
              titleKey: 'request_visa',
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'full_name',
                          icon: Icons.person_rounded,
                          validate: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(context).translate('name_required');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _nationalityController,
                          label: 'nationality',
                          icon: Icons.flag_rounded,
                          validate: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(context).translate('nationality_required');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _ageController,
                          label: 'age',
                          icon: Icons.calendar_today_rounded,
                          keyboardType: TextInputType.number,
                          validate: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(context).translate('age_required');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _passportIdController,
                          label: 'passport_id',
                          icon: Icons.document_scanner_rounded,
                          validate: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(context).translate('passport_required');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _visaDurationController,
                          label: 'visa_duration',
                          icon: Icons.timer_rounded,
                          validate: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(context).translate('duration_required');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _selectDateOfEntrance,
                          child: AbsorbPointer(
                            child: _buildTextField(
                              controller: _dateOfEntranceController,
                              label: 'date_of_entrance',
                              icon: Icons.calendar_month_rounded,
                              validate: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppLocalizations.of(context).translate('entrance_date_required');
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _visaReasonController,
                          label: 'visa_reason',
                          icon: Icons.description_rounded,
                          validate: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(context).translate('reason_required');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildVisaEntryDropdown(),
                        const SizedBox(height: 24),
                        _buildSubmitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FormFieldValidator<String>? validate,
    TextInputType? keyboardType,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return TextFormField(
      controller: controller,
      validator: validate,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate(label),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.black54,
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFe2211c),
          size: 18,
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFe2211c),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildVisaEntryDropdown() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return DropdownButtonFormField<String>(
      value: _visaEntry,
      items: ['Single', 'Multiple'].map((String type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(
            AppLocalizations.of(context).translate(type.toLowerCase()),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 14,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _visaEntry = value!;
        });
      },
      dropdownColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate('visa_entry'),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.black54,
          fontSize: 13,
        ),
        prefixIcon: Icon(
          Icons.flight_rounded,
          color: const Color(0xFFe2211c),
          size: 18,
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFe2211c),
            width: 1.5,
          ),
        ),
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
      icon: Icon(
        Icons.arrow_drop_down,
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
    );
  }

  void _selectDateOfEntrance() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateOfEntranceController.text = picked.toLocal().toString().split(' ')[0];
      });
    }
  }

  void _handleSubmission() async {
    if (!_formKey.currentState!.validate()) return;

    // Show preview dialog before actual submission
    final bool? shouldSubmit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _buildPreviewDialog();
      },
    );

    if (shouldSubmit != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }

      // Get user data from the users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User data not found');
      }

      // Create the visa request document
      final visaRequest = {
        'userId': currentUser.uid,
        'userEmail': currentUser.email,
        'username': userDoc.data()?['username'],
        'fullName': _nameController.text.trim(),
        'nationality': _nationalityController.text.trim(),
        'age': int.parse(_ageController.text.trim()),
        'passportId': _passportIdController.text.trim(),
        'visaDuration': _visaDurationController.text.trim(),
        'dateOfEntrance': _dateOfEntranceController.text,
        'visaReason': _visaReasonController.text.trim(),
        'visaEntry': _visaEntry,
        'status': 'pending',  // Initial status
        'submissionDate': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('visa_requests')
          .add(visaRequest);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('request_submitted')),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to the previous screen
      Navigator.pop(context);

    } catch (e) {
      // Show error message
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

  Widget _buildPreviewDialog() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Dialog(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFe2211c).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.visibility_rounded,
                    color: Color(0xFFe2211c),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).translate('preview_request'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).translate('review_before_submit'),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Content
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPreviewItem(
                      'full_name', 
                      _nameController.text,
                      Icons.person_rounded
                    ),
                    _buildPreviewItem(
                      'nationality', 
                      _nationalityController.text,
                      Icons.flag_rounded
                    ),
                    _buildPreviewItem(
                      'age', 
                      _ageController.text,
                      Icons.calendar_today_rounded
                    ),
                    _buildPreviewItem(
                      'passport_id', 
                      _passportIdController.text,
                      Icons.document_scanner_rounded
                    ),
                    _buildPreviewItem(
                      'visa_duration', 
                      _visaDurationController.text,
                      Icons.timer_rounded
                    ),
                    _buildPreviewItem(
                      'date_of_entrance', 
                      _dateOfEntranceController.text,
                      Icons.calendar_month_rounded
                    ),
                    _buildPreviewItem(
                      'visa_reason', 
                      _visaReasonController.text,
                      Icons.description_rounded
                    ),
                    _buildPreviewItem(
                      'visa_entry', 
                      _visaEntry,
                      Icons.flight_rounded
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context).translate('edit'),
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFe2211c),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppLocalizations.of(context).translate('confirm_submit'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItem(String label, String value, IconData icon) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFe2211c).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFe2211c),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate(label),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 42,
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
                AppLocalizations.of(context).translate('submit_request'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}