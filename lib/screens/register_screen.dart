import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_localizations.dart';
import 'package:demo/widgets/slideshow_background.dart';
import '../utils/app_functions.dart'; // Import the validation functions
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _nationalIdController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  String _accountType = 'Client';

  // Global key for form validation
  final _formKey = GlobalKey<FormState>();

  // Add animation controllers
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).translate('register'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SlideshowBackground(
            imagePaths: [
              'assets/background1.png',
              'assets/background2.png',
              'assets/background3.png',
              'assets/background4.png'
            ],
            blurAmount: 5.0,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Hero(
                        tag: 'logo',
                        child: AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) => Transform.rotate(
                            angle: _rotationAnimation.value,
                            child: child,
                          ),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/efinance.png',
                              height: 100,
                              width: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: 400),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                              ? const Color(0xFF1E1E1E).withOpacity(0.9) 
                              : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTextField(
                                controller: _usernameController,
                                label: 'username',
                                icon: Icons.person_rounded,
                              ),
                              SizedBox(height: 12),
                              _buildEmailField(),
                              SizedBox(height: 12),
                              _buildNationalIdField(),
                              SizedBox(height: 12),
                              _buildAgeField(),
                              SizedBox(height: 12),
                              GestureDetector(
                                onTap: _selectDateOfBirth,
                                child: AbsorbPointer(
                                  child: _buildTextField(
                                    controller: _dobController,
                                    label: 'date_of_birth',
                                    icon: Icons.calendar_today_rounded,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              _buildTextField(
                                controller: _addressController,
                                label: 'address',
                                icon: Icons.location_on_rounded,
                              ),
                              SizedBox(height: 12),
                              _buildPasswordField(),
                              SizedBox(height: 12),
                              _buildPhoneNumberField(),
                              SizedBox(height: 12),
                              _buildAccountTypeDropdown(),
                              SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: ElevatedButton(
                                  onPressed: _handleRegistration,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.secondary,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        AppLocalizations.of(context).translate('register'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).translate('already_have_account'),
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(context, '/login');
                                    },
                                    child: Text(
                                      AppLocalizations.of(context).translate('login'),
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.blue[300] : const Color(0xFF062f6e),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    FormFieldValidator<String>? validate,
    void Function(String)? onChanged,
    int? maxLength,
    TextInputType? keyboardType,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: TextStyle(
        color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate(label),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
          size: 22,
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF062f6e),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
            width: 2.0,
          ),
        ),
      ),
      validator: validate,
      onChanged: onChanged,
    );
  }

  Widget _buildEmailField() {
    return _buildTextField(
      controller: _emailController,
      label: 'email',
      icon: Icons.email_rounded,
      validate: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).translate('Email is required');
        }
        String? validationError = validateEmail(value); // Using the function from app_functions.dart
        if (validationError != null) {
          return AppLocalizations.of(context).translate(validationError);
        }
        return null;
      },
    );
  }

  Widget _buildNationalIdField() {
    return _buildTextField(
      controller: _nationalIdController,
      label: 'nationalid',
      icon: Icons.perm_identity_rounded,
      maxLength: 14,
      keyboardType: TextInputType.number,
      validate: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).translate('National ID is required');
        }
        String? validationError = validateEgyptianNationalID(value);
        if (validationError != null) {
          return AppLocalizations.of(context).translate(validationError);
        }
        Map<String, dynamic> extractedData = extractDataFromNationalID(value);
        setState(() {
          _ageController.text = extractedData['age'].toString();
          _dobController.text = extractedData['dateOfBirth'];
        });
        return null;
      },
      onChanged: (value) {
        if (value.length == 14) {
          Map<String, dynamic> extractedData = extractDataFromNationalID(value);
          setState(() {
            _ageController.text = extractedData['age'].toString();
            _dobController.text = extractedData['dateOfBirth'];
          });
        }
      },
    );
  }

  Widget _buildAgeField() {
    return _buildTextField(
      controller: _ageController,
      label: 'age',
      icon: Icons.calendar_today,
      validate: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).translate('Age is required');
        }
        int age = int.tryParse(value) ?? 0;
        if (age < 18) {
          return AppLocalizations.of(context).translate('Age must be 18 or older');
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return _buildTextField(
      controller: _passwordController,
      label: 'password',
      icon: Icons.lock_rounded,
      obscureText: true,
      validate: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).translate('Password is required');
        }
        String? validationError = validatePassword(value); // Using the function from app_functions.dart
        if (validationError != null) {
          return AppLocalizations.of(context).translate(validationError);
        }
        return null;
      },
    );
  }

  Widget _buildPhoneNumberField() {
    return _buildTextField(
      controller: _phoneNumberController,
      label: 'phonenumber',
      icon: Icons.phone_rounded,
      maxLength: 11,
      keyboardType: TextInputType.phone,
      validate: (value) {
        if (value == null || value.isEmpty) {
          return AppLocalizations.of(context).translate('Phone number is required');
        }
        String? validationError = validateEgyptianPhoneNumber(value);
        if (validationError != null) {
          return AppLocalizations.of(context).translate(validationError);
        }
        return null;
      },
    );
  }

  Widget _buildAccountTypeDropdown() {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return DropdownButtonFormField<String>(
      value: _accountType,
      items: ['Client', 'Merchant'].map((String type) {
        return DropdownMenuItem<String>(
          value: type,
          child: Text(
            type,
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _accountType = value!;
        });
      },
      dropdownColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
      icon: Icon(
        Icons.arrow_drop_down,
        color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
        size: 24,
      ),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context).translate('accounttype'),
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          Icons.account_circle_rounded,
          color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
          size: 22,
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF062f6e),
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
            width: 2.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: TextStyle(
        color: isDarkMode ? Colors.white : const Color(0xFF062f6e),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  void _selectDateOfBirth() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _dobController.text = pickedDate.toLocal().toString().split(' ')[0];
      });
    }
  }

  void _handleRegistration() {
    if (_formKey.currentState?.validate() ?? false) {
      _registerUser();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('validation_failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _registerUser() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    _animationController.repeat();

    try {
      // Check for existing email
      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .get();

      if (emailQuery.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: AppLocalizations.of(context).translate('email_already_exists'),
        );
      }

      // Check for existing username
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'username-already-in-use',
          message: AppLocalizations.of(context).translate('username_already_exists'),
        );
      }

      // Check for existing phone number
      final phoneQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone_number', isEqualTo: _phoneNumberController.text.trim())
          .get();

      if (phoneQuery.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'phone-already-in-use',
          message: AppLocalizations.of(context).translate('phone_already_exists'),
        );
      }

      // If all checks pass, create the user
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'age': _ageController.text,
          'nationalid': _nationalIdController.text,
          'dob': _dobController.text,
          'address': _addressController.text,
          'phone_number': _phoneNumberController.text.trim(),
          'account_type': _accountType,
        });

        await FirebaseAuth.instance.signOut();
        await _animationController.forward();
        
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('registration_successful')),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      _animationController.stop();
      _animationController.reset();
      
      setState(() {
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'email-already-in-use':
              _errorMessage = AppLocalizations.of(context).translate('email_already_exists');
              break;
            case 'username-already-in-use':
              _errorMessage = AppLocalizations.of(context).translate('username_already_exists');
              break;
            case 'phone-already-in-use':
              _errorMessage = AppLocalizations.of(context).translate('phone_already_exists');
              break;
            default:
              _errorMessage = AppLocalizations.of(context).translate('registration_failed');
          }
        } else {
          _errorMessage = AppLocalizations.of(context).translate('registration_failed');
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
