import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_localizations.dart';
import 'package:demo/widgets/slideshow_background.dart';
import '../utils/app_functions.dart'; // Import the validation functions

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('register')),
      ),
      body: Stack(
        fit: StackFit.expand,
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Center(
                child: Form(
                  key: _formKey, // Set form key for validation
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          border: Border.all(
                            color: Colors.black,
                            width: 3.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: EdgeInsets.all(10),
                        child: Image.asset(
                          'assets/efinance.png',
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(height: 40),
                      _buildTextField(_usernameController, 'username', Icons.person),
                      SizedBox(height: 20),
                      _buildEmailField(),
                      SizedBox(height: 20),
                      _buildAgeField(),
                      SizedBox(height: 20),
                      _buildNationalIdField(),
                      SizedBox(height: 20),
                      GestureDetector(
                        onTap: _selectDateOfBirth,
                        child: AbsorbPointer(
                          child: _buildTextField(_dobController, 'date_of_birth', Icons.calendar_today),
                        ),
                      ),
                      SizedBox(height: 20),
                      _buildTextField(_addressController, 'address', Icons.location_on),
                      SizedBox(height: 20),
                      _buildPasswordField(),
                      SizedBox(height: 20),
                      _buildPhoneNumberField(),
                      SizedBox(height: 20),
                      _buildAccountTypeDropdown(),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _handleRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 40.0),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('register'),
                          style: TextStyle(fontSize: 18, color: Colors.white),
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

Widget _buildTextField(
  TextEditingController controller,
  String label,
  IconData icon, {
  bool obscureText = false,
  FormFieldValidator<String>? validate,
  void Function(String)? onChanged,  // Added onChanged parameter
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          AppLocalizations.of(context).translate(label),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      TextFormField(
        controller: controller,
        obscureText: obscureText,  // For password visibility
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
          errorStyle: TextStyle(color: Colors.white), // Change error message color to white
        ),
        validator: validate, // Use the passed validation function
        onChanged: onChanged, // Add onChanged functionality
      ),
    ],
  );
}


Widget _buildEmailField() {
  return _buildTextField(
    _emailController,
    'email', // Matches key in ar.json
    Icons.email,
    validate: (value) {
      if (value == null || value.isEmpty) {
        return AppLocalizations.of(context).translate('Email is required');
      }
      String? validationError = validateEmail(value); // Assume validateEmail returns a translated key
      if (validationError != null) {
        return AppLocalizations.of(context).translate('Invalid Email'); // Translate specific error if needed
      }
      return null;
    },
  );
}


Widget _buildNationalIdField() {
  return _buildTextField(
    _nationalIdController,
    'nationalid', // Use 'nationalid' to match ar.json key
    Icons.perm_identity,
    validate: (value) {
      if (value == null || value.isEmpty) {
        return AppLocalizations.of(context).translate('National ID is required');
      }
      // Validate Egyptian National ID format
      String? validationError = validateEgyptianNationalID(value);
      if (validationError != null) {
        return AppLocalizations.of(context).translate('Invalid National ID');
      }
      return null;
    },
  );
}


Widget _buildAgeField() {
  return _buildTextField(
    _ageController,
    'age', // Use 'age' to match ar.json key
    Icons.calendar_today,
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
    _passwordController,
    'password', // Matches key in ar.json
    Icons.lock,
    obscureText: true,
    validate: (value) {
      if (value == null || value.isEmpty) {
        return AppLocalizations.of(context).translate('Password is required');
      }
      String? validationError = validatePassword(value);
      if (validationError != null) {
        return AppLocalizations.of(context).translate('Invalid Password'); // Translate specific error if needed
      }
      return null;
    },
  );
}


Widget _buildPhoneNumberField() {
  return _buildTextField(
    _phoneNumberController,
    'phonenumber', // Matches key in ar.json
    Icons.phone,
    validate: (value) {
      if (value == null || value.isEmpty) {
        return AppLocalizations.of(context).translate('Phone number is required');
      }
      String? validationError = validateEgyptianPhoneNumber(value);
      if (validationError != null) {
        return AppLocalizations.of(context).translate('Invalid Phone Number');
      }
      return null;
    },
  );
}



  // Dropdown to select account type
  Widget _buildAccountTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            AppLocalizations.of(context).translate('accounttype'),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          value: _accountType,
          items: ['Client', 'Merchant'].map((String type) {
            return DropdownMenuItem<String>(value: type, child: Text(type));
          }).toList(),
          onChanged: (value) {
            setState(() {
              _accountType = value!;
            });
          },
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.account_circle, color: Theme.of(context).colorScheme.primary),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  // Select the date of birth using DatePicker
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

  // Handling Registration Logic
  void _handleRegistration() {
    if (_formKey.currentState?.validate() ?? false) {
      // If form is valid, proceed with registration
      _registerUser();
    } else {
      // Show snack bar with error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('validation_failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Register user with Firebase Authentication and Firestore
  void _registerUser() async {
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final user = userCredential.user;

      if (user != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': _usernameController.text,
          'email': _emailController.text,
          'age': _ageController.text,
          'nationalid': _nationalIdController.text,
          'dob': _dobController.text,
          'address': _addressController.text,
          'phone_number': _phoneNumberController.text,
          'account_type': _accountType,
        });

        // Navigate to next screen or home
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).translate('registration_error')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
