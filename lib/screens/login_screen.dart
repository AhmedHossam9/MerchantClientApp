import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import '../utils/app_localizations.dart';
import '../widgets/slideshow_background.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  final Function(Locale) onLanguageChange;

  const LoginScreen({required this.onLanguageChange});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _loginIdentifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.14159)
        .animate(_animationController);
  }

  @override
  void dispose() {
    _loginIdentifierController.dispose();
    _passwordController.dispose();
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
          AppLocalizations.of(context).translate('login'),
          style: TextStyle(
            fontWeight: FontWeight.w600,
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
            child: SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
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
                      SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          maxWidth: 400,
                        ),
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF1E1E1E).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTextField(
                              controller: _loginIdentifierController,
                              labelText: AppLocalizations.of(context).translate('email_username_phone'),
                              icon: Icons.person_outline_rounded,
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              labelText: AppLocalizations.of(context).translate('password'),
                              icon: Icons.lock_rounded,
                              obscureText: true,
                            ),
                            SizedBox(height: 16),
                            if (_errorMessage.isNotEmpty) ...[
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 16),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.login_rounded, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            AppLocalizations.of(context).translate('login'),
                                            style: TextStyle(
                                              fontSize: 15,
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
                                  AppLocalizations.of(context).translate('dont_have_account'),
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 4),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => Navigator.pushNamed(context, '/register'),
                                    child: Text(
                                      AppLocalizations.of(context).translate('register_now'),
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.blue[300] : Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
    required String labelText,
    required IconData icon,
    bool obscureText = false,
  }) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black54,
          fontSize: 14
        ),
        prefixIcon: Icon(
          icon, 
          color: isDarkMode ? Colors.white70 : Theme.of(context).primaryColor,
          size: 20
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
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
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white : Theme.of(context).primaryColor,
            width: 1.5
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    _animationController.repeat();

    try {
      final String identifier = _loginIdentifierController.text.trim();
      final String password = _passwordController.text.trim();
      
      print('Login attempt with identifier: $identifier'); // Debug log
      
      // Validate inputs
      if (identifier.isEmpty) {
        throw FirebaseAuthException(code: 'identifier-required');
      }
      if (password.isEmpty) {
        throw FirebaseAuthException(code: 'password-required');
      }

      String? email;
      String? foundIdentifier;

      // First try email directly
      if (identifier.contains('@')) {
        email = identifier;
        foundIdentifier = 'email';
      } else {
        // Try to find user by username
        print('Searching for username: $identifier'); // Debug log
        final usernameQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: identifier)
            .get();

        if (usernameQuery.docs.isNotEmpty) {
          email = usernameQuery.docs.first.get('email') as String;
          foundIdentifier = 'username';
          print('Found user by username, email: $email'); // Debug log
        } else {
          // Try to find user by phone
          print('Searching for phone: $identifier'); // Debug log
          final phoneQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('phone_number', isEqualTo: identifier)
              .get();

          if (phoneQuery.docs.isNotEmpty) {
            email = phoneQuery.docs.first.get('email') as String;
            foundIdentifier = 'phone';
            print('Found user by phone, email: $email'); // Debug log
          }
        }
      }

      if (email == null) {
        print('No user found with identifier: $identifier'); // Debug log
        throw FirebaseAuthException(code: 'user-not-found');
      }

      print('Attempting login with email: $email'); // Debug log

      // Attempt to sign in with email
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print('Login successful for user: ${userCredential.user?.uid}'); // Debug log

      if (userCredential.user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
        
        if (!mounted) return;

        if (userDoc.exists) {
          final accountType = userDoc.data()?['account_type'] as String?;
          print('Account type: $accountType'); // Debug log
          
          await _animationController.forward();

          if (!mounted) return;

          if (accountType == 'Client') {
            Navigator.pushReplacementNamed(context, '/services_home_page');
          } else if (accountType == 'Merchant') {
            Navigator.pushReplacementNamed(context, '/merchant_home_page');
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}'); // Debug log
      _animationController.stop();
      _animationController.reset();
      
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _errorMessage = AppLocalizations.of(context).translate('user_not_found');
            break;
          case 'wrong-password':
            _errorMessage = AppLocalizations.of(context).translate('incorrect_password');
            break;
          case 'invalid-email':
            _errorMessage = AppLocalizations.of(context).translate('invalid_login_identifier');
            break;
          case 'identifier-required':
            _errorMessage = AppLocalizations.of(context).translate('login_identifier_required');
            break;
          case 'password-required':
            _errorMessage = AppLocalizations.of(context).translate('password_required');
            break;
          default:
            _errorMessage = '${AppLocalizations.of(context).translate('invalid_information')} (${e.code})';
        }
      });
    } catch (e) {
      print('General error: $e'); // Debug log
      _animationController.stop();
      _animationController.reset();
      
      setState(() {
        _errorMessage = AppLocalizations.of(context).translate('invalid_information');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
