import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/efinance.png', height: 150, width: 150),
            SizedBox(height: 40),
            ElevatedButton.icon(
              icon: Icon(Icons.login, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              label: Text('Login', style: TextStyle(color: Colors.white)),
            ),

            SizedBox(height: 20),

            ElevatedButton.icon(
              icon: Icon(Icons.app_registration, color: Colors.white),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              label: Text('Register', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
