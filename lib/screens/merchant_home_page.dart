import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore
import '../utils/app_localizations.dart';
import '../widgets/custom_app_bar.dart';

class MerchantHomePage extends StatefulWidget {
  @override
  _MerchantHomePageState createState() => _MerchantHomePageState();
}

class _MerchantHomePageState extends State<MerchantHomePage> {
  String username = "Loading..."; // Default value while fetching
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
  }

  // Fetch the username from Firestore
  Future<void> _fetchUsername() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users') // Ensure your users collection is named 'users'
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            username = userDoc['username'] ?? 'Guest'; // Fetch username
            isLoading = false;
          });
        }
      } catch (e) {
        setState(() {
          username = 'Error fetching username';
          isLoading = false;
        });
        print('Error fetching username: $e');
      }
    }
  }

  void _changeLanguage(Locale locale) {
    // Logic to update app's locale
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        setLocale: _changeLanguage,
        username: username, // Pass the fetched username
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading indicator
          : Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey[200],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildImageButton(
                    context,
                    imagePath: 'assets/addbutton.png',
                    label: AppLocalizations.of(context).translate('add_items'),
                    onPressed: () {
                      // Navigate to Add Items page
                    },
                  ),
                  SizedBox(height: 20),
                  _buildImageButton(
                    context,
                    imagePath: 'assets/viewbutton.png',
                    label: AppLocalizations.of(context).translate('view_items'),
                    onPressed: () {
                      // Navigate to View Items page
                    },
                  ),
                  SizedBox(height: 20),
                  _buildImageButton(
                    context,
                    imagePath: 'assets/orderbutton.png',
                    label: AppLocalizations.of(context).translate('view_orders'),
                    onPressed: () {
                      // Navigate to View Orders page
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildImageButton(
    BuildContext context, {
    required String imagePath,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 160, // Fixed width for the button
        height: 160, // Fixed height for the button
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15), // Rounded corners
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 3,
              blurRadius: 7,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15), // Rounded corners
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image with fixed size
              Container(
                width: 130, // Fixed size for the image
                height: 130, // Fixed size for the image
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover, // Make sure the image covers the box area
                ),
              ),
              SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
