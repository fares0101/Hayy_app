import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/widgets/themed_top_header.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String bookingId;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.bookingId,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  // Guard: prevent double-navigation if both onNavigationRequest & onUrlChange fire
  bool _resultHandled = false;
  Timer? _sessionTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _isLoading = true);
            // Also check here: server-side 302 redirects bypass onNavigationRequest
            _checkPaymentResult(url);
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _checkPaymentResult(url);
          },
          onNavigationRequest: (request) {
            final url = request.url;
            // Intercept custom-scheme deep links — WebView cannot handle them
            if (url.startsWith('hayy://') || url.startsWith('hayyapp://')) {
              _checkPaymentResult(url);
              return NavigationDecision.prevent;
            }
            _checkPaymentResult(url);
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) {
            if (change.url != null) _checkPaymentResult(change.url!);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));

    _startSessionTimeout();
  }

  void _startSessionTimeout() {
    _sessionTimeoutTimer = Timer(const Duration(minutes: 2), () {
      if (!mounted || _resultHandled) return;

      _resultHandled = true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Payment session expired. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

      Navigator.of(context).pop(false);
    });
  }

  void _checkPaymentResult(String url) {
    if (_resultHandled) return;

    bool? success;

    // Pattern 1: deep link callback — hayy://payment-result?success=true&bookingId=...
    if (url.startsWith('hayy://payment-result') ||
        url.startsWith('hayyapp://payment-result')) {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      final hasSuccess = uri.queryParameters.keys.any((k) => k.toLowerCase() == 'success');
      if (hasSuccess) {
        final val = uri.queryParameters.entries
            .firstWhere((e) => e.key.toLowerCase() == 'success')
            .value;
        success = val.toLowerCase() == 'true';
      }
    }
    // Pattern 2: backend redirect URL — .../api/EventPayment/payment-result?success=...
    else if (url.contains('/api/EventPayment/payment-result')) {
      final uri = Uri.tryParse(url);
      if (uri == null) return;
      final hasSuccess = uri.queryParameters.keys.any((k) => k.toLowerCase() == 'success');
      if (hasSuccess) {
        final val = uri.queryParameters.entries
            .firstWhere((e) => e.key.toLowerCase() == 'success')
            .value;
        success = val.toLowerCase() == 'true';
      }
    }

    if (success == null) return; // URL is not a result page — ignore

    _resultHandled = true; // lock so the second event (if any) is ignored
    _sessionTimeoutTimer?.cancel();

    // Pop back to the caller with the payment result (true = success)
    Future.microtask(() {
      if (!mounted) return;
      Navigator.of(context).pop(success);
    });
  }

  @override
  void dispose() {
    _sessionTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Payment',
            showBackButton: true,
            trailing: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          // ─ Security badge ─
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: const Color(0xFFFFF8F5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.verified_user_rounded,
                    size: 15, color: Color(0xFFFE5D17)),
                SizedBox(width: 5),
                Text(
                  'Secured by Paymob • SSL encrypted',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A7A7A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ─ WebView ─
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  Container(
                    color: Colors.white,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PaymentLoadingIndicator(),
                          SizedBox(height: 20),
                          Text(
                            'Processing your payment..',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Please wait a moment',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9A9A9A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Animated Payment Loading Indicator ──────────────────────────────────────
class _PaymentLoadingIndicator extends StatefulWidget {
  const _PaymentLoadingIndicator();

  @override
  State<_PaymentLoadingIndicator> createState() =>
      _PaymentLoadingIndicatorState();
}

class _PaymentLoadingIndicatorState extends State<_PaymentLoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _rotateController;
  final List<AnimationController> _dotControllers = [];
  final List<Animation<double>> _dotAnimations = [];

  @override
  void initState() {
    super.initState();

    // Rotating card icon
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Orbiting dots (matching screenshot)
    for (int i = 0; i < 6; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      );
      _dotControllers.add(ctrl);
      _dotAnimations.add(Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      ));
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _rotateController.dispose();
    for (final c in _dotControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Large peach circle
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFF0E8),
            ),
          ),
          // Card icon
          const Icon(
            Icons.credit_card_rounded,
            size: 48,
            color: Color(0xFFFE5D17),
          ),
          // Orbiting dots
          ..._buildOrbitDots(),
        ],
      ),
    );
  }

  List<Widget> _buildOrbitDots() {
    return List.generate(6, (i) {
      return FadeTransition(
        opacity: _dotAnimations[i % _dotAnimations.length],
        child: Transform.translate(
          offset: Offset(
            70 + 58 * (i / 5 - 0.5),
            70 + 30 * ((i % 3) / 2 - 0.5),
          ),
          child: Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFFE5D17),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    });
  }
}
