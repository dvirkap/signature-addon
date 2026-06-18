import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'main.dart'; // To access AppSettings and getStr/appLanguage if needed

class IapService {
  static final IapService instance = IapService._internal();

  IapService._internal();

  static const String proProductId = 'just_sign_pro_upgrade';
  
  final ValueNotifier<bool> isPro = ValueNotifier<bool>(false);
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;

  // Initialize IAP and load cached state
  Future<void> initialize() async {
    // 1. Load offline cached state from AppSettings
    final settings = await AppSettings.readSettings();
    isPro.value = settings['is_pro'] == true;
    debugPrint('IAP: Loaded cached Pro status: ${isPro.value}');

    // 2. Initialize in-app purchase stream
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        InAppPurchase.instance.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription?.cancel();
    }, onError: (error) {
      debugPrint('IAP stream error: $error');
    });

    // 3. Check if billing store is available
    try {
      _isAvailable = await InAppPurchase.instance.isAvailable();
      debugPrint('IAP: Store is available: $_isAvailable');
      if (_isAvailable) {
        // Run a silent purchase restoration check on startup to sync state if online
        await restorePurchases(silent: true);
      }
    } catch (e) {
      debugPrint('IAP availability check failed: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }

  // Handle stream updates
  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Purchase is pending
        debugPrint('IAP: Purchase is pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('IAP Error: ${purchaseDetails.error}');
          _handlePurchaseError(purchaseDetails.error);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('IAP: Purchase/Restore success! Product: ${purchaseDetails.productID}');
          if (purchaseDetails.productID == proProductId) {
            await _unlockPro();
          }
        }
        
        // Complete purchase to verify delivery
        if (purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _unlockPro() async {
    isPro.value = true;
    await AppSettings.writeSetting('is_pro', true);
    debugPrint('IAP: Pro status unlocked and cached.');
  }

  void _handlePurchaseError(IAPError? error) {
    // We can handle purchase failures silently or dispatch error logs.
    // Toast / Dialog alert is triggered in the buying view if needed.
  }

  // Trigger Purchase Flow
  Future<bool> buyPro() async {
    if (!_isAvailable) {
      _isAvailable = await InAppPurchase.instance.isAvailable();
    }
    if (!_isAvailable) {
      debugPrint('IAP: Billing service is not available.');
      return false;
    }

    try {
      // Query product details
      final ProductDetailsResponse response =
          await InAppPurchase.instance.queryProductDetails({proProductId});
      
      if (response.notFoundIDs.contains(proProductId) || response.productDetails.isEmpty) {
        debugPrint('IAP: Product $proProductId not found in store.');
        return false;
      }

      final ProductDetails productDetails = response.productDetails.first;
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      
      // Buy product
      return await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('IAP purchase error: $e');
      return false;
    }
  }

  // Restore Purchases Flow
  Future<bool> restorePurchases({bool silent = false}) async {
    try {
      if (!_isAvailable) {
        _isAvailable = await InAppPurchase.instance.isAvailable();
      }
      if (!_isAvailable) return false;

      await InAppPurchase.instance.restorePurchases();
      return true;
    } catch (e) {
      debugPrint('IAP restoration error: $e');
      return false;
    }
  }
}
