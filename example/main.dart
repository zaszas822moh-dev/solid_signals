import 'package:flutter/material.dart';
import 'package:reactive_signals/reactive_flutter.dart';

// ==========================================
// 1. Core Models and State
// ==========================================

class Product {
  final String id;
  final String name;
  final double price;
  final String description;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
  });
}

// Global catalog of products
const mockProducts = [
  Product(id: '1', name: 'Elite Noise-Cancelling Headphones', price: 299.99, description: 'Experience pure audio bliss with active hybrid noise cancellation.'),
  Product(id: '2', name: 'Ultra-Sharp Mechanical Keyboard', price: 149.99, description: 'Tactile blue switches with vibrant per-key RGB backlighting.'),
  Product(id: '3', name: 'Ergonomic Vertical Mouse', price: 79.99, description: 'Designed to reduce muscle strain and improve wrist alignment.'),
];

// Signals & Computeds
final cart = Signal<List<Product>>([]);
final cartTotal = Computed(() => cart.value.fold<double>(0.0, (sum, item) => sum + item.price));

// Active selected product ID for details screen
final selectedProductId = Signal<String?>(null);

// Signal Family: Fetches detailed reviews / extra details for a product asynchronously
final productDetailFamily = AsyncSignalFamily<String, String>(
  (productId) => AsyncSignal.fromFuture(
    () async {
      print("FAMILY API: Fetching mock reviews for product $productId...");
      await Future.delayed(const Duration(seconds: 1)); // Simulating api latency
      final product = mockProducts.firstWhere((p) => p.id == productId);
      return "Highly rated! Customers say: \"Amazing build quality and excellent value. The ${product.name} exceeded my expectations!\"";
    },
    autoDispose: true, // Dispose and clear cache when modal sheet closes!
  ),
);

// ==========================================
// 2. Central Monitoring via SignalObserver
// ==========================================

class ConsoleSignalObserver extends SignalObserver {
  @override
  void onSignalCreated(Signal signal) {
    print("[Observer] Signal Created: ${signal.runtimeType} (initial: ${signal.value})");
  }

  @override
  void onSignalChanged(Signal signal, Object? oldValue, Object? newValue) {
    print("[Observer] Signal Changed: ${signal.runtimeType} | $oldValue -> $newValue");
  }

  @override
  void onSignalDisposed(Signal signal) {
    print("[Observer] Signal Disposed: ${signal.runtimeType} (final: ${signal.value})");
  }
}

// ==========================================
// 3. Application Entrypoint
// ==========================================

void main() {
  // Register the observer
  signalObserver = ConsoleSignalObserver();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signals Enterprise Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0E17),
        cardColor: const Color(0xFF1E1C2A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7F5AF0),
          secondary: Color(0xFF2CB67D),
          surface: Color(0xFF1E1C2A),
        ),
      ),
      home: const CatalogScreen(),
    );
  }
}

// ==========================================
// 4. Catalog Screen Widget
// ==========================================

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solid Signals Store', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          _buildCartButton(context),
        ],
      ),
      // SignalListener tracks cart updates to trigger side effects (Snackbars) without rebuild
      body: SignalListener<int>(
        select: () => cart.value.length,
        listener: (itemCount) {
          if (itemCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added to cart! Total items: $itemCount'),
                backgroundColor: const Color(0xFF2CB67D),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(20.0),
          children: [
            _buildPromoBanner(context),
            const SizedBox(height: 24),
            const Text('Available Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...mockProducts.map((p) => _buildProductCard(context, p)),
          ],
        ),
      ),
    );
  }

  Widget _buildCartButton(BuildContext context) {
    // Rebuild surgically only the badge using Observe
    return Observe(
      builder: (context) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () => _showCartDialog(context),
            ),
            if (cart.value.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFFEF4565), shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '${cart.value.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPromoBanner(BuildContext context) {
    // Demonstration of SignalScope: Overriding selectedProductId in this subtree
    final promotionalProduct = mockProducts[0]; // Elite Headphones
    final localSelectedProduct = Signal<String?>(null);

    return SignalScope(
      overrides: {
        selectedProductId: localSelectedProduct,
      },
      child: Builder(
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7F5AF0), Color(0xFF2CB67D)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WEEKEND SPECIAL PROMO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white70)),
                      SizedBox(height: 4),
                      Text('Get 20% off on premium audio products!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // This sets the scoped override signal instead of the global selectedProductId
                    localSelectedProduct.value = promotionalProduct.id;
                    _showProductDetails(context, promotionalProduct);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('View Deal'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF2CB67D), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(product.description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    selectedProductId.value = product.id; // Sets global selectedProductId
                    _showProductDetails(context, product);
                  },
                  child: const Text('Learn More'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => cart.value = [...cart.value, product],
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Add to Cart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetails(BuildContext context, Product product) {
    // Retrieve the active selected ID from scope.
    // In the promo banner subtree, it resolves to localSelectedProduct, otherwise to the global selectedProductId.
    final activeIdSignal = SignalScope.get(context, selectedProductId);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1C2A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // Resolve the async signal from the family based on the active ID
        final detailsSignal = productDetailFamily(activeIdSignal.value!);

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('\$${product.price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF2CB67D), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Product Overview', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(product.description),
              const SizedBox(height: 20),
              const Text('Featured Review (Loaded Lazily)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              // Render loading / data / error for the AsyncSignalFamily
              Observe(
                builder: (context) {
                  return detailsSignal.when(
                    data: (review) => Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        review,
                        style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, st) => Text('Failed to load review: $err', style: const TextStyle(color: Colors.red)),
                  );
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // Clear selection when sheet is closed
      activeIdSignal.value = null;
    });
  }

  void _showCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1C2A),
          title: const Text('Shopping Cart'),
          content: SizedBox(
            width: double.maxFinite,
            child: Observe(
              builder: (context) {
                if (cart.value.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Text('Your cart is empty.', style: TextStyle(color: Colors.grey)),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...cart.value.map((item) => ListTile(
                          title: Text(item.name),
                          trailing: Text('\$${item.price.toStringAsFixed(2)}'),
                        )),
                    const Divider(),
                    ListTile(
                      title: const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text(
                        '\$${cartTotal.value.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2CB67D)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cart.value = [];
                Navigator.pop(context);
              },
              child: const Text('Clear Cart', style: TextStyle(color: Color(0xFFEF4565))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Checkout'),
            ),
          ],
        );
      },
    );
  }
}
