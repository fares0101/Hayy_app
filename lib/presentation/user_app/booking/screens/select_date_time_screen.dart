import 'package:flutter/material.dart';
import '../../../../core/widgets/themed_top_header.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../discovery/discovery_list_page.dart';
import 'payment_method_screen.dart';
import '../../../../core/utils/image_url_formatter.dart';

class SelectDateTimeScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final DiscoveryListItem? item;

  const SelectDateTimeScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    this.item,
  });

  @override
  State<SelectDateTimeScreen> createState() => _SelectDateTimeScreenState();
}

class _SelectDateTimeScreenState extends State<SelectDateTimeScreen>
    with SingleTickerProviderStateMixin {
  int _seats = 1;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  double _parseUnitPrice() {
    final priceStr = widget.item?.priceText ?? widget.item?.accentText ?? '';
    final numMatch = RegExp(r'(\d+)').firstMatch(priceStr);
    if (numMatch != null) {
      return double.tryParse(numMatch.group(1)!) ?? 150.0;
    }
    return 150.0;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final unitPrice = _parseUnitPrice();
    final totalPrice = unitPrice * _seats;

    final title = item?.title ?? widget.eventTitle;
    final subtitle = item?.subtitle ?? 'Upcoming Event';
    final dateText = item?.dateText ?? item?.detailLine ?? 'Date upcoming';
    final timeText = item?.timeText ?? '08:00 PM';
    final locationText = item?.locationText ?? '';
    final imageUrl = ImageUrlFormatter.format(item?.imageUrl);
    final ticketCountText = item?.ticketCountText ?? 'Tickets Available';
    final priceText = item?.priceText ?? '${unitPrice.toInt()} EGP';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Book Tickets',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      const Text(
                        'Event Summary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F1F1F),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Animated Event Poster Card
                      Hero(
                        tag: 'event_poster_${widget.eventId}',
                        child: Material(
                          color: Colors.white,
                          elevation: 4,
                          shadowColor: const Color(0x24000000),
                          borderRadius: BorderRadius.circular(22),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image with badges
                                Stack(
                                  children: [
                                    if (imageUrl.isNotEmpty)
                                      Image.network(
                                        imageUrl,
                                        width: double.infinity,
                                        height: 180,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _buildFallbackImage(),
                                      )
                                    else
                                      _buildFallbackImage(),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.1),
                                              Colors.transparent,
                                              Colors.black.withOpacity(0.6),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Availability Badge
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.65),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.25)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.local_activity_rounded,
                                              color: Color(0xFFFFB08A),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              ticketCountText,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Price Badge
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFE5D17),
                                              Color(0xFFFF8C53)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x40FE5D17),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          priceText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Event Details
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 18.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E1E1E),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        subtitle,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF7F3),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: const Color(0xFFFFDFD0)),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.calendar_month_rounded,
                                                  size: 18,
                                                  color: Color(0xFFFE5D17),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    dateText,
                                                    style: const TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF2E2E2E),
                                                    ),
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.access_time_rounded,
                                                  size: 18,
                                                  color: Color(0xFFFE5D17),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  timeText,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2E2E2E),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (locationText.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on_rounded,
                                                    size: 18,
                                                    color: Color(0xFFFE5D17),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      locationText,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Color(0xFF666666),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Ticket Counter Card (Located directly under poster!)
                      const Text(
                        'Number of Tickets',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F1F1F),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0EA),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.confirmation_number_rounded,
                                    color: Color(0xFFFE5D17),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Select Tickets',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E1E1E),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${unitPrice.toInt()} EGP per ticket',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Stepper Control (- / +)
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF6F6F8),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                        color: const Color(0xFFE5E5E5)),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        borderRadius: BorderRadius.circular(30),
                                        onTap: () {
                                          if (_seats > 1) {
                                            setState(() => _seats--);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _seats > 1
                                                ? const Color(0xFFFE5D17)
                                                : Colors.grey.shade300,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.remove,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          '$_seats',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E1E1E),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(30),
                                        onTap: () {
                                          if (_seats < 10) {
                                            setState(() => _seats++);
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFE5D17),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1),

                            // Total Price Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Price',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF555555),
                                  ),
                                ),
                                Text(
                                  '${totalPrice.toInt()} EGP',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFE5D17),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Continue Button
                      CustomButton(
                        text: 'Continue to Payment',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentMethodScreen(
                                eventId: widget.eventId,
                                eventTitle: widget.eventTitle,
                                ticketQuantity: _seats,
                              ),
                            ),
                          );
                        },
                        borderRadius: 999,
                        height: 52,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      height: 180,
      color: const Color(0xFFE5E5E5),
      alignment: Alignment.center,
      child: const Icon(
        Icons.confirmation_number_outlined,
        color: Color(0xFF999999),
        size: 50,
      ),
    );
  }
}
