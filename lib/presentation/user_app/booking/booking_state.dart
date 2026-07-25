import 'package:equatable/equatable.dart';
import '../../../data/user_app/models/booking_model.dart';

abstract class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {}

class BookingLoading extends BookingState {}

// ─── Booking Created: Pending ─────────────────────────────────────────────────
class BookingPending extends BookingState {
  final BookingModel booking;
  final Duration remaining;

  const BookingPending(this.booking, this.remaining);

  @override
  List<Object?> get props => [booking, remaining];
}

// ─── Booking Created: Waitlisted ─────────────────────────────────────────────
class BookingWaitlisted extends BookingState {
  final BookingModel booking;

  const BookingWaitlisted(this.booking);

  @override
  List<Object?> get props => [booking];
}

// ─── Waitlist promoted to Pending ────────────────────────────────────────────
class WaitlistPromotedToPending extends BookingState {
  final BookingModel booking;

  const WaitlistPromotedToPending(this.booking);

  @override
  List<Object?> get props => [booking];
}

// ─── Booking Expired ──────────────────────────────────────────────────────────
class BookingExpired extends BookingState {}

// ─── Payment ──────────────────────────────────────────────────────────────────
class PaymentInitiated extends BookingState {
  final String paymentUrl;
  final String bookingId;

  const PaymentInitiated({required this.paymentUrl, required this.bookingId});

  @override
  List<Object?> get props => [paymentUrl, bookingId];
}

class PaymentSuccess extends BookingState {
  final String bookingId;

  const PaymentSuccess(this.bookingId);

  @override
  List<Object?> get props => [bookingId];
}

class PaymentFailed extends BookingState {
  final String message;

  const PaymentFailed(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── QR ───────────────────────────────────────────────────────────────────────
class BookingQRLoaded extends BookingState {
  final String qrCodeBase64;
  final String bookingId;

  const BookingQRLoaded({required this.qrCodeBase64, required this.bookingId});

  @override
  List<Object?> get props => [qrCodeBase64, bookingId];
}

// ─── My Tickets (list) ────────────────────────────────────────────────────────
class MyTicketsLoaded extends BookingState {
  final List<BookingModel> tickets;

  const MyTicketsLoaded(this.tickets);

  @override
  List<Object?> get props => [tickets];
}

// ─── Error ────────────────────────────────────────────────────────────────────
class BookingError extends BookingState {
  final String message;

  const BookingError(this.message);

  @override
  List<Object?> get props => [message];
}

// Keep for backward compatibility
class BookingCreated extends BookingState {
  final Map<String, dynamic> booking;

  const BookingCreated(this.booking);

  @override
  List<Object?> get props => [booking];
}
