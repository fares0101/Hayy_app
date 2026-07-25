import 'package:equatable/equatable.dart';

class BookingModel extends Equatable {
  final String id;
  final String eventId;
  final String status; // "Pending" | "Waitlisted" | "Confirmed" | "Cancelled"
  final int ticketQuantity;
  final int? waitlistPosition;
  final DateTime? paymentDeadline;
  final bool isPaid;
  final String? qrCodeBase64;

  // ─── Event Details (populated from booking response) ──────────────────────
  final String? eventTitle;
  final DateTime? eventDate;
  final String? eventLocation;
  final String? eventImageUrl;
  final double? totalAmount;
  final String? eventDescription;

  const BookingModel({
    required this.id,
    required this.eventId,
    required this.status,
    required this.ticketQuantity,
    this.waitlistPosition,
    this.paymentDeadline,
    this.isPaid = false,
    this.qrCodeBase64,
    this.eventTitle,
    this.eventDate,
    this.eventLocation,
    this.eventImageUrl,
    this.totalAmount,
    this.eventDescription,
  });

  // ─── Case-insensitive status helpers ──────────────────────────────────────
  // ASP.NET's JsonStringEnumConverter may serialize as "pending", "waitlisted",
  // etc.  We normalise to lowercase so the app never breaks on casing.

  String get _statusLower => status.trim().toLowerCase();

  bool get isPending => _statusLower == 'pending';
  bool get isWaitlisted => _statusLower == 'waitlisted';
  bool get isConfirmed => _statusLower == 'confirmed';
  bool get isCancelled => _statusLower == 'cancelled';

  bool get isExpired {
    if (paymentDeadline == null) return false;
    return DateTime.now().isAfter(paymentDeadline!);
  }

  Duration get remainingTime {
    if (paymentDeadline == null) return Duration.zero;
    final diff = paymentDeadline!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // ── Parse status (case-insensitive normalisation) ────────────────────────
    final rawStatus = (json['status']?.toString() ?? 
                       json['bookingStatus']?.toString() ?? 
                       json['state']?.toString() ?? '').trim();
    String parsedStatus = rawStatus.isEmpty ? 'Pending' : rawStatus;
    if (parsedStatus.toLowerCase() == 'panding') {
      parsedStatus = 'Pending'; // Workaround for backend typo
    }

    // ── Parse payment deadline ──────────────────────────────────────────────
    DateTime? deadline;
    final rawDeadline = json['paymentDeadline'];
    if (rawDeadline != null && rawDeadline.toString().isNotEmpty) {
      String dateStr = rawDeadline.toString();
      // If the backend sends UTC without a timezone indicator, append 'Z'
      if (!dateStr.endsWith('Z') && !dateStr.contains('+')) {
        dateStr += 'Z';
      }
      deadline = DateTime.tryParse(dateStr)?.toLocal();
    }

    // Only default to 15 minutes if the booking is Pending (needs a timer).
    // Waitlisted bookings don't have a payment deadline.
    final isPendingStatus = parsedStatus.toLowerCase() == 'pending';
    if (deadline == null && isPendingStatus) {
      deadline = DateTime.now().add(const Duration(minutes: 15));
    }

    return BookingModel(
      id: json['id']?.toString() ?? json['bookingId']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      status: parsedStatus,
      ticketQuantity: int.tryParse(json['ticketQuantity']?.toString() ?? '') ?? 1,
      waitlistPosition: int.tryParse(json['waitlistPosition']?.toString() ?? ''),
      paymentDeadline: deadline,
      isPaid: json['isPaid'] == true,
      qrCodeBase64: json['qrCodeBase64']?.toString(),
      // ── Event Details: try multiple possible key paths ────────────────────
      eventTitle: _extractString(json, [
        'eventTitle', 'event.title', 'eventName', 'name',
      ], nested: json['event']),
      eventDate: _parseDate(json['eventDate']?.toString() ??
          json['event']?['date']?.toString() ??
          json['event']?['startDate']?.toString() ??
          json['event']?['eventDate']?.toString()),
      eventLocation: _extractString(json, [
        'eventLocation', 'location', 'venue',
      ], nested: json['event']),
      eventImageUrl: _extractString(json, [
        'eventImageUrl', 'imageUrl', 'image', 'coverImage',
      ], nested: json['event']),
      totalAmount: double.tryParse(
          json['totalAmount']?.toString() ??
          json['amount']?.toString() ??
          json['event']?['price']?.toString() ?? ''),
      eventDescription: _extractString(json, [
        'description', 'eventDescription',
      ], nested: json['event']),
    );
  }

  /// Safely extracts a non-null, non-empty string from a flat map,
  /// then falls back to the same keys inside [nested] if provided.
  static String? _extractString(
    Map<String, dynamic> json,
    List<String> keys, {
    dynamic nested,
  }) {
    for (final key in keys) {
      final val = json[key]?.toString();
      if (val != null && val.isNotEmpty) return val;
    }
    if (nested is Map) {
      final n = Map<String, dynamic>.from(nested);
      for (final key in keys) {
        final val = n[key]?.toString();
        if (val != null && val.isNotEmpty) return val;
      }
    }
    return null;
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      String s = raw;
      if (!s.endsWith('Z') && !s.contains('+')) s += 'Z';
      return DateTime.tryParse(s)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'status': status,
        'ticketQuantity': ticketQuantity,
        'waitlistPosition': waitlistPosition,
        'paymentDeadline': paymentDeadline?.toIso8601String(),
        'isPaid': isPaid,
        'qrCodeBase64': qrCodeBase64,
        'eventTitle': eventTitle,
        'eventDate': eventDate?.toIso8601String(),
        'eventLocation': eventLocation,
        'eventImageUrl': eventImageUrl,
        'totalAmount': totalAmount,
        'eventDescription': eventDescription,
      };

  BookingModel copyWith({
    String? status,
    int? waitlistPosition,
    DateTime? paymentDeadline,
    bool? isPaid,
    String? qrCodeBase64,
    String? eventTitle,
    DateTime? eventDate,
    String? eventLocation,
    String? eventImageUrl,
    double? totalAmount,
    String? eventDescription,
  }) {
    return BookingModel(
      id: id,
      eventId: eventId,
      status: status ?? this.status,
      ticketQuantity: ticketQuantity,
      waitlistPosition: waitlistPosition ?? this.waitlistPosition,
      paymentDeadline: paymentDeadline ?? this.paymentDeadline,
      isPaid: isPaid ?? this.isPaid,
      qrCodeBase64: qrCodeBase64 ?? this.qrCodeBase64,
      eventTitle: eventTitle ?? this.eventTitle,
      eventDate: eventDate ?? this.eventDate,
      eventLocation: eventLocation ?? this.eventLocation,
      eventImageUrl: eventImageUrl ?? this.eventImageUrl,
      totalAmount: totalAmount ?? this.totalAmount,
      eventDescription: eventDescription ?? this.eventDescription,
    );
  }

  @override
  List<Object?> get props => [
        id,
        eventId,
        status,
        ticketQuantity,
        waitlistPosition,
        paymentDeadline,
        isPaid,
        qrCodeBase64,
        eventTitle,
        eventDate,
        eventLocation,
        eventImageUrl,
        totalAmount,
        eventDescription,
      ];
}
