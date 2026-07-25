import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/themed_top_header.dart';
import '../../../../data/user_app/datasources/places_remote_data_source.dart';
import '../../../../data/user_app/models/booking_model.dart';
import '../../../../injection_container.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../core/utils/image_url_formatter.dart';
import '../booking_bloc.dart';
import '../booking_event.dart';
import '../booking_state.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BookingBloc>()..add(GetMyBookingsEvent()),
      child: const _MyTicketsView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MyTicketsView extends StatelessWidget {
  const _MyTicketsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EE),
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'My Booking',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: BlocBuilder<BookingBloc, BookingState>(
              builder: (context, state) {
                if (state is BookingLoading || state is BookingInitial) {
                  return ShimmerLoading.buildVerticalList(itemCount: 4);
                }
                if (state is BookingError) {
                  return _ErrorView(
                    message: state.message,
                    onRetry: () =>
                        context.read<BookingBloc>().add(GetMyBookingsEvent()),
                  );
                }
                if (state is MyTicketsLoaded) {
                  final bookings = state.tickets;
                  if (bookings.isEmpty) return const _EmptyState();
                  return RefreshIndicator(
                    color: const Color(0xFFFE5D17),
                    onRefresh: () async {
                      context.read<BookingBloc>().add(GetMyBookingsEvent());
                      await Future.delayed(const Duration(milliseconds: 500));
                      HapticFeedback.mediumImpact();
                    },
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 16),
                      itemBuilder: (ctx, i) =>
                          _BookingCard(booking: bookings[i]),
                    ),
                  );
                }
                return const _EmptyState();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booking Card ─────────────────────────────────────────────────────────────

class _BookingCard extends StatefulWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  Map<String, dynamic>? _eventData;
  bool _loadingEvent = false;

  BookingModel get b => widget.booking;

  @override
  void initState() {
    super.initState();
    // If the booking already has event details embedded, no fetch needed
    if (b.eventTitle == null && b.eventId.isNotEmpty) {
      _fetchEventDetails();
    }
  }

  Future<void> _fetchEventDetails() async {
    setState(() => _loadingEvent = true);
    try {
      final ds = sl<PlacesRemoteDataSource>();
      final data = await ds.getEventById(b.eventId);
      if (mounted) setState(() => _eventData = data);
    } catch (e) {
      dev.log('[BookingCard] event fetch failed: $e', name: 'MyTickets');
    } finally {
      if (mounted) setState(() => _loadingEvent = false);
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  String get _title =>
      b.eventTitle ??
      _eventData?['title']?.toString() ??
      _eventData?['name']?.toString() ??
      'Event Booking';

  String get _location =>
      b.eventLocation ??
      _eventData?['location']?.toString() ??
      _eventData?['venue']?.toString() ??
      '';

  String get _imageUrl {
    if (b.eventImageUrl != null && b.eventImageUrl!.isNotEmpty) {
      return ImageUrlFormatter.format(b.eventImageUrl);
    }
    if (_eventData != null) {
      return ImageUrlFormatter.extractFromMap(_eventData!);
    }
    return '';
  }

  DateTime? get _eventDate {
    if (b.eventDate != null) return b.eventDate;
    final raw = _eventData?['date']?.toString() ??
        _eventData?['startDate']?.toString() ??
        _eventData?['eventDate']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      String s = raw;
      if (!s.endsWith('Z') && !s.contains('+')) s += 'Z';
      return DateTime.tryParse(s)?.toLocal();
    } catch (_) {
      return null;
    }
  }

  double? get _price =>
      b.totalAmount ??
      double.tryParse(_eventData?['price']?.toString() ?? '');

  // ── status map ────────────────────────────────────────────────────────────
  Map<String, dynamic> get _status {
    if (b.isConfirmed || b.isPaid) {
      return {
        'label': 'Confirmed',
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF2E7D32),
        'bg': const Color(0xFFE8F5E9),
      };
    }
    if (b.isPending) {
      return {
        'label': 'Awaiting Payment',
        'icon': Icons.payment_rounded,
        'color': const Color(0xFFE65100),
        'bg': const Color(0xFFFFF3E0),
      };
    }
    if (b.isWaitlisted) {
      return {
        'label': 'Waitlisted',
        'icon': Icons.hourglass_top_rounded,
        'color': const Color(0xFF1565C0),
        'bg': const Color(0xFFE3F2FD),
      };
    }
    return {
      'label': 'Cancelled',
      'icon': Icons.cancel_rounded,
      'color': const Color(0xFFB71C1C),
      'bg': const Color(0xFFFBE9E7),
    };
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${dt.day} ${months[dt.month]} ${dt.year}  •  $h:$m $ampm';
  }

  String _formatDeadline(DateTime d) {
    final diff = d.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m left';
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m left';
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final st = _status;
    final statusColor = st['color'] as Color;
    final statusBg = st['bg'] as Color;
    final date = _eventDate;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Event Image Header ───────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: _imageUrl.isNotEmpty
                ? Image.network(
                    _imageUrl,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(_title),
                  )
                : _loadingEvent
                    ? Container(
                        height: 150,
                        color: const Color(0xFFF0EBE4),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFFFE5D17), strokeWidth: 2),
                        ),
                      )
                    : _imagePlaceholder(_title),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status Badge ───────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(st['icon'] as IconData,
                              color: statusColor, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            st['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Booking ID chip
                    if (b.id.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EBE4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${b.id.length > 8 ? b.id.substring(0, 8).toUpperCase() : b.id.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7A6A5A),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Event Title ────────────────────────────────────────────
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 10),
                const Divider(color: Color(0xFFF0EBE4)),
                const SizedBox(height: 10),

                // ── Details Row ────────────────────────────────────────────
                if (date != null) ...[
                  _DetailRow(
                    icon: Icons.calendar_today_rounded,
                    text: _formatDate(date),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_location.isNotEmpty) ...[
                  _DetailRow(
                    icon: Icons.location_on_rounded,
                    text: _location,
                  ),
                  const SizedBox(height: 8),
                ],
                _DetailRow(
                  icon: Icons.confirmation_num_outlined,
                  text:
                      '${b.ticketQuantity} ticket${b.ticketQuantity > 1 ? 's' : ''}',
                ),
                if (_price != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.attach_money_rounded,
                    text: 'Total: EGP ${_price!.toStringAsFixed(0)}',
                  ),
                ],

                // ── Waitlist info ──────────────────────────────────────────
                if (b.isWaitlisted && b.waitlistPosition != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.format_list_numbered_rounded,
                    text: 'Waitlist position: #${b.waitlistPosition}',
                    color: const Color(0xFF1565C0),
                  ),
                ],

                // ── Payment deadline ───────────────────────────────────────
                if (b.isPending && b.paymentDeadline != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFFFCC80), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: Color(0xFFE65100), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Pay within: ${_formatDeadline(b.paymentDeadline!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Action Button ──────────────────────────────────────────
                if (b.isConfirmed || b.isPaid)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFE7A2A), Color(0xFFFE5D17)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            _showTicketSheet(context);
                          },
                          child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.qr_code_2_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'View Ticket QR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(String title) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFE5D17), Color(0xFF98380E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_rounded, color: Colors.white54, size: 48),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── QR Bottom Sheet ───────────────────────────────────────────────────────
  void _showTicketSheet(BuildContext context) {
    final qr = b.qrCodeBase64;
    if (qr == null || qr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR code not available yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketSheet(booking: b, title: _title),
    );
  }
}

// ── Detail row helper ─────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.text,
    this.color = const Color(0xFF5A5A5A),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ticket Bottom Sheet ───────────────────────────────────────────────────────
class _TicketSheet extends StatelessWidget {
  final BookingModel booking;
  final String title;

  const _TicketSheet({required this.booking, required this.title});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    return Container(
      height: screenH * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 20),

          // Header gradient strip
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFE7A2A), Color(0xFFFE5D17)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.confirmation_num_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${booking.ticketQuantity} ticket${booking.ticketQuantity > 1 ? 's' : ''}  •  Confirmed ✓',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // QR Code
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF7F5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFE5D17).withValues(alpha: 0.2),
                          width: 1.5),
                    ),
                    child: _buildQR(),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F2EE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _SheetDetailRow(
                          label: 'Booking ID',
                          value: booking.id.isNotEmpty
                              ? booking.id.toUpperCase()
                              : '—',
                        ),
                        const SizedBox(height: 8),
                        _SheetDetailRow(
                          label: 'Tickets',
                          value:
                              '${booking.ticketQuantity} ticket${booking.ticketQuantity > 1 ? 's' : ''}',
                        ),
                        const SizedBox(height: 8),
                        _SheetDetailRow(
                          label: 'Status',
                          value: booking.status,
                          valueColor: const Color(0xFF2E7D32),
                        ),
                        if (booking.totalAmount != null) ...[
                          const SizedBox(height: 8),
                          _SheetDetailRow(
                            label: 'Total Paid',
                            value:
                                'EGP ${booking.totalAmount!.toStringAsFixed(0)}',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Show this QR code at the entrance',
                    style: TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE0D8D0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(color: Color(0xFF4A4A4A))),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQR() {
    final qr = booking.qrCodeBase64!;
    final b64 = qr.contains(',') ? qr.split(',').last : qr;
    try {
      final bytes = base64Decode(b64);
      return Image.memory(bytes,
          width: double.infinity,
          height: 240,
          fit: BoxFit.contain);
    } catch (_) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: Icon(Icons.qr_code_2_rounded,
              size: 120, color: Color(0xFFFE5D17)),
        ),
      );
    }
  }
}

class _SheetDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SheetDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A8A))),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0E8),
              ),
              child: const Center(
                child: Icon(Icons.confirmation_num_outlined,
                    size: 52, color: Color(0xFFFE5D17)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Bookings Yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your event bookings will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: Color(0xFF9A9A9A), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 64, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF7A7A7A), fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFE5D17),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
