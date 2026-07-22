import 'package:flutter/material.dart';
import 'product_model.dart';

class VendorDashboardView extends StatefulWidget {
  const VendorDashboardView({super.key});

  @override
  State<VendorDashboardView> createState() => _VendorDashboardViewState();
}

class _VendorDashboardViewState extends State<VendorDashboardView> {
  final String restaurantName = "مطعم أبو العبد";
  final String phoneNumber = "07800108275";

  List<ProductModel> products = [
    ProductModel(
      id: "1",
      name: "كباب عراقي",
      description: "كباب لحم غنم طازج مع الخبز الحار",
      price: 12000,
      imageUrl: "https://images.unsplash.com/photo-1561651823-34fed0225408",
    ),
  ];

  void _showProductDialog({ProductModel? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final descController = TextEditingController(text: product?.description ?? '');
    final priceController = TextEditingController(
        text: product?.price != null ? product!.price.toString() : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product == null ? "إضافة وجبة جديدة" : "تعديل الوجبة"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "اسم الوجبة"),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "الوصف"),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "السعر (د.ع)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              final double? enteredPrice = double.tryParse(priceController.text);
              if (nameController.text.isEmpty || enteredPrice == null) return;

              setState(() {
                if (product == null) {
                  products.add(ProductModel(
                    id: DateTime.now().toString(),
                    name: nameController.text,
                    description: descController.text,
                    price: enteredPrice,
                    imageUrl: "https://images.unsplash.com/photo-1561651823-34fed0225408",
                  ));
                } else {
                  int index = products.indexWhere((p) => p.id == product.id);
                  if (index != -1) {
                    products[index] = product.copyWith(
                      name: nameController.text,
                      description: descController.text,
                      price: enteredPrice,
                    );
                  }
                }
              });
              Navigator.pop(context);
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(restaurantName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("هاتف: $phoneNumber", style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
      body: products.isEmpty
          ? const Center(child: Text("لا توجد وجبات حالياً"))
          : ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: const Icon(Icons.fastfood, size: 40),
                    title: Text(product.name),
                    subtitle: Text("${product.description}\nالسعر: ${product.price.toInt()} د.ع"),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showProductDialog(product: product),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              products.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}