import 'package:flutter/material.dart';
import '../widgets/service_app_bar.dart';

class NightlifeActivitiesScreen extends StatelessWidget {
  const NightlifeActivitiesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ServiceAppBar(
              titleKey: 'nightlife_activities',
            ),
            const Expanded(
              child: Center(
                child: Text('Nightlife Activities Coming Soon'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 