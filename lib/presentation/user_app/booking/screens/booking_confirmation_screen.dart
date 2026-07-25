import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/user_app/models/booking_model.dart';
import '../booking_bloc.dart';
import '../booking_event.dart';
import '../booking_state.dart';
import 'payment_result_screen.dart';
import 'payment_webview_screen.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final BookingModel booking;
  final String eventTitle;
  /// Explicit event ID passed from parent to guarantee correct polling
  /// even if the booking response omits the eventId field.
  final String eventId;

  const BookingConfirmationScreen({
    super.key,
    required this.booking,
    required this.eventTitle,
    required this.eventId,
  });

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<BookingBloc>();
      // Remove unused pollId
      if (widget.booking.isPending) {
        bloc.add(TimerTickEvent(widget.booking));
      } else if (widget.booking.isWaitlisted) {
        bloc.add(
          StartWaitlistPollingEvent(widget.booking),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _BookingConfirmationView(
      booking: widget.booking,
      eventTitle: widget.eventTitle,
    );
  }
}

class _BookingConfirmationView extends StatefulWidget {
  final BookingModel booking;
  final String eventTitle;
  const _BookingConfirmationView({
    required this.booking,
    required this.eventTitle,
  });

  @override
  State<_BookingConfirmationView> createState() =>
      _BookingConfirmationViewState();
}

class _BookingConfirmationViewState extends State<_BookingConfirmationView> {
  /// Guard: only fire the payment initiation once per promotion.
  bool _paymentTriggered = false;

  /// Guard: prevent double push to WebView if PaymentInitiated re-emits.
  bool _paymentNavigated = false;

  @override
  void initState() {
    super.initState();
    // The bloc now handles all polling via StartWaitlistPollingEvent
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: BlocConsumer<BookingBloc, BookingState>(
        listener: (context, state) {
          if (state is BookingError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
          } else if (state is PaymentInitiated) {
            if (_paymentNavigated) return;
            _paymentNavigated = true;
            final capturedState = state;
            final bookingBloc = context.read<BookingBloc>();
            // Use async IIFE so we can await the WebView result
            () async {
              // Push WebView and wait for it to pop with true/false
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => PaymentWebViewScreen(
                    paymentUrl: capturedState.paymentUrl,
                    bookingId: capturedState.bookingId,
                  ),
                ),
              );
              if (!mounted) return;
              final success = result ?? false;
              // Fire BLoC event so state is updated
              bookingBloc.add(
                PaymentResultEvent(
                  success: success,
                  bookingId: capturedState.bookingId,
                ),
              );
              // Navigate to result screen, removing WebView + confirmation from stack
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PaymentResultScreen(
                    success: success,
                    bookingId: capturedState.bookingId,
                    eventTitle: widget.eventTitle,
                    seats: widget.booking.ticketQuantity,
                  ),
                ),
              );
            }();
          } else if (state is WaitlistPromotedToPending) {
            if (!_paymentTriggered) {
              _paymentTriggered = true;
              _showPromotedDialog(context, state.booking);
            }
          } else if (state is BookingExpired) {
            _showExpiredDialog(context);
          }
        },
        builder: (context, state) {
          // Determine which booking to render
          BookingModel currentBooking = widget.booking;
          Duration remaining = widget.booking.remainingTime;

          if (state is BookingPending) {
            currentBooking = state.booking;
            remaining = state.remaining;
          } else if (state is WaitlistPromotedToPending) {
            currentBooking = state.booking;
            remaining = state.booking.remainingTime;
          } else if (state is BookingWaitlisted) {
            currentBooking = state.booking;
          }

          return Column(
            children: [
              _BookingHeader(
                eventTitle: widget.eventTitle,
                status: currentBooking.status,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: const Color(0xFFFE5D17),
                  onRefresh: () async {
                    try {
                      if (state is! WaitlistPromotedToPending &&
                          !currentBooking.isPending) {
                        final bloc = context.read<BookingBloc>();
                        if (!bloc.isClosed) {
                          bloc.add(WaitlistPollEvent(currentBooking));
                        }
                      }
                    } catch (_) {}
                    // Guarantee the spinner shows for a bit then disappears
                    await Future.delayed(const Duration(milliseconds: 1500));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.sizeOf(context).width * 0.06,
                        vertical: MediaQuery.sizeOf(context).height * 0.024,
                      ),
                      child: currentBooking.isPending ||
                              state is WaitlistPromotedToPending
                          ? _PendingContent(
                              booking: currentBooking,
                              remaining: remaining,
                              isLoading: state is BookingLoading,
                              onPayNow: () => context.read<BookingBloc>().add(
                                    InitiatePaymentEvent(currentBooking.id),
                                  ),
                            )
                          : _WaitlistContent(
                              booking: widget.booking,
                              isPromoted: state is WaitlistPromotedToPending,
                              onProceedToPayment: state is WaitlistPromotedToPending
                                  ? () => context.read<BookingBloc>().add(
                                        InitiatePaymentEvent(currentBooking.id),
                                      )
                                  : null,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows a celebratory dialog then automatically initiates payment.
  void _showPromotedDialog(BuildContext context, BookingModel promoted) {
    final sh = MediaQuery.sizeOf(context).height;
    final sw = MediaQuery.sizeOf(context).width;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(sw * 0.06)),
        contentPadding: EdgeInsets.fromLTRB(
            sw * 0.06, sh * 0.03, sw * 0.06, sh * 0.03),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: sw * 0.22,
              height: sw * 0.22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0E8),
              ),
              child: Icon(
                Icons.celebration_rounded,
                color: const Color(0xFFFE5D17),
                size: sw * 0.12,
              ),
            ),
            SizedBox(height: sh * 0.02),
            Text(
              "🎉 It's your turn!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sh * 0.026,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            SizedBox(height: sh * 0.012),
            Text(
              'A spot just opened up for you.\nWe\'re taking you to payment now...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sh * 0.016,
                color: const Color(0xFF7A7A7A),
                height: 1.5,
              ),
            ),
            SizedBox(height: sh * 0.024),
            const CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFFFE5D17)),
            ),
          ],
        ),
      ),
    );

    // Auto-dismiss after 2 seconds then fire payment
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;                   // use State.mounted, not context.mounted
      Navigator.of(context).pop();            // pop only the dialog, not the screen
      context
          .read<BookingBloc>()
          .add(InitiatePaymentEvent(promoted.id));
    });
  }

  void _showExpiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '⏰ Booking Expired',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Your 15-minute window has passed and the booking was cancelled automatically. Please try booking again.',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFE5D17),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _BookingHeader extends StatelessWidget {
  final String eventTitle;
  final String status;

  const _BookingHeader({required this.eventTitle, required this.status});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final sh = MediaQuery.sizeOf(context).height;
    final sw = MediaQuery.sizeOf(context).width;
    final statusLabel = status == 'Pending' ? 'Pending Payment' : 'Waitlisted';
    final statusColor =
        status == 'Pending' ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9);
    final statusTextColor =
        status == 'Pending' ? const Color(0xFFFE5D17) : const Color(0xFF2E7D32);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        sw * 0.04,
        topPad + sh * 0.02,
        sw * 0.04,
        sh * 0.024,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFE5D17), Color(0xFF98380E)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: sw * 0.055,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Booking',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: sh * 0.024,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          SizedBox(height: sh * 0.01),
          Text(
            eventTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: sh * 0.02,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: sh * 0.01),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: sw * 0.04,
              vertical: sh * 0.007,
            ),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusTextColor,
                fontSize: sh * 0.015,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pending Content ─────────────────────────────────────────────────────────
class _PendingContent extends StatelessWidget {
  final BookingModel booking;
  final Duration remaining;
  final bool isLoading;
  final VoidCallback onPayNow;

  const _PendingContent({
    required this.booking,
    required this.remaining,
    required this.isLoading,
    required this.onPayNow,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    final sh = MediaQuery.sizeOf(context).height;
    final minutes =
        remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final progress = 1.0 - (remaining.inSeconds / (15 * 60));
    final ringSize = sw * 0.44;

    return Column(
      children: [
        SizedBox(height: sh * 0.02),
        // ─ Countdown ring ─
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CustomPaint(
                  painter:
                      _CountdownRingPainter(progress: progress.clamp(0.0, 1.0)),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$minutes:$seconds',
                    style: TextStyle(
                      fontSize: sh * 0.048,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFE5D17),
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    'remaining',
                    style: TextStyle(
                      fontSize: sh * 0.015,
                      color: const Color(0xFF8A8A8A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: sh * 0.028),

        // ─ Info card ─
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(sw * 0.05),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(sw * 0.05),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.credit_card_rounded,
                color: const Color(0xFFFE5D17),
                size: sw * 0.1,
              ),
              SizedBox(height: sh * 0.014),
              Text(
                'Complete your payment',
                style: TextStyle(
                  fontSize: sh * 0.02,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: sh * 0.01),
              Text(
                'Your booking is reserved for 15 minutes.\nPay now to confirm your spot!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: sh * 0.016,
                  color: const Color(0xFF7A7A7A),
                  height: 1.5,
                ),
              ),
              SizedBox(height: sh * 0.018),
              _BookingDetailRow(
                label: 'Tickets',
                value: '${booking.ticketQuantity}',
              ),
              SizedBox(height: sh * 0.01),
              _BookingDetailRow(
                label: 'Booking ID',
                value: booking.id.length > 8
                    ? '...${booking.id.substring(booking.id.length - 8)}'
                    : booking.id,
              ),
            ],
          ),
        ),
        SizedBox(height: sh * 0.032),

        // ─ Pay button ─
        SizedBox(
          width: double.infinity,
          height: sh * 0.065,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFE7A2A), Color(0xFFFE5D17)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44FE5D17),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: isLoading ? null : onPayNow,
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: sh * 0.03,
                          height: sh * 0.03,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Pay Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: sh * 0.02,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: sh * 0.014),
        Text(
          'Your booking expires if not paid in time.',
          style: TextStyle(
            fontSize: sh * 0.014,
            color: const Color(0xFF9A9A9A),
          ),
        ),
        SizedBox(height: sh * 0.05),
      ],
    );
  }
}

// ─── Waitlist Content ────────────────────────────────────────────────────────
class _WaitlistContent extends StatefulWidget {
  final BookingModel booking;
  final bool isPromoted;
  final VoidCallback? onProceedToPayment;

  const _WaitlistContent({
    required this.booking,
    required this.isPromoted,
    this.onProceedToPayment,
  });

  @override
  State<_WaitlistContent> createState() => _WaitlistContentState();
}

class _WaitlistContentState extends State<_WaitlistContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.sizeOf(context).width;
    final sh = MediaQuery.sizeOf(context).height;
    final position = widget.booking.waitlistPosition ?? 1;
    final iconCircleSize = sw * 0.4;
    final isPromoted = widget.isPromoted;

    return Column(
      children: [
        SizedBox(height: sh * 0.028),
        // ─ Pulse icon ─
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: iconCircleSize,
            height: iconCircleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPromoted
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF0E8),
              border: Border.all(
                color: isPromoted
                    ? const Color(0xFF2E7D32).withValues(alpha: 0.4)
                    : const Color(0xFFFE5D17).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                isPromoted ? Icons.celebration_rounded : Icons.queue_rounded,
                size: iconCircleSize * 0.42,
                color: isPromoted
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFFE5D17),
              ),
            ),
          ),
        ),
        SizedBox(height: sh * 0.032),

        // ─ Position / Promoted badge ─
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: sw * 0.07,
            vertical: sh * 0.016,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPromoted
                  ? [const Color(0xFF43A047), const Color(0xFF2E7D32)]
                  : [const Color(0xFFFE7A2A), const Color(0xFFFE5D17)],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: isPromoted
                    ? const Color(0x402E7D32)
                    : const Color(0x40FE5D17),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPromoted
                    ? Icons.check_circle_rounded
                    : Icons.people_alt_rounded,
                color: Colors.white,
                size: sw * 0.055,
              ),
              SizedBox(width: sw * 0.025),
              Text(
                isPromoted
                    ? '🎉 It\'s your turn!'
                    : 'Position #$position in Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: sh * 0.019,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: sh * 0.028),

        // ─ Info card ─
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(sw * 0.055),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(sw * 0.05),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                isPromoted
                    ? 'A spot opened for you!'
                    : 'You\'re on the waitlist!',
                style: TextStyle(
                  fontSize: sh * 0.022,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: sh * 0.012),
              Text(
                isPromoted
                    ? 'Great news! Tap "Proceed to Payment" below to complete your booking.'
                    : 'When someone cancels their booking, you\'ll be promoted automatically. We\'ll send you an email notification.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: sh * 0.016,
                  color: const Color(0xFF7A7A7A),
                  height: 1.55,
                ),
              ),
              SizedBox(height: sh * 0.02),
              const Divider(color: Color(0xFFEEEEEE)),
              SizedBox(height: sh * 0.016),
              _BookingDetailRow(
                label: 'Tickets',
                value: '${widget.booking.ticketQuantity}',
              ),
              SizedBox(height: sh * 0.01),
              _BookingDetailRow(
                label: 'Status',
                value: isPromoted ? 'Ready to Pay' : 'Checking every 10 sec',
                valueColor: isPromoted
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFFE5D17),
              ),
            ],
          ),
        ),
        SizedBox(height: sh * 0.028),

        // ─ Proceed to Payment button (disabled until promoted) ─
        SizedBox(
          width: double.infinity,
          height: sh * 0.065,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPromoted
                    ? [const Color(0xFF43A047), const Color(0xFF2E7D32)]
                    : [const Color(0xFFBDBDBD), const Color(0xFF9E9E9E)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: isPromoted
                  ? const [
                      BoxShadow(
                        color: Color(0x442E7D32),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      )
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: isPromoted ? widget.onProceedToPayment : null,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPromoted
                            ? Icons.payment_rounded
                            : Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: sh * 0.024,
                      ),
                      SizedBox(width: sw * 0.02),
                      Text(
                        'Proceed to Payment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: sh * 0.02,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: sh * 0.016),
        // ─ Polling dots (only when not promoted) ─
        if (!isPromoted) ...[
          const _PollingDots(),
          SizedBox(height: sh * 0.012),
          Text(
            'Auto-checking your queue status...',
            style: TextStyle(
              fontSize: sh * 0.015,
              color: const Color(0xFF9A9A9A),
            ),
          ),
        ],
        SizedBox(height: sh * 0.05),
      ],
    );
  }
}

// ─── Polling Dots Animation ───────────────────────────────────────────────────
class _PollingDots extends StatefulWidget {
  const _PollingDots();

  @override
  State<_PollingDots> createState() => _PollingDotsState();
}

class _PollingDotsState extends State<_PollingDots>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _animations = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 4; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      _controllers.add(ctrl);
      _animations.add(Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeInOut),
      ));
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FadeTransition(
            opacity: _animations[i],
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
      }),
    );
  }
}

// ─── Shared Detail Row ────────────────────────────────────────────────────────
class _BookingDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _BookingDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.sizeOf(context).height;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: sh * 0.016,
            color: const Color(0xFF9A9A9A),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: sh * 0.016,
            color: valueColor ?? const Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Countdown Ring Painter ───────────────────────────────────────────────────
class _CountdownRingPainter extends CustomPainter {
  final double progress; // 0.0 = start, 1.0 = expired

  const _CountdownRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 12.0;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFEEEEEE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    final sweepAngle = 2 * math.pi * (1.0 - progress);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFE7A2A), Color(0xFFFE5D17)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) => old.progress != progress;
}
