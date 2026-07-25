import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../booking_bloc.dart';
import '../booking_event.dart';
import '../booking_state.dart';
import '../../../../core/widgets/themed_top_header.dart';
import 'payment_webview_screen.dart';
import 'payment_result_screen.dart';
import 'booking_confirmation_screen.dart';

class ProcessingPaymentScreen extends StatelessWidget {
  final String eventId;
  final String eventTitle;
  final int ticketQuantity;

  const ProcessingPaymentScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.ticketQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<BookingBloc>()..add(CreateBookingEvent(eventId, ticketQuantity)),
      child: _ProcessingPaymentView(
        eventId: eventId,
        eventTitle: eventTitle,
        ticketQuantity: ticketQuantity,
      ),
    );
  }
}

class _ProcessingPaymentView extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final int ticketQuantity;

  const _ProcessingPaymentView({
    required this.eventId,
    required this.eventTitle,
    required this.ticketQuantity,
  });

  @override
  State<_ProcessingPaymentView> createState() => _ProcessingPaymentViewState();
}

class _ProcessingPaymentViewState extends State<_ProcessingPaymentView> {
  /// Guard: prevent BlocListener from navigating more than once.
  /// Without this, when the Bloc re-emits while the WebView is already open
  /// (ProcessingPaymentScreen is still in the stack), the listener fires again
  /// and pushes a second WebView on top — which looks like a "refresh".
  bool _navigationHandled = false;

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingBloc, BookingState>(
      listener: (context, state) {
        if (state is BookingPending) {
          // Immediately initiate payment when pending
          context
              .read<BookingBloc>()
              .add(InitiatePaymentEvent(state.booking.id));
        } else if (state is PaymentInitiated) {
          // Guard: only navigate once even if Bloc re-emits PaymentInitiated
          if (_navigationHandled) return;
          _navigationHandled = true;

          final capturedState = state;
          final bookingBloc = context.read<BookingBloc>();
          // Use async IIFE to await the WebView result
          () async {
            // Push WebView and wait for it to pop with true/false
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: bookingBloc,
                  child: PaymentWebViewScreen(
                    paymentUrl: capturedState.paymentUrl,
                    bookingId: capturedState.bookingId,
                  ),
                ),
              ),
            );
            if (!context.mounted) return;
            final success = result ?? false;
            // Fire BLoC event so state is updated
            bookingBloc.add(
              PaymentResultEvent(
                success: success,
                bookingId: capturedState.bookingId,
              ),
            );
            // Navigate to result screen, replacing entire stack up to here
            // PaymentResultScreen creates its own fresh BookingBloc internally.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PaymentResultScreen(
                  success: success,
                  bookingId: capturedState.bookingId,
                  eventTitle: widget.eventTitle,
                  seats: widget.ticketQuantity,
                ),
              ),
            );
          }();
        } else if (state is BookingWaitlisted) {
          if (_navigationHandled) return;
          _navigationHandled = true;

          final bookingBloc = context.read<BookingBloc>();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: bookingBloc,
                child: BookingConfirmationScreen(
                  booking: state.booking,
                  eventTitle: widget.eventTitle,
                  eventId: widget.eventId,
                ),
              ),
            ),
          );
        } else if (state is BookingError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context); // Go back on error
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F8),
        body: Column(
          children: [
            const ThemedTopHeader(
              title: 'Payment',
              showBackButton: true,
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEBB9D), // Light peach color
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Icon(
                              Icons.credit_card_rounded,
                              size: 72,
                              color: Color(0xFFFE5D17),
                            ),
                            Padding(
                              padding: EdgeInsets.only(bottom: 4, right: 4),
                              child: Icon(
                                Icons.security_rounded,
                                size: 36,
                                color: Color(0xFFFE5D17),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Processing your payment..',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Please wait a moment',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 64),
                    const CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFE5D17)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
