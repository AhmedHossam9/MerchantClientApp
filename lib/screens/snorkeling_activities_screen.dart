import 'package:flutter/material.dart';
import '../widgets/service_app_bar.dart';

class SnorkelingActivitiesScreen extends StatelessWidget {
  const SnorkelingActivitiesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(
              titleKey: 'snorkeling_activities',
            ),
            const Expanded(
              child: Center(
                child: Text('Snorkeling Activities Coming Soon'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 