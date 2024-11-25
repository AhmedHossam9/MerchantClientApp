import 'package:flutter/material.dart';
import '../widgets/service_app_bar.dart';

class SafariActivitiesScreen extends StatelessWidget {
  const SafariActivitiesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(
              titleKey: 'safari_activities',
            ),
            const Expanded(
              child: Center(
                child: Text('Safari Activities Coming Soon'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 