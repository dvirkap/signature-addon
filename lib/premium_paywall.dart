import 'package:flutter/material.dart';
import 'iap_service.dart';
import 'main.dart'; // To access appLanguage, getStr, and settings

class PremiumPaywall extends StatefulWidget {
  const PremiumPaywall({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumPaywall(),
    );
  }

  @override
  State<PremiumPaywall> createState() => _PremiumPaywallState();
}

class _PremiumPaywallState extends State<PremiumPaywall> {
  bool _isPurchasing = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    // Listen to changes in Pro status to dismiss paywall automatically if purchase finishes
    IapService.instance.isPro.addListener(_onProStatusChanged);
  }

  @override
  void dispose() {
    IapService.instance.isPro.removeListener(_onProStatusChanged);
    super.dispose();
  }

  void _onProStatusChanged() {
    if (IapService.instance.isPro.value && mounted) {
      Navigator.pop(context); // Close paywall
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getStr('purchase_success')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleBuy() async {
    setState(() => _isPurchasing = true);
    final success = await IapService.instance.buyPro();
    if (!success && mounted) {
      setState(() => _isPurchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(getStr('purchase_failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);
    final success = await IapService.instance.restorePurchases();
    if (mounted) {
      setState(() => _isRestoring = false);
      if (success) {
        // Wait a bit to let stream handle restored items, else show feedback
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !IapService.instance.isPro.value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(getStr('restore_failed'))),
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(getStr('purchase_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = appLanguage.value == 'he';
    
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A), // Premium Dark Slate background
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Header / Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF38BDF8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              getStr('pro_feature_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              getStr('pro_feature_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF1E293B)),
            const SizedBox(height: 16),
            // Benefit Checkmarks
            _buildBenefitItem(Icons.pages_outlined, isRtl ? 'עריכת דפי מסมך (סיבוב, מחיקה)' : 'Edit PDF pages (Rotate, delete)'),
            _buildBenefitItem(Icons.drag_indicator, isRtl ? 'שינוי סדר דפים בקלות' : 'Reorder pages easily'),
            _buildBenefitItem(Icons.note_add_outlined, isRtl ? 'הוספת דפים ריקים לכל מקום במסמך' : 'Insert blank pages anywhere'),
            _buildBenefitItem(Icons.camera_enhance_outlined, isRtl ? 'סריקת דפים מהמצלמה עם פילטרים מיוחדים' : 'Scan pages with B&W contrast filters'),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF1E293B)),
            const SizedBox(height: 24),
            // Upgrade button
            ElevatedButton(
              onPressed: (_isPurchasing || _isRestoring) ? null : _handleBuy,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF4F46E5), // Indigo
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: _isPurchasing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      getStr('upgrade_to_pro'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 16),
            // Restore Purchases Link
            TextButton(
              onPressed: (_isPurchasing || _isRestoring) ? null : _handleRestore,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[400],
              ),
              child: _isRestoring
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 1.5),
                    )
                  : Text(
                      getStr('restore_purchases'),
                      style: const TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 20), // Sky blue accent
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
