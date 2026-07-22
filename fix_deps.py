import re

def main():
    # 1. Update super_admin_screen.dart: allRestaurants -> restaurants
    with open('lib/super_admin_screen.dart', 'r', encoding='utf-8') as f:
        super_content = f.read()
    
    super_content = super_content.replace('controller.allRestaurants', 'controller.restaurants')
    
    with open('lib/super_admin_screen.dart', 'w', encoding='utf-8', newline='\n') as f:
        f.write(super_content)
        
    print("Fixed super_admin_screen.dart")

    # 2. Update main.dart: add fields and methods
    with open('lib/main.dart', 'r', encoding='utf-8') as f:
        main_content = f.read()
        
    # --- Update Restaurant ---
    rest_old = """class Restaurant {
  final String id;
  final String name;
  final String location;
  final String cuisine;
  final double rating;
  final String deliveryTime;
  final String imageUrl;
  final String description;
  final String whatsappNumber;

  Restaurant({
    required this.id,
    required this.name,
    required this.location,
    required this.cuisine,
    required this.rating,
    required this.deliveryTime,
    required this.imageUrl,
    required this.description,
    required this.whatsappNumber,
  });
}"""

    rest_new = """class Restaurant {
  final String id;
  final String name;
  final String location;
  final String cuisine;
  final double rating;
  final String deliveryTime;
  final String imageUrl;
  final String description;
  final String whatsappNumber;
  
  bool isActive;
  double deliveryFee;
  String ownerPhone;
  String ownerPassword;

  Restaurant({
    required this.id,
    required this.name,
    required this.location,
    required this.cuisine,
    required this.rating,
    required this.deliveryTime,
    required this.imageUrl,
    required this.description,
    required this.whatsappNumber,
    this.isActive = true,
    this.deliveryFee = 1500,
    this.ownerPhone = '',
    this.ownerPassword = '',
  });
}"""
    main_content = main_content.replace(rest_old, rest_new)
    
    # --- Update Product ---
    prod_old = """class Product {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String categoryId;
  bool isAvailable;

  Product({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    this.isAvailable = true,
  });
}"""

    prod_new = """class Product {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String categoryId;
  bool isAvailable;
  double? discountPrice;

  Product({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    this.isAvailable = true,
    this.discountPrice,
  });
}"""
    main_content = main_content.replace(prod_old, prod_new)

    # --- Add methods to JeebliController ---
    methods = """
  // ----- طرق الإدارة (Super Admin & Owner) -----
  void toggleRestaurantActive(String id) {
    final idx = _restaurants.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _restaurants[idx].isActive = !_restaurants[idx].isActive;
      notifyListeners();
    }
  }

  void addRestaurant(Restaurant restaurant) {
    _restaurants.add(restaurant);
    notifyListeners();
  }

  void deleteRestaurant(String id) {
    _restaurants.removeWhere((r) => r.id == id);
    _products.removeWhere((p) => p.restaurantId == id);
    notifyListeners();
  }

  void updateDeliveryFee(String id, double fee) {
    final idx = _restaurants.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _restaurants[idx].deliveryFee = fee;
      notifyListeners();
    }
  }

  void addProduct(Product product) {
    _products.add(product);
    notifyListeners();
  }

  void updateProduct(Product product) {
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      _products[idx] = product;
      notifyListeners();
    }
  }

  void deleteProduct(String id) {
    _products.removeWhere((p) => p.id == id);
    notifyListeners();
  }
"""
    # Insert methods just before "List<Restaurant> get restaurants => _restaurants;"
    insertion_point = "List<Restaurant> get restaurants => _restaurants;"
    main_content = main_content.replace(insertion_point, methods + "\n  " + insertion_point)

    with open('lib/main.dart', 'w', encoding='utf-8', newline='\n') as f:
        f.write(main_content)
        
    print("Fixed main.dart")

if __name__ == '__main__':
    main()
