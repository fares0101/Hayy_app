import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';

import '../../../core/storage/user_session_manager.dart';
import '../../../data/user_app/datasources/booking_remote_data_source.dart';
import '../../../data/user_app/models/booking_model.dart';
import 'booking_event.dart';
import 'booking_state.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRemoteDataSource _dataSource;
  final UserSessionManager _sessionManager;

  Timer? _countdownTimer;
  Timer? _pollTimer;

  BookingBloc(this._dataSource, this._sessionManager)
      : super(BookingInitial()) {
    on<CreateBookingEvent>(_onCreateBooking);
    on<TimerTickEvent>(_onTimerTick);
    on<WaitlistPollEvent>(_onWaitlistPoll);
    on<StartWaitlistPollingEvent>(_onStartWaitlistPolling);
    on<InitiatePaymentEvent>(_onInitiatePayment);
    on<PaymentResultEvent>(_onPaymentResult);
    on<GetBookingQREvent>(_onGetBookingQR);
    on<GetBookingDetailsEvent>(_onGetBookingDetails);
    on<GetMyBookingsEvent>(_onGetMyBookings);
    on<CancelBookingTimersEvent>(_onCancelTimers);
  }

  // ─── Step 1: Create Booking ────────────────────────────────────────────────
  Future<void> _onCreateBooking(
    CreateBookingEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    _stopAllTimers();

    try {
      final data = await _dataSource.createBooking(
        eventId: event.eventId,
        ticketQuantity: event.ticketQuantity,
      );

      final booking = _parseBookingFromResponse(data);
      if (booking == null) {
        emit(const BookingError('Failed to parse booking response.'));
        return;
      }

      if (booking.isPending) {
        emit(BookingPending(booking, booking.remainingTime));
        _startCountdownTimer(booking);
      } else if (booking.isWaitlisted) {
        emit(BookingWaitlisted(booking));
        _startWaitlistPoll(booking);
      } else {
        emit(BookingError('Unexpected booking status: ${booking.status}'));
      }
    } catch (e) {
      emit(BookingError(_parseError(e)));
    }
  }

  // ─── Countdown Timer ───────────────────────────────────────────────────────
  void _startCountdownTimer(BookingModel booking) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(TimerTickEvent(booking));
    });
  }

  void _onTimerTick(TimerTickEvent event, Emitter<BookingState> emit) {
    final remaining = event.booking.remainingTime;
    if (remaining == Duration.zero) {
      _countdownTimer?.cancel();
      emit(BookingExpired());
    } else {
      emit(BookingPending(event.booking, remaining));
    }
  }

  // ─── Start Waitlist Polling (from an external screen) ─────────────────────
  void _onStartWaitlistPolling(
    StartWaitlistPollingEvent event,
    Emitter<BookingState> emit,
  ) {
    _startWaitlistPoll(event.booking);
  }

  void _startWaitlistPoll(BookingModel booking) {
    _pollTimer?.cancel();
    // Poll immediately once, then every 5 seconds
    if (!isClosed) add(WaitlistPollEvent(booking));
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!isClosed) add(WaitlistPollEvent(booking));
    });
  }

  Future<void> _onWaitlistPoll(
    WaitlistPollEvent event,
    Emitter<BookingState> emit,
  ) async {
    try {
      // Try to fetch by bookingId first, fall back to eventId if necessary
      dynamic rawData;
      try {
        rawData = await _dataSource.getBookingById(bookingId: event.booking.id);
      } catch (_) {
        // Fallback to old behavior if endpoint doesn't exist
        rawData = await _dataSource.getBookingDetails(eventId: event.booking.eventId);
      }

      BookingModel? booking;

      if (rawData is List && rawData.isNotEmpty) {
        // API returned a plain List — find the first pending booking
        final all = rawData
            .map((e) =>
                BookingModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        booking = all.firstWhere(
          (b) => b.isPending,
          orElse: () => all.first,
        );
      } else if (rawData is Map<String, dynamic>) {
        final items =
            rawData['items'] ?? rawData['data'] ?? rawData['Data'] ?? rawData['result'];
        if (items is List && items.isNotEmpty) {
          final all = items
              .map((e) => BookingModel.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
          booking = all.firstWhere(
            (b) => b.isPending,
            orElse: () => all.first,
          );
        } else if (items is Map) {
          booking = BookingModel.fromJson(
              Map<String, dynamic>.from(items));
        } else if (rawData.containsKey('id') ||
            rawData.containsKey('bookingId')) {
          booking = BookingModel.fromJson(rawData);
        }
        // Check if the raw status field at root level is pending
        // (handles flat response shape)
        if (booking == null) {
          final rawStatus = rawData['status']?.toString().trim().toLowerCase() ?? '';
          if (rawStatus == 'pending' || rawStatus == 'panding') {
            booking = BookingModel.fromJson(rawData);
          }
        }
      } else if (rawData is String) {
        // The endpoint just returns a string status like "Panding"
        final rawStatus = rawData.trim().toLowerCase();
        if (rawStatus == 'pending' || rawStatus == 'panding') {
           // Copy the original booking but update its status so we don't lose ticketQuantity
           booking = event.booking.copyWith(status: 'Pending');
        } else {
           booking = event.booking.copyWith(status: rawData.trim());
        }
      }

      if (booking == null) return;

      // BookingModel.isPending is now case-insensitive, so this catches
      // "pending", "Pending", "PENDING", etc.
      if (booking.isPending) {
        _pollTimer?.cancel();
        // Ensure the status string is normalised for downstream UI checks
        final promotedBooking = booking.copyWith(
          status: 'Pending',
          paymentDeadline: booking.paymentDeadline ??
              DateTime.now().add(const Duration(minutes: 15)),
        );
        emit(WaitlistPromotedToPending(promotedBooking));
        _startCountdownTimer(promotedBooking);
      } else if (booking.isCancelled) {
        // Expose backend bug to user UI instead of silently looping
        emit(const BookingError('Backend Bug: API returned a Cancelled booking instead of the current Waitlist/Pending booking.'));
      }
      // Still waitlisted — keep polling silently
    } catch (e) {
      // Temporarily emit error to help debug why polling is stuck
      emit(BookingError('Waitlist polling failed: $e'));
      print('[BookingBloc] Poll error: $e');
    }
  }

  // ─── Step 2: Initiate Payment ─────────────────────────────────────────────
  Future<void> _onInitiatePayment(
    InitiatePaymentEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      final userId = _sessionManager.getUser()?.id ?? '';
      final data = await _dataSource.initiatePayment(
        userId: userId,
        bookingId: event.bookingId,
      );
      final url = data['url']?.toString() ?? '';
      if (url.isEmpty) {
        emit(const BookingError('Failed to get payment URL from server.'));
        return;
      }
      emit(PaymentInitiated(paymentUrl: url, bookingId: event.bookingId));
    } catch (e) {
      emit(BookingError(_parseError(e)));
    }
  }

  // ─── Step 3: Payment Result (from WebView) ─────────────────────────────────
  void _onPaymentResult(
    PaymentResultEvent event,
    Emitter<BookingState> emit,
  ) {
    _countdownTimer?.cancel();
    if (event.success) {
      emit(PaymentSuccess(event.bookingId));
    } else {
      emit(const PaymentFailed('Payment was unsuccessful. Please try again.'));
    }
  }

  // ─── Step 4: Get QR Code ──────────────────────────────────────────────────
  Future<void> _onGetBookingQR(
    GetBookingQREvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      final data = await _dataSource.getBookingQR(bookingId: event.bookingId);

      // Try every possible field name the backend might use
      final qr = data['qrCode']?.toString() ??
          data['qrcode']?.toString() ??
          data['qr']?.toString() ??
          data['qrCodeBase64']?.toString() ??
          data['base64']?.toString() ??
          data['imageBase64']?.toString() ??
          data['image']?.toString() ??
          data['code']?.toString() ??
          data['data']?.toString() ??
          data['result']?.toString() ??
          '';

      if (qr.isEmpty) {
        emit(const BookingError('QR code not available yet.'));
        return;
      }
      emit(BookingQRLoaded(qrCodeBase64: qr, bookingId: event.bookingId));
    } catch (e) {
      emit(BookingError(_parseError(e)));
    }
  }

  // ─── Load All Bookings (My Booking page) ──────────────────────────────────
  Future<void> _onGetMyBookings(
    GetMyBookingsEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      final dynamic rawData = await _dataSource.getMyBookings();
      List<BookingModel> tickets = [];

      if (rawData is List) {
        tickets = rawData
            .map((e) => BookingModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      } else if (rawData is Map<String, dynamic>) {
        final items = rawData['items'] ?? rawData['data'] ?? rawData['result'];
        if (items is List) {
          tickets = items
              .map((e) => BookingModel.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
        } else if (rawData.containsKey('id') || rawData.containsKey('bookingId')) {
          tickets = [BookingModel.fromJson(rawData)];
        }
      }

      emit(MyTicketsLoaded(tickets));
    } catch (e) {
      emit(BookingError(_parseError(e)));
    }
  }

  // ─── Load Booking List (My Tickets legacy) ────────────────────────────────
  Future<void> _onGetBookingDetails(
    GetBookingDetailsEvent event,
    Emitter<BookingState> emit,
  ) async {
    emit(BookingLoading());
    try {
      // Use dynamic so Dart can narrow the type inside each branch
      final dynamic rawData =
          await _dataSource.getBookingDetails(eventId: event.eventId);

      List<BookingModel> tickets = [];

      if (rawData is List) {
        tickets = rawData
            .map((e) => BookingModel.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList();
      } else if (rawData is Map<String, dynamic>) {
        final items = rawData['items'] ?? rawData['data'] ?? rawData['result'];
        if (items is List) {
          tickets = items
              .map((e) => BookingModel.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
        } else {
          tickets = [BookingModel.fromJson(rawData)];
        }
      }

      emit(MyTicketsLoaded(tickets));
    } catch (e) {
      emit(BookingError(_parseError(e)));
    }
  }

  void _onCancelTimers(
    CancelBookingTimersEvent event,
    Emitter<BookingState> emit,
  ) {
    _stopAllTimers();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  void _stopAllTimers() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _countdownTimer = null;
    _pollTimer = null;
  }

  BookingModel? _parseBookingFromResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      final items = data['items'] ?? data['data'] ?? data['result'];
      if (items is List && items.isNotEmpty) {
        return BookingModel.fromJson(Map<String, dynamic>.from(items.first as Map));
      }
      if (items is Map) {
        return BookingModel.fromJson(Map<String, dynamic>.from(items));
      }
      if (data.containsKey('id') || data.containsKey('bookingId')) {
        return BookingModel.fromJson(data);
      }
    }
    return null;
  }

  String _parseError(Object e) {
    if (e is DioException) {
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          String finalMsg = '';
          final msg = data['message'] ?? data['title'] ?? data['detail'] ?? data['error'];
          if (msg != null && msg.toString().isNotEmpty) {
            finalMsg = msg.toString();
          }
          final errors = data['errors'];
          if (errors is Map) {
            final errorsStr = errors.entries.map((e) => '${e.key}: ${e.value}').join(', ');
            if (finalMsg.isNotEmpty) finalMsg += '\n';
            finalMsg += errorsStr;
          }
          if (finalMsg.isNotEmpty) return finalMsg;
        }
        if (data is String) return data;
      }
    }
    
    final msg = e.toString();
    if (msg.contains('401')) return 'Session expired. Please log in again.';
    if (msg.contains('400')) return 'Invalid booking request: Server returned 400.';
    if (msg.contains('404')) return 'Booking not found.';
    if (msg.contains('409')) return 'This event is no longer available.';
    if (msg.contains('SocketException') || msg.contains('network')) {
      return 'No internet connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<void> close() {
    _stopAllTimers();
    return super.close();
  }
}
