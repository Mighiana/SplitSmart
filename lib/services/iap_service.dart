import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'entitlement.dart';

/// Drives Google Play Billing / Apple StoreKit purchases for SplitSmart
/// Premium and verifies them SERVER-SIDE via the `verifyPurchase` Cloud
/// Function. The client never grants entitlement itself.
///
/// Product rule: Premium unlocks the guest-join feature for groups the buyer
/// owns. Buyer = group owner.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  /// Store product IDs (must match Play Console / App Store Connect).
  static const String monthlyId = 'splitsmart_premium_monthly';
  static const String yearlyId = 'splitsmart_premium_yearly';
  static const Set<String> _productIds = {monthlyId, yearlyId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool _available = false;
  bool get isStoreAvailable => _available;

  List<ProductDetails> _products = const [];
  List<ProductDetails> get products => _products;

  /// Emits a verified entitlement after the Cloud Function confirms a purchase.
  final StreamController<Entitlement> _entitlementController =
      StreamController<Entitlement>.broadcast();
  Stream<Entitlement> get onEntitlement => _entitlementController.stream;

  /// Emits a human-readable error for the paywall to display.
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  Stream<String> get onError => _errorController.stream;

  bool _initialized = false;

  /// Initialise the store connection and start listening for purchase updates.
  /// Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint('[IAP] Store not available on this device.');
      return;
    }

    // Listen to the purchase stream (covers buy, restore, and pending flows).
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) {
        debugPrint('[IAP] purchaseStream error: $e');
        _errorController.add('A store error occurred. Please try again.');
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final resp = await _iap.queryProductDetails(_productIds);
      if (resp.error != null) {
        debugPrint('[IAP] queryProductDetails error: ${resp.error}');
      }
      _products = resp.productDetails;
      if (resp.notFoundIDs.isNotEmpty) {
        debugPrint('[IAP] Product IDs not found: ${resp.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('[IAP] _loadProducts failed: $e');
    }
  }

  /// Start a subscription purchase. Returns false if the product is unknown
  /// or the store is unavailable.
  Future<bool> buy(String productId) async {
    if (!_available) {
      _errorController.add('In-app purchases are unavailable on this device.');
      return false;
    }
    ProductDetails? product;
    for (final p in _products) {
      if (p.id == productId) {
        product = p;
        break;
      }
    }
    if (product == null) {
      _errorController.add('This plan is not available right now.');
      return false;
    }
    final param = PurchaseParam(productDetails: product);
    try {
      // Subscriptions use buyNonConsumable in the in_app_purchase API.
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      debugPrint('[IAP] buy failed: $e');
      _errorController.add('Could not start the purchase. Please try again.');
      return false;
    }
  }

  /// Restore previously-purchased subscriptions (required by Apple).
  Future<void> restore() async {
    if (!_available) {
      _errorController.add('In-app purchases are unavailable on this device.');
      return;
    }
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[IAP] restore failed: $e');
      _errorController.add('Could not restore purchases. Please try again.');
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          // UI can show a spinner; nothing to do yet.
          break;
        case PurchaseStatus.error:
          debugPrint('[IAP] purchase error: ${p.error}');
          _errorController.add('Purchase failed. You were not charged.');
          break;
        case PurchaseStatus.canceled:
          debugPrint('[IAP] purchase canceled');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(p);
          break;
      }
      // Always acknowledge/complete or the store will refund after 3 days.
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (e) {
          debugPrint('[IAP] completePurchase failed: $e');
        }
      }
    }
  }

  /// Send the receipt to the Cloud Function for server-side validation.
  Future<void> _verify(PurchaseDetails p) async {
    final store = defaultTargetPlatform == TargetPlatform.iOS
        ? 'appstore'
        : 'play';
    final token = p.verificationData.serverVerificationData;
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyPurchase');
      final result = await callable.call<Map<String, dynamic>>({
        'store': store,
        'productId': p.productID,
        'token': token,
      });
      final data = Map<String, dynamic>.from(result.data);
      if (data['valid'] == true) {
        final ent = Entitlement.fromMap(
          Map<String, dynamic>.from(data['entitlement'] as Map? ?? {}),
        );
        _entitlementController.add(ent);
      } else {
        _errorController.add('We could not verify your purchase.');
      }
    } catch (e) {
      debugPrint('[IAP] verifyPurchase call failed: $e');
      // The store will redeliver this purchase on next launch, and the
      // App Store / Play webhook will reconcile entitlement server-side,
      // so we surface a soft message rather than failing hard.
      _errorController.add(
        'Purchase received — finishing setup. This can take a moment.',
      );
    }
  }

  void dispose() {
    _sub?.cancel();
    _entitlementController.close();
    _errorController.close();
  }
}
