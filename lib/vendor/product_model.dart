/// نموذج البيانات الخاص بالمنتج (ProductModel) الذي يمثل الوجبة في لوحة تحكم التاجر.
class ProductModel {
  final String id;          // المعرف الفريد للمنتج
  final String name;        // اسم الوجبة
  final String description; // وصف الوجبة أو المكونات
  final double price;       // السعر بالدينار العراقي
  final String imageUrl;    // رابط صورة الوجبة

  ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  /// دالة (copyWith) تتيح إنشاء نسخة جديدة من المنتج مع تعديل بعض الخصائص (مثل السعر أو الاسم) 
  /// دون الحاجة لإعادة كتابة كامل البيانات.
  ProductModel copyWith({
    String? name,
    String? description,
    double? price,
    String? imageUrl,
  }) {
    return ProductModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}