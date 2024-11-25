import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  final Function(Locale) setLocale;

  const SplashScreen({Key? key, required this.setLocale}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(Duration(seconds: 1)); // Brief delay for splash screen
    
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      // Only go to welcome screen if no user is logged in
      Navigator.pushReplacementNamed(context, '/welcome');
      return;
    }

    // User is logged in, go directly to appropriate home screen
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (userDoc.exists) {
        final accountType = userDoc.data()?['account_type'];
        
        if (accountType == 'Merchant') {
          Navigator.pushReplacementNamed(context, '/merchant_home_page');
        } else if (accountType == 'Client') {
          Navigator.pushReplacementNamed(context, '/services_home_page');
        }
      }
    } catch (e) {
      print("Error checking user state: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
} 