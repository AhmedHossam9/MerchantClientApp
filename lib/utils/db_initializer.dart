import 'package:cloud_firestore/cloud_firestore.dart';

class DbInitializer {
  static Future<void> initializeEvents() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final CollectionReference events = firestore.collection('events');

    // Check if collection is empty
    final QuerySnapshot snapshot = await events.limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      print('Events collection already initialized');
      return;
    }

    // Sample events data
    final List<Map<String, dynamic>> sampleEvents = [
      {
        'name': 'Sharm El Sheikh International Theater Festival',
        'description': 'Annual international theater festival featuring performances from around the world',
        'price': 150.00,
        'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'location': 'Sharm El Sheikh Cultural Center',
        'availableSeats': 200,
        'imageUrl': '',
      },
      {
        'name': 'Red Sea Film Festival',
        'description': 'Celebrating the best in international and regional cinema',
        'price': 200.00,
        'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 45))),
        'location': 'Sharm El Sheikh Conference Hall',
        'availableSeats': 300,
        'imageUrl': '',
      },
      {
        'name': 'Sharm Music Festival',
        'description': 'A night of classical and contemporary music performances',
        'price': 175.00,
        'date': Timestamp.fromDate(DateTime.now().add(const Duration(days: 60))),
        'location': 'Sharm El Sheikh Amphitheater',
        'availableSeats': 250,
        'imageUrl': '',
      },
    ];

    // Add events to Firestore
    try {
      for (final eventData in sampleEvents) {
        await events.add(eventData);
      }
      print('Events collection initialized successfully');
    } catch (e) {
      print('Error initializing events: $e');
    }
  }
}