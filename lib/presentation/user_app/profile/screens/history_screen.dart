import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../../../../core/widgets/themed_top_header.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../injection_container.dart';
import '../../../../data/user_app/datasources/booking_remote_data_source.dart';
import '../../../../data/user_app/models/booking_model.dart';

/// History screen shows all past booking activity (all statuses) as
/// a timeline of the user's event participation history.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<BookingModel>> _historyFuture;
  late final BookingRemoteDataSource _dataSource;

  @override
  void initState() {
    super.initState();
    _dataSource = sl<BookingRemoteDataSource>();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = _fetchHistory();
    });
  }

  Future<List<BookingModel>> _fetchHistory() async {
    try {
      // Use the same /api/EventBookings/my-bookings endpoint and show ALL statuses
      final dynamic rawData = await _dataSource.getMyBookings();
      dev.log('[History] raw: $rawData', name: 'HistoryScreen');
      List<BookingModel> bookings = [];

      if (rawData is List) {
        bookings = rawData
            .map((e) => BookingModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } else if (rawData is Map<String, dynamic>) {
        final items = rawData['items'] ?? rawData['data'] ?? rawData['result'];
        if (items is List) {
          bookings = items
              .map((e) => BookingModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        } else if (rawData.containsKey('id') || rawData.containsKey('bookingId')) {
          bookings = [BookingModel.fromJson(rawData)];
        }
      }

      // Sort: most recent first (using id as proxy if no date field)
      return bookings.reversed.toList();
    } catch (e) {
      dev.log('[History] error: $e', name: 'HistoryScreen');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EE),
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'History Event Booking',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: FutureBuilder<List<BookingModel>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ShimmerLoading.buildVerticalList(itemCount: 6);
                }

                if (snapshot.hasError) {
                  return _buildErrorState();
                }

                final history = snapshot.data ?? [];

                if (history.isEmpty) {
                  return _buildEmptyState();
                }

                return RefreshIndicator(
                  color: const Color(0xFFFE5D17),
                  onRefresh: () async => _loadHistory(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildHistoryCard(history[index], index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 64, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 16),
          const Text(
            'Could not load history',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFE5D17),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history_rounded, size: 100, color: Color(0xFFB0B0B0)),
          SizedBox(height: 16),
          Text(
            'No booking history yet.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E2E2E),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start booking events to see your history!',
            style: TextStyle(fontSize: 14, color: Color(0xFF8A8A8A)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BookingModel booking, int index) {
    final statusInfo = _statusInfo(booking);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status icon circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusInfo['bg'] as Color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusInfo['icon'] as IconData,
              color: statusInfo['color'] as Color,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Booking',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${booking.ticketQuantity} ticket${booking.ticketQuantity > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF7A7A7A)),
                ),
                const SizedBox(height: 4),
                if (booking.isWaitlisted && booking.waitlistPosition != null)
                  Text(
                    'Waitlist position: #${booking.waitlistPosition}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF7A7A7A)),
                  ),
                if (booking.isPending && booking.paymentDeadline != null)
                  Text(
                    'Payment deadline: ${_formatDeadline(booking.paymentDeadline!)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFE65100)),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusInfo['bg'] as Color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusInfo['label'] as String,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: statusInfo['color'] as Color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _statusInfo(BookingModel booking) {
    if (booking.isConfirmed || booking.isPaid) {
      return {
        'bg': const Color(0xFFE8F5E9),
        'color': const Color(0xFF2E7D32),
        'icon': Icons.check_circle_outline_rounded,
        'label': 'Confirmed',
      };
    }
    if (booking.isPending) {
      return {
        'bg': const Color(0xFFFFF3E0),
        'color': const Color(0xFFE65100),
        'icon': Icons.payment_rounded,
        'label': 'Pending',
      };
    }
    if (booking.isWaitlisted) {
      return {
        'bg': const Color(0xFFE3F2FD),
        'color': const Color(0xFF1565C0),
        'icon': Icons.hourglass_top_rounded,
        'label': 'Waitlisted',
      };
    }
    return {
      'bg': const Color(0xFFFBE9E7),
      'color': const Color(0xFFB71C1C),
      'icon': Icons.cancel_outlined,
      'label': 'Cancelled',
    };
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) return 'Expired';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m left';
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m left';
  }
}
