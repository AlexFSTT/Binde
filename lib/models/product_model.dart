/// Model pentru un produs din Shop
class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String? category;
  final int stockQuantity;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.category,
    this.stockQuantity = 0,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creează un Product din JSON
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String?,
      stockQuantity: json['stock_quantity'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convertește Product în JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category': category,
      'stock_quantity': stockQuantity,
      'is_available': isAvailable,
    };
  }

  /// Returnează prețul formatat
  String get formattedPrice => '${price.toStringAsFixed(2)} RON';

  /// Verifică dacă produsul e în stoc
  bool get inStock => stockQuantity > 0;
}

/// Model pentru un item din coș
class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  /// Prețul total pentru acest item (preț × cantitate)
  double get totalPrice => product.price * quantity;

  /// Prețul total formatat
  String get formattedTotalPrice => '${totalPrice.toStringAsFixed(2)} RON';
}