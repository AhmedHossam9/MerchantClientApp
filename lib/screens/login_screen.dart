import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import '../utils/app_localizations.dart';
import '../widgets/slideshow_background.dart';
import 'merchant_home_page.dart'; // Import the Merchant Home Page

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('login')),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      border: Border.all(color: Colors.black, width: 3.0),
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
                  _buildTextField(
                    controller: _emailController,
                    labelText: AppLocalizations.of(context).translate('email'),
                    icon: Icons.email,
                  ),
                  SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    labelText: AppLocalizations.of(context).translate('password'),
                    icon: Icons.lock,
                    obscureText: true,
                  ),
                  SizedBox(height: 20),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.login, color: Colors.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      padding: EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: _isLoading ? null : _login,
                    label: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            AppLocalizations.of(context).translate('login'),
                            style: TextStyle(color: Colors.white),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Colors.black54, fontSize: 16),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        errorStyle: TextStyle(
          color: const Color.fromARGB(255, 255, 255, 255),
          fontSize: 14.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Validate Email and Password before submitting
      if (_emailController.text.trim().isEmpty) {
        throw FirebaseAuthException(code: 'email-required');
      }
      if (_passwordController.text.trim().isEmpty) {
        throw FirebaseAuthException(code: 'password-required');
      }

      // Attempt Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Fetch the user account type from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      String accountType = userDoc['accountType'];

      if (accountType == 'Merchant') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MerchantHomePage()),
        );
      } else {
        setState(() {
          _errorMessage = AppLocalizations.of(context).translate('Not a merchant account');
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = AppLocalizations.of(context).translate('User not found');
            break;
          case 'wrong-password':
            _errorMessage = AppLocalizations.of(context).translate('Incorrect password');
            break;
          case 'invalid-email':
            _errorMessage = AppLocalizations.of(context).translate('Invalid email address');
            break;
          case 'too-many-requests':
            _errorMessage = AppLocalizations.of(context).translate('Too many attempts. Try again later');
            break;
          case 'email-required':
            _errorMessage = AppLocalizations.of(context).translate('Email is required');
            break;
          case 'password-required':
            _errorMessage = AppLocalizations.of(context).translate('Password is required');
            break;
          default:
            _errorMessage = AppLocalizations.of(context).translate('Invalid information');
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
