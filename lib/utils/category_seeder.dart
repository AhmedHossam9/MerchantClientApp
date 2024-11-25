import 'package:cloud_firestore/cloud_firestore.dart';

class CategorySeeder {
  static final List<Map<String, dynamic>> _defaultCategories = [
    {
      "name_en": "Electronics",
      "name_ar": "إلكترونيات",
      "order": 1
    },
    {
      "name_en": "Fashion",
      "name_ar": "أزياء",
      "order": 2
    },
    {
      "name_en": "Home & Living",
      "name_ar": "المنزل والمعيشة",
      "order": 3
    },
    {
      "name_en": "Beauty & Personal Care",
      "name_ar": "الجمال والعناية الشخصية",
      "order": 4
    },
    {
      "name_en": "Sports & Outdoors",
      "name_ar": "الرياضة والأنشطة الخارجية",
      "order": 5
    },
    {
      "name_en": "Toys & Games",
      "name_ar": "الألعاب",
      "order": 6
    },
    {
      "name_en": "Books & Stationery",
      "name_ar": "الكتب والقرطاسية",
      "order": 7
    },
    {
      "name_en": "Automotive",
      "name_ar": "السيارات",
      "order": 8
    },
    {
      "name_en": "Pet Supplies",
      "name_ar": "مستلزمات الحيوانات الأليفة",
      "order": 9
    },
    {
      "name_en": "Food & Beverages",
      "name_ar": "الطعام والمشروبات",
      "order": 10
    }
  ];

  static Future<void> seedCategories() async {
    try {
      // Delete existing categories first
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .get();
      
      final batch = FirebaseFirestore.instance.batch();
      
      // Delete existing categories
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Add new categories
      for (final category in _defaultCategories) {
        final docRef = FirebaseFirestore.instance
            .collection('categories')
            .doc();
        batch.set(docRef, {
          ...category,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
      print('Categories reseeded successfully');
    } catch (e) {
      print('Error seeding categories: $e');
    }
  }
}