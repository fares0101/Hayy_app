import 'package:flutter/material.dart';
import '../../../../core/widgets/themed_top_header.dart';
import '../../../../core/widgets/custom_button.dart';
import 'processing_payment_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final int ticketQuantity;

  const PaymentMethodScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.ticketQuantity,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Payment',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: IntrinsicHeight(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height - ThemedTopHeader.heightFor(context) - 48,
                  ),
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            const Text(
              'Payment Method:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            
            // Payment Method Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFE5D17), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFE5D17),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Credit Card',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            
            const Center(
              child: Text(
                'Your payment is secure\nand encryption',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ),
            
            const Spacer(),
            
            CustomButton(
              text: 'Continue',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProcessingPaymentScreen(
                      eventId: widget.eventId,
                      eventTitle: widget.eventTitle,
                      ticketQuantity: widget.ticketQuantity,
                    ),
                  ),
                );
              },
              borderRadius: 999,
            ),
            const SizedBox(height: 24),
            
            const Center(
              child: Text(
                'You will not be charged yet!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}
