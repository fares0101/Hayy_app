import 'dart:developer' as dev;
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';

class BookingRemoteDataSource {
  final ApiClient apiClient;

  BookingRemoteDataSource(this.apiClient);

  Future<Map<String, dynamic>> createBooking({
    required String eventId,
    required int ticketQuantity,
  }) async {
    final response = await apiClient.post(
      ApiConstants.eventBookings,
      data: {
        'eventId': eventId,
        'ticketQuantity': ticketQuantity,
      },
    );
    return _ensureMapResponse(response.data);
  }

  Future<Map<String, dynamic>> initiatePayment({
    required String userId,
    required String bookingId,
  }) async {
    final response = await apiClient.post(
      ApiConstants.eventPaymentInitiate,
      data: {
        'userId': userId,
        'bookingId': bookingId,
        // Paymob will redirect to this deep link after payment is complete.
        // The app handles hayy://payment-result?success=true&bookingId=...
        'redirectUrl': 'hayy://payment-result',
      },
    );
    return _ensureMapResponse(response.data);
  }

  Future<dynamic> getMyBookings() async {
    final response = await apiClient.get(ApiConstants.myAllBookings);
    dev.log('=== My All Bookings Response ===', name: 'BookingDS');
    dev.log('${response.data}', name: 'BookingDS');
    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return data;
  }

  Future<dynamic> getBookingById({
    required String bookingId,
  }) async {
    final response = await apiClient.get(
      ApiConstants.eventBookingById.replaceAll('{bookingId}', bookingId),
    );
    
    // ✅ Logging response to debug backend format
    dev.log('=== Polling Response (ByID) ===', name: 'BookingDS');
    dev.log('${response.data}', name: 'BookingDS');
    
    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return data;
  }

  Future<dynamic> getBookingDetails({
    required String eventId,
  }) async {
    final response = await apiClient.get(
      ApiConstants.eventBookingsMyBookings.replaceAll('{eventId}', eventId),
    );
    
    // ✅ Logging response to debug backend format
    dev.log('=== Polling Response ===', name: 'BookingDS');
    dev.log('${response.data}', name: 'BookingDS');
    
    // API may return a List of bookings or a single Map — return raw data
    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return data;
  }

  Future<Map<String, dynamic>> getBookingQR({
    required String bookingId,
  }) async {
    final response = await apiClient.get(
      ApiConstants.eventBookingMyQr.replaceAll('{bookingId}', bookingId),
    );
    // 🔍 Debug: print the raw response so we can see the exact field name
    dev.log('[BookingQR] raw response: ${response.data}', name: 'BookingDS');
    return _ensureMapResponse(response.data);
  }

  Map<String, dynamic> _ensureMapResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw Exception('Unexpected response format from server.');
  }
}
