import 'package:cloud_firestore/cloud_firestore.dart';

class Event {
  final String id;
  final String name;
  final String? description;
  final double price;
  final DateTime date;
  final String location;
  final int availableSeats;
  final String imageUrl;

  Event({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.date,
    required this.location,
    required this.availableSeats,
    required this.imageUrl,
  });

  factory Event.fromMap(String id, Map<String, dynamic> data) {
    return Event(
      id: id,
      name: data['name'] ?? '',
      description: data['description'],
      price: (data['price'] ?? 0.0).toDouble(),
      date: (data['date'] as Timestamp).toDate(),
      location: data['location'] ?? '',
      availableSeats: data['availableSeats'] ?? 0,
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}