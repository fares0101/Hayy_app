import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../app_router.dart';
import '../../../../injection_container.dart';
import '../../../../core/widgets/custom_button.dart';
import '../booking_bloc.dart';
import '../booking_event.dart';
import '../booking_state.dart';
import '../../../../core/widgets/themed_top_header.dart';

class PaymentResultScreen extends StatelessWidget {
  final bool success;
  final String bookingId;
  final String eventTitle;
  final String dateStr;
  final int seats;
  final String totalAmount;

  const PaymentResultScreen({
    super.key,
    required this.success,
    required this.bookingId,
    required this.eventTitle,
    this.dateStr = '30 Jan 2026',
    this.seats = 1,
    this.totalAmount = '200 EGP',
  });

  @override
  Widget build(BuildContext context) {
    // Create a fresh BookingBloc owned by this screen.
    // Do NOT receive the bloc from outside — the caller's BlocProvider(create:)
    // disposes the bloc when it leaves the stack, so we must own it here.
    return BlocProvider(
      create: (_) => sl<BookingBloc>(),
      child: _PaymentResultBody(
        success: success,
        bookingId: bookingId,
        eventTitle: eventTitle,
        dateStr: dateStr,
        seats: seats,
        totalAmount: totalAmount,
      ),
    );
  }
}

// ── Inner stateful body ───────────────────────────────────────────────────────
class _PaymentResultBody extends StatefulWidget {
  final bool success;
  final String bookingId;
  final String eventTitle;
  final String dateStr;
  final int seats;
  final String totalAmount;

  const _PaymentResultBody({
    required this.success,
    required this.bookingId,
    required this.eventTitle,
    required this.dateStr,
    required this.seats,
    required this.totalAmount,
  });

  @override
  State<_PaymentResultBody> createState() => _PaymentResultBodyState();
}

class _PaymentResultBodyState extends State<_PaymentResultBody> {
  @override
  void initState() {
    super.initState();
    // Auto-fetch QR if payment succeeded — bloc is freshly created above
    if (widget.success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<BookingBloc>().add(GetBookingQREvent(widget.bookingId));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: Column(
        children: [
          ThemedTopHeader(
            title: widget.success ? 'Book Event' : 'Something Wrong',
            showBackButton: true,
            onBackPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
            },
          ),
          Expanded(
            child: widget.success
                ? _SuccessView(
                    bookingId: widget.bookingId,
                    eventTitle: widget.eventTitle,
                    dateStr: widget.dateStr,
                    seats: widget.seats,
                    totalAmount: widget.totalAmount,
                  )
                : const _FailedView(),
          ),
        ],
      ),
    );
  }
}

// ─── Success View ─────────────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final String bookingId;
  final String eventTitle;
  final String dateStr;
  final int seats;
  final String totalAmount;

  const _SuccessView({
    required this.bookingId,
    required this.eventTitle,
    required this.dateStr,
    required this.seats,
    required this.totalAmount,
  });

  Future<void> _shareTicket(BuildContext context, String qrBase64) async {
    final pdf = pw.Document();

    String cleanBase64 = qrBase64;
    if (qrBase64.startsWith('data:image')) {
      cleanBase64 = qrBase64.split(',').last;
    }

    Uint8List qrBytes;
    try {
      qrBytes = base64Decode(cleanBase64);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR format. Cannot share.')),
      );
      return;
    }

    final image = pw.MemoryImage(qrBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text('HAYY App - Event Ticket',
                  style: pw.TextStyle(
                      fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange)),
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Event: $eventTitle',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Booking ID: $bookingId', style: const pw.TextStyle(fontSize: 16)),
                    pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 16)),
                    pw.Text('Seats: $seats Ticket(s)', style: const pw.TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Image(image, width: 200, height: 200),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Please show this QR code at the venue entrance.',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
            ],
          ),
        ),
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'hayy_ticket_$bookingId.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Success Icon
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF00C875),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your booking is confirmed!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 32),
          
          // Booking Details
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Booking Details:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                _buildDetailRow(Icons.calendar_today_outlined, 'Date', dateStr),
                const Divider(height: 24),
                _buildDetailRow(Icons.event_seat_outlined, 'Seats', '$seats'),
                const Divider(height: 24),
                _buildDetailRow(Icons.receipt_long_outlined, 'Total', totalAmount),
              ],
            ),
          ),
          const SizedBox(height: 32),
          
          // QR Code
          const Text(
            'Show this QR code at the venue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          BlocBuilder<BookingBloc, BookingState>(
            builder: (context, state) {
              if (state is BookingLoading) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFE5D17)),
                    ),
                  ),
                );
              } else if (state is BookingQRLoaded) {
                String base64String = state.qrCodeBase64;
                if (base64String.startsWith('data:image')) {
                  base64String = base64String.split(',').last;
                }
                try {
                  final decodedBytes = base64Decode(base64String);
                  return Image.memory(
                    decodedBytes,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  );
                } catch (e) {
                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: Text('Invalid QR format', style: TextStyle(color: Colors.red)),
                    ),
                  );
                }
              } else if (state is BookingError) {
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      state.message,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFE5D17)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 48),
          
          // Buttons
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                final state = context.read<BookingBloc>().state;
                if (state is BookingQRLoaded) {
                  _shareTicket(context, state.qrCodeBase64);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('QR Code is still loading. Please wait.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text(
                'Share QR',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Go to home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
            },
            height: 50,
            borderRadius: 999,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFFE5D17)),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

// ─── Failed View ──────────────────────────────────────────────────────────────
class _FailedView extends StatelessWidget {
  const _FailedView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Spacer(),
          // Failed Icon
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Failed',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const Spacer(),
          
          // Go to home button
          CustomButton(
            text: 'Go to home',
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
            },
            height: 50,
            borderRadius: 999,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
