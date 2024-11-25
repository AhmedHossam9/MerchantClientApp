class Museum {
  final String id;
  final String name;
  final double price;
  final String? description;

  Museum({
    required this.id,
    required this.name,
    required this.price,
    this.description,
  });

  factory Museum.fromMap(String id, Map<String, dynamic> data) {
    return Museum(
      id: id,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      description: data['description'],
    );
  }
}