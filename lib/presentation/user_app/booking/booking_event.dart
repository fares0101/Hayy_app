import '../../../data/user_app/models/booking_model.dart';

abstract class BookingEvent {}

// ─── Step 1: Create booking ───────────────────────────────────────────────────
class CreateBookingEvent extends BookingEvent {
  final String eventId;
  final int ticketQuantity;

  CreateBookingEvent(this.eventId, this.ticketQuantity);
}

// ─── Step 2: Initiate payment ─────────────────────────────────────────────────
class InitiatePaymentEvent extends BookingEvent {
  final String bookingId;

  InitiatePaymentEvent(this.bookingId);
}

// ─── Step 3: Payment result from WebView ─────────────────────────────────────
class PaymentResultEvent extends BookingEvent {
  final bool success;
  final String bookingId;

  PaymentResultEvent({required this.success, required this.bookingId});
}

// ─── Step 4: Load QR ──────────────────────────────────────────────────────────
class GetBookingQREvent extends BookingEvent {
  final String bookingId;

  GetBookingQREvent(this.bookingId);
}

// ─── Polling & Timer ──────────────────────────────────────────────────────────
class GetBookingDetailsEvent extends BookingEvent {
  final String eventId;

  GetBookingDetailsEvent(this.eventId);
}

/// Fetches ALL bookings for the authenticated user (no eventId needed).
/// Uses GET /api/EventBookings/my-bookings
class GetMyBookingsEvent extends BookingEvent {}

/// Starts the periodic waitlist poll timer inside the Bloc.
/// Use this when navigating to a screen that shows an already-created
/// waitlisted booking (i.e. the Bloc didn't go through CreateBookingEvent).
class StartWaitlistPollingEvent extends BookingEvent {
  final BookingModel booking;

  StartWaitlistPollingEvent(this.booking);
}

class TimerTickEvent extends BookingEvent {
  final BookingModel booking;

  TimerTickEvent(this.booking);
}

class WaitlistPollEvent extends BookingEvent {
  final BookingModel booking;

  WaitlistPollEvent(this.booking);
}

class CancelBookingTimersEvent extends BookingEvent {}
