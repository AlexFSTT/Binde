import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';

/// Provider pentru coșul de cumpărături (folosind Notifier modern)
final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(() {
  return CartNotifier();
});

/// Notifier care gestionează starea coșului
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    // Starea inițială - coș gol
    return [];
  }

  /// Adaugă un produs în coș
  void addToCart(Product product) {
    // Verifică dacă produsul există deja în coș
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);

    if (existingIndex != -1) {
      // Produsul există - mărește cantitatea
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            CartItem(product: state[i].product, quantity: state[i].quantity + 1)
          else
            state[i],
      ];
    } else {
      // Produs nou - adaugă în coș
      state = [...state, CartItem(product: product)];
    }
  }

  /// Elimină un produs din coș complet
  void removeFromCart(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  /// Mărește cantitatea unui produs
  void increaseQuantity(String productId) {
    state = [
      for (final item in state)
        if (item.product.id == productId)
          CartItem(product: item.product, quantity: item.quantity + 1)
        else
          item,
    ];
  }

  /// Micșorează cantitatea unui produs
  void decreaseQuantity(String productId) {
    state = [
      for (final item in state)
        if (item.product.id == productId)
          if (item.quantity > 1)
            CartItem(product: item.product, quantity: item.quantity - 1)
          else
            item // Nu scade sub 1
        else
          item,
    ];
  }

  /// Setează cantitatea exactă
  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }

    state = [
      for (final item in state)
        if (item.product.id == productId)
          CartItem(product: item.product, quantity: quantity)
        else
          item,
    ];
  }

  /// Golește coșul
  void clearCart() {
    state = [];
  }

  /// Calculează totalul coșului
  double get totalPrice {
    return state.fold(0, (sum, item) => sum + item.totalPrice);
  }

  /// Numărul total de produse în coș
  int get itemCount {
    return state.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Verifică dacă un produs e în coș
  bool isInCart(String productId) {
    return state.any((item) => item.product.id == productId);
  }

  /// Obține cantitatea unui produs din coș
  int getQuantity(String productId) {
    final item = state.where((item) => item.product.id == productId).firstOrNull;
    return item?.quantity ?? 0;
  }

  void updateQuantity(String id, int i) {}
}

/// Provider pentru totalul coșului (formatat)
final cartTotalProvider = Provider<String>((ref) {
  final cart = ref.watch(cartProvider);
  final total = cart.fold(0.0, (sum, item) => sum + item.totalPrice);
  return '${total.toStringAsFixed(2)} RON';
});

/// Provider pentru numărul de items din coș
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});