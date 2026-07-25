import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/widgets/custom_button.dart';

import '../../../app_router.dart';
import '../../../core/widgets/themed_top_header.dart';
import '../../../core/utils/image_url_formatter.dart';

enum DiscoveryPageKind { place, event, offer }

class PlaceCollectionRouteArgs {
  final List<String> placeIds;

  const PlaceCollectionRouteArgs({
    this.placeIds = const [],
  });
}

class EventDateTimeResult {
  final String dateText;
  final String timeText;
  final DateTime? dateTime;

  const EventDateTimeResult({
    required this.dateText,
    required this.timeText,
    this.dateTime,
  });
}

class DiscoveryListItem {
  final String id;
  final String title;
  final String subtitle;
  final String detailLine;
  final String accentText;
  final String footerLinkLabel;
  final String imageUrl;
  final String actionLabel;
  final double? rating;
  final String? actionRoute;
  final Object? actionArguments;
  final String? dateText;
  final String? timeText;
  final String? ticketCountText;
  final String? priceText;
  final String? locationText;
  final bool isSoldOut;
  final Map<String, dynamic>? rawData;

  const DiscoveryListItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detailLine,
    required this.accentText,
    required this.footerLinkLabel,
    required this.imageUrl,
    required this.actionLabel,
    this.rating,
    this.actionRoute,
    this.actionArguments,
    this.dateText,
    this.timeText,
    this.ticketCountText,
    this.priceText,
    this.locationText,
    this.isSoldOut = false,
    this.rawData,
  });
}

class DiscoveryListPage extends StatelessWidget {
  final String title;
  final DiscoveryPageKind pageKind;
  final List<DiscoveryListItem> items;
  final String unavailableActionMessage;
  final String emptyMessage;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final void Function(BuildContext context, DiscoveryListItem item)?
      onPrimaryAction;
  final void Function(BuildContext context, DiscoveryListItem item)?
      onSecondaryAction;

  const DiscoveryListPage({
    super.key,
    required this.title,
    required this.pageKind,
    required this.items,
    required this.unavailableActionMessage,
    this.emptyMessage = 'No items available right now.',
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.onPrimaryAction,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: Column(
        children: [
          ThemedTopHeader(
            title: title,
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) {
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final imageHeight =
              pageKind == DiscoveryPageKind.event ? 112.0 : 104.0;
          return Material(
            color: Colors.white,
            elevation: 1.5,
            shadowColor: const Color(0x14000000),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Shimmer.fromColors(
                baseColor: Colors.grey.shade200,
                highlightColor: Colors.grey.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: imageHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 150,
                      height: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 130,
                      height: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 12,
                          color: Colors.white,
                        ),
                        const Spacer(),
                        Container(
                          width: 90,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (errorMessage != null) {
      return _DiscoveryStateView(
        message: errorMessage!,
        buttonLabel: 'Retry',
        onPressed: onRetry,
      );
    }

    if (items.isEmpty) {
      return _DiscoveryStateView(
        message: emptyMessage,
        buttonLabel: onRetry != null ? 'Refresh' : null,
        onPressed: onRetry,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) => DiscoveryCard(
        item: items[index],
        pageKind: pageKind,
        onPrimaryAction: () => _handlePrimaryAction(context, items[index]),
        onSecondaryAction: () => _handleSecondaryAction(context, items[index]),
      ),
    );
  }

  void _handlePrimaryAction(BuildContext context, DiscoveryListItem item) {
    if (onPrimaryAction != null) {
      onPrimaryAction!(context, item);
      return;
    }

    if (item.actionRoute != null) {
      Navigator.pushNamed(
        context,
        item.actionRoute!,
        arguments: item.actionArguments ?? item.id,
      );
      return;
    }

    _showMessage(context, unavailableActionMessage);
  }

  void _handleSecondaryAction(BuildContext context, DiscoveryListItem item) {
    if (onSecondaryAction != null) {
      onSecondaryAction!(context, item);
      return;
    }

    _showMessage(
      context,
      '${item.title} details will be completed from the API.',
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

/// Maps raw API response maps to [DiscoveryListItem] objects.
class DiscoveryDataMapper {
  static DiscoveryListItem fromPlace(
    Map<String, dynamic> map, {
    String fallbackSubtitle = 'Place',
  }) {
    final id = _firstString(map, const ['id', 'placeId'], fallback: 'place');
    final title = _firstString(
      map,
      const ['name', 'title', 'placeName'],
      fallback: 'Place',
    );
    final subtitle = _firstString(
      map,
      const [
        'categoryName',
        'type',
        'placeType',
        'mainCategory',
        'subcategory',
      ],
      fallback: fallbackSubtitle,
    );
    final detailLine = _buildPlaceDetailLine(map);
    final accentText = _firstString(
      map,
      const ['description', 'tagline', 'status', 'about'],
      fallback: 'Tap view to open details.',
    );

    return DiscoveryListItem(
      id: id,
      title: title,
      subtitle: subtitle,
      detailLine: detailLine,
      accentText: accentText,
      footerLinkLabel: 'Open details',
      imageUrl: _extractImageUrl(map),
      actionLabel: 'View',
      rating: _firstDouble(map, const ['rating', 'averageRating', 'rate']),
      actionRoute: AppRoutes.placeDetails,
      actionArguments: id,
    );
  }

  static DiscoveryListItem fromOffer(Map<String, dynamic> map) {
    final id = _firstString(
      map,
      const ['offerId', 'id'],
      fallback: 'offer',
    );
    final discount = _formatDiscount(
      _firstValue(map, const [
        'discount',
        'badge',
        'discountPercentage',
        'discountRate',
      ]),
    );

    // Check gallery/offer-specific images FIRST before generic imageUrl.
    final imageUrlVal = _extractImageUrlPrioritizingGallery(map);

    debugPrint("========== MAPPER DEBUG (OFFER) ==========");
    debugPrint("Item ID = $id");
    debugPrint("map['imageUrl'] = ${map['imageUrl']}");
    debugPrint("map['image'] = ${map['image']}");
    debugPrint("map['coverImage'] = ${map['coverImage']}");
    debugPrint(
        "map['galleryImages'] = ${map['galleryImages'] ?? map['GalleryImages']}");
    debugPrint("Final DiscoveryListItem.imageUrl = $imageUrlVal");
    debugPrint("==========================================");

    // Enrich the map with pre-extracted image so offer_details_page can find it
    final enrichedMap = <String, dynamic>{
      ...map,
      if (imageUrlVal.isNotEmpty) 'image': imageUrlVal,
    };

    return DiscoveryListItem(
      id: id,
      title: _firstString(
        map,
        const ['title', 'offerTitle', 'name'],
        fallback: 'Offer',
      ),
      subtitle: _firstString(
        map,
        const ['placeName', 'categoryName', 'type'],
        fallback: 'Active offer',
      ),
      detailLine: _buildOfferDetailLine(map),
      accentText: discount.isEmpty
          ? _firstString(
              map,
              const ['description', 'shortDescription', 'details'],
              fallback: 'Limited time offer',
            )
          : discount,
      footerLinkLabel: 'See details',
      imageUrl: imageUrlVal,
      actionLabel: 'View',
      actionRoute: AppRoutes.offerDetails,
      actionArguments: enrichedMap,
      rawData: enrichedMap,
    );
  }

  static DiscoveryListItem fromEvent(Map<String, dynamic> map) {
    final id = _firstString(
      map,
      const ['eventId', 'id'],
      fallback: 'event',
    );

    // Check gallery/event-specific images FIRST before generic imageUrl
    String imageUrlVal = _extractImageUrlPrioritizingGallery(map);

    debugPrint("========== MAPPER DEBUG (EVENT) ==========");
    debugPrint("Item ID = $id");
    debugPrint("map['imageUrl'] = ${map['imageUrl']}");
    debugPrint("map['image'] = ${map['image']}");
    debugPrint("map['coverImage'] = ${map['coverImage']}");
    debugPrint(
        "map['galleryImages'] = ${map['galleryImages'] ?? map['GalleryImages']}");
    debugPrint("Final DiscoveryListItem.imageUrl = $imageUrlVal");
    debugPrint("==========================================");

    final title = _firstString(
      map,
      const ['name', 'title', 'eventName'],
      fallback: 'Event',
    );
    final subtitle = _firstString(
      map,
      const ['categoryName', 'type', 'eventType'],
      fallback: 'Upcoming Event',
    );
    final location = _firstString(
      map,
      const ['address', 'location', 'venue', 'placeName', 'city'],
    );

    // Extract Real Date & Time from Database
    final eventDateTime = _extractRealEventDateTime(map);
    final formattedDate = eventDateTime.dateText;
    final formattedTime = eventDateTime.timeText;

    final detailLine = [
      if (formattedDate.isNotEmpty) formattedDate,
      if (formattedTime.isNotEmpty) formattedTime,
    ].join(' • ');

    // Ticket Price
    final rawPrice = _firstValue(
        map, const ['price', 'entryPrice', 'ticketPrice', 'priceRange']);
    String priceText = 'Free Entry';
    if (rawPrice != null) {
      final pStr = rawPrice.toString().trim();
      if (pStr.isNotEmpty && pStr != '0' && pStr.toLowerCase() != 'free') {
        priceText = '$pStr EGP';
      }
    }

    // Ticket Availability & Sold Out Check
    bool isSoldOut = false;
    String ticketCountText = 'Tickets Available';

    final isSoldOutVal = _firstValue(map, const [
      'isSoldOut',
      'soldOut',
      'isFull',
    ]);
    if (isSoldOutVal != null) {
      if (isSoldOutVal == true ||
          isSoldOutVal.toString().toLowerCase() == 'true' ||
          isSoldOutVal == 1) {
        isSoldOut = true;
      }
    }

    final isAvailableVal = _firstValue(map, const [
      'isAvailable',
      'available',
      'hasTickets',
      'canBook',
      'hasAvailableTickets',
    ]);
    if (isAvailableVal != null) {
      if (isAvailableVal == false ||
          isAvailableVal.toString().toLowerCase() == 'false' ||
          isAvailableVal == 0) {
        isSoldOut = true;
      }
    }

    final statusVal = _firstString(
      map,
      const ['status', 'eventStatus', 'bookingStatus', 'ticketStatus'],
    ).toLowerCase();

    if (statusVal == 'sold_out' ||
        statusVal == 'soldout' ||
        statusVal == 'full' ||
        statusVal == 'completed' ||
        statusVal == 'unavailable' ||
        statusVal == 'ended' ||
        statusVal == 'expired') {
      isSoldOut = true;
    }

    final rawTickets = _firstValue(map, const [
      'availableTickets',
      'remainingTickets',
      'ticketsRemaining',
      'availableSeats',
      'ticketCount',
      'tickets',
      'totalTickets',
      'seats',
    ]);

    if (rawTickets != null) {
      final numVal = num.tryParse(rawTickets.toString().trim());
      if (numVal != null) {
        if (numVal <= 0) {
          isSoldOut = true;
          ticketCountText = 'Sold Out';
        } else {
          ticketCountText = '$numVal Tickets Available';
        }
      } else {
        final tStr = rawTickets.toString().trim();
        if (tStr.toLowerCase().contains('sold out') ||
            tStr.toLowerCase().contains('full') ||
            tStr == '0') {
          isSoldOut = true;
          ticketCountText = 'Sold Out';
        } else if (tStr.isNotEmpty) {
          ticketCountText = '$tStr Tickets Remaining';
        }
      }
    }

    if (isSoldOut) {
      ticketCountText = 'Sold Out';
    }

    return DiscoveryListItem(
      id: id,
      title: title,
      subtitle: subtitle,
      detailLine: detailLine.isNotEmpty ? detailLine : 'Upcoming Event',
      accentText: priceText,
      footerLinkLabel: 'Open details',
      imageUrl: imageUrlVal,
      actionLabel: isSoldOut ? 'Sold Out' : 'Booking',
      dateText: formattedDate,
      timeText: formattedTime,
      ticketCountText: ticketCountText,
      priceText: priceText,
      locationText: location,
      isSoldOut: isSoldOut,
      rawData: map,
    );
  }

  static EventDateTimeResult _extractRealEventDateTime(
      Map<String, dynamic> map) {
    final candidateDateKeys = [
      'eventDate',
      'startDate',
      'date',
      'startsAt',
      'eventDateTime',
      'dateTime',
      'createdDate',
      'createdAt',
      'time',
      'startTime',
    ];

    final rawDateVal = _firstValue(map, candidateDateKeys);
    DateTime? dt = _parseEventDate(rawDateVal);

    String dateText = '';
    String timeText = '';

    if (dt != null) {
      final localDt = dt.toLocal();
      dateText = _formatFullEventDate(localDt);
      timeText = _formatEventTimeOnly(localDt);
    }

    // Separate time string lookup (e.g. "20:30:00" or "08:30 PM")
    final rawTimeStr = _firstString(
      map,
      const ['time', 'startTime', 'startsAt', 'eventTime', 'timeStr'],
    );
    if (rawTimeStr.isNotEmpty) {
      final formattedFromRaw = _formatTimeString(rawTimeStr);
      if (formattedFromRaw.isNotEmpty) {
        timeText = formattedFromRaw;
      }
    }

    // Fallback date string if dt parsing failed
    if (dateText.isEmpty) {
      final rawDateStr = _firstString(
        map,
        const [
          'eventDate',
          'date',
          'startDate',
          'startsAt',
          'createdDate',
          'createdAt'
        ],
      );
      if (rawDateStr.isNotEmpty) {
        final cleanPart = rawDateStr.split('T').first.split(' ').first;
        final candidateDt = DateTime.tryParse(cleanPart);
        if (candidateDt != null) {
          dateText = _formatFullEventDate(candidateDt);
        } else {
          dateText = rawDateStr;
        }
      }
    }

    // Deep fallback: scan map values for any ISO date pattern (YYYY-MM-DD)
    if (dateText.isEmpty) {
      for (final entry in map.entries) {
        final valStr = entry.value?.toString() ?? '';
        if (RegExp(r'\d{4}-\d{2}-\d{2}').hasMatch(valStr)) {
          final match =
              RegExp(r'\d{4}-\d{2}-\d{2}(?:[T\s]\d{2}:\d{2}:?\d{0,2})?')
                  .firstMatch(valStr);
          if (match != null) {
            final parsed = _parseEventDate(match.group(0));
            if (parsed != null) {
              dateText = _formatFullEventDate(parsed.toLocal());
              if (timeText.isEmpty) {
                timeText = _formatEventTimeOnly(parsed.toLocal());
              }
              break;
            }
          }
        }
      }
    }

    return EventDateTimeResult(
      dateText: dateText,
      timeText: timeText,
      dateTime: dt,
    );
  }

  static DateTime? _parseEventDate(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) return date;
    String text = date.toString().trim();
    if (text.isEmpty) return null;

    if (text.contains(' ') && !text.contains('T')) {
      text = text.replaceFirst(' ', 'T');
    }

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    if (!text.endsWith('Z') && !text.contains('+')) {
      final parsedUtc = DateTime.tryParse('${text}Z');
      if (parsedUtc != null) return parsedUtc;
    }

    return null;
  }

  static String _formatFullEventDate(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final dayName = days[dt.weekday - 1];
    final monthName = months[dt.month - 1];
    return '$dayName, ${dt.day} $monthName ${dt.year}';
  }

  static String _formatEventTimeOnly(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final hourStr = hour.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr $period';
  }

  static String _formatTimeString(String input) {
    final clean = input.trim();
    if (clean.isEmpty) return '';

    if (clean.toUpperCase().contains('AM') ||
        clean.toUpperCase().contains('PM')) {
      return clean;
    }

    final timeMatch =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?').firstMatch(clean);
    if (timeMatch != null) {
      int hour = int.tryParse(timeMatch.group(1)!) ?? 0;
      final minute = timeMatch.group(2)!;
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final hourStr = formattedHour.toString().padLeft(2, '0');
      return '$hourStr:$minute $period';
    }

    return clean;
  }

  static String _buildPlaceDetailLine(Map<String, dynamic> map) {
    final explicitPrice = _firstString(
      map,
      const ['priceRange', 'minimumCharge', 'entryPrice'],
    );
    if (explicitPrice.isNotEmpty) {
      return explicitPrice;
    }

    final location = _firstString(
      map,
      const ['address', 'location', 'city', 'district'],
    );
    if (location.isNotEmpty) {
      return location;
    }

    return _firstString(
      map,
      const ['workingHours', 'openHours'],
      fallback: 'Available now',
    );
  }

  static String _buildOfferDetailLine(Map<String, dynamic> map) {
    final validUntil = _formatDate(
      _firstValue(map, const ['validUntil', 'endDate', 'expiryDate']),
    );
    if (validUntil.isNotEmpty) {
      return 'Valid until $validUntil';
    }

    return _firstString(
      map,
      const ['description', 'shortDescription', 'details'],
      fallback: 'Active offer',
    );
  }

  static dynamic _firstValue(Map<String, dynamic> map, List<String> keys) {
    if (map.isEmpty) return null;

    // 1. Exact key lookup
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        return value;
      }
    }

    // 2. Case-insensitive lookup against map keys
    final lowerMap = <String, String>{};
    for (final k in map.keys) {
      lowerMap[k.toLowerCase()] = k;
    }

    for (final key in keys) {
      final actualKey = lowerMap[key.toLowerCase()];
      if (actualKey != null && map[actualKey] != null) {
        return map[actualKey];
      }
    }

    // 3. Nested Candidates
    final nestedCandidates = <dynamic>[
      map['data'],
      map['Data'],
      map['result'],
      map['Result'],
      map['place'],
      map['Place'],
      map['offer'],
      map['Offer'],
      map['event'],
      map['Event'],
      map['item'],
      map['Item'],
      map['payload'],
      map['Payload'],
    ];

    for (final candidate in nestedCandidates) {
      if (candidate is Map) {
        final nested = Map<String, dynamic>.from(candidate);
        final found = _firstValue(nested, keys);
        if (found != null) {
          return found;
        }
      }
    }

    return null;
  }

  static String _firstString(
    Map<String, dynamic> map,
    List<String> keys, {
    String fallback = '',
  }) {
    final value = _firstValue(map, keys);
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static double? _firstDouble(Map<String, dynamic> map, List<String> keys) {
    final value = _firstValue(map, keys);
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString().trim());
  }

  /// Priority-based image extraction:
  /// Gallery images → Event-specific → Offer-specific → Cover/Banner → Generic imageUrl → Place fallback
  static String _extractImageUrlPrioritizingGallery(Map<String, dynamic> map) {
    // 0. Pre-processed keys: if 'image'/'imageUrl'/'coverImage' already holds a
    //    fully-resolved HTTP URL (set by _enrichItemsWithPlaceDetails), use it
    //    directly without re-processing raw webpage links.
    for (final key in ['image', 'imageUrl', 'coverImage']) {
      final val = map[key];
      if (val is String && val.trim().isNotEmpty) {
        final v = val.trim().toLowerCase();
        // Accept any http URL that is NOT a raw Unsplash/Pexels webpage link
        if (v.startsWith('http') &&
            !v.contains('unsplash.com/photos/') &&
            !v.contains('unsplash.com/fotos/') &&
            !v.contains('pexels.com/photo/')) {
          debugPrint('[IMG_EXTRACT] Pre-processed key "$key" -> "$val"');
          return val.trim();
        }
      }
    }

    // 1. Gallery images (formatted via ImageUrlFormatter)
    for (final key in [
      'GalleryImages',
      'galleryImages',
      'gallery_images',
      'galleryImage',
      'gallery_image',
      'galleryImageUrl',
      'gallery_image_url',
      'galleryImagePath',
      'gallery_image_path',
      'galleryUrl',
      'gallery_url',
      'galleryPath',
      'gallery_path',
      'gallery',
    ]) {
      final val = map[key];
      if (val != null) {
        final formatted = ImageUrlFormatter.format(val);
        if (formatted.isNotEmpty) {
          debugPrint("[IMG_EXTRACT] Gallery key '$key' -> '$formatted'");
          return formatted;
        }
      }
    }

    // 2. Event-specific image keys
    for (final key in [
      'eventGalleryImages',
      'event_gallery_images',
      'eventGallery',
      'event_gallery',
      'eventImages',
      'event_images',
      'eventPhotos',
      'event_photos',
      'eventImageUrl',
      'event_image_url',
      'eventImage',
      'event_image',
      'eventImagePath',
      'event_image_path',
      'eventPoster',
      'event_poster',
      'eventPosterUrl',
      'event_poster_url',
      'eventCover',
      'event_cover',
      'eventBanner',
      'event_banner',
    ]) {
      final val = map[key];
      if (val != null) {
        final formatted = ImageUrlFormatter.format(val);
        if (formatted.isNotEmpty) {
          debugPrint("[IMG_EXTRACT] Event key '$key' -> '$formatted'");
          return formatted;
        }
      }
    }

    // 3. Offer-specific image keys
    for (final key in [
      'offerGalleryImages',
      'offer_gallery_images',
      'offerGallery',
      'offer_gallery',
      'offerImages',
      'offer_images',
      'offerPhotos',
      'offer_photos',
      'offerImageUrl',
      'offer_image_url',
      'offerImage',
      'offer_image',
      'offerImagePath',
      'offer_image_path',
      'offerPhotoUrl',
      'offer_photo_url',
      'offerPhoto',
      'offer_photo',
      'offerPictureUrl',
      'offer_picture_url',
      'offerPicture',
      'offer_picture',
      'offerCoverUrl',
      'offer_cover_url',
      'offerCover',
      'offer_cover',
      'offerBannerUrl',
      'offer_banner_url',
      'offerBanner',
      'offer_banner',
      'offerMediaUrl',
      'offer_media_url',
      'offerMedia',
      'offer_media',
      'offerFileUrl',
      'offer_file_url',
      'offerFile',
      'offer_file',
      'offerAttachmentUrl',
      'offer_attachment_url',
      'offerAttachment',
      'offer_attachment',
      'discountImageUrl',
      'discount_image_url',
      'discountImage',
      'discount_image',
      'discountBanner',
      'discount_banner',
      'promotionImageUrl',
      'promotion_image_url',
      'promotionImage',
      'promotion_image',
      'promotionBanner',
      'promotion_banner',
      'dealImageUrl',
      'deal_image_url',
      'dealImage',
      'deal_image',
      'couponImageUrl',
      'coupon_image_url',
      'couponImage',
      'coupon_image',
    ]) {
      final val = map[key];
      if (val != null) {
        final formatted = ImageUrlFormatter.format(val);
        if (formatted.isNotEmpty) {
          debugPrint("[IMG_EXTRACT] Offer key '$key' -> '$formatted'");
          return formatted;
        }
      }
    }

    // 4. Cover / Banner / Poster / Main Image Keys
    for (final key in [
      'CoverImage',
      'coverImage',
      'cover_image',
      'Cover',
      'cover',
      'CoverUrl',
      'coverUrl',
      'cover_url',
      'CoverPath',
      'coverPath',
      'cover_path',
      'posterUrl',
      'poster_url',
      'posterPath',
      'poster_path',
      'posterImage',
      'poster_image',
      'poster',
      'bannerUrl',
      'banner_url',
      'bannerPath',
      'banner_path',
      'bannerImage',
      'banner_image',
      'banner',
      'mainImage',
      'main_image',
      'mainImageUrl',
      'main_image_url',
      'cardImage',
      'card_image',
      'cardImageUrl',
      'card_image_url',
    ]) {
      final val = map[key];
      if (val != null) {
        final formatted = ImageUrlFormatter.format(val);
        if (formatted.isNotEmpty) {
          debugPrint("[IMG_EXTRACT] Cover key '$key' -> '$formatted'");
          return formatted;
        }
      }
    }

    // 5. Generic imageUrl / image keys (may contain stale data, used as fallback)
    for (final key in [
      'imageUrl',
      'image_url',
      'imagePath',
      'image_path',
      'image',
      'photoUrl',
      'photo_url',
      'photoPath',
      'photo_path',
      'photo',
      'pictureUrl',
      'picture_url',
      'picturePath',
      'picture_path',
      'picture',
      'mediaUrl',
      'media_url',
      'mediaPath',
      'media_path',
      'media',
      'fileUrl',
      'file_url',
      'filePath',
      'file_path',
      'file',
      'url',
      'path',
      'src',
      'link',
      'uri',
      'attachments',
      'images',
      'imageUrls',
      'image_urls',
      'photos',
      'pictures',
      'files',
      'thumbnail',
      'thumbnailUrl',
      'thumbnail_url',
      'thumbnailPath',
      'thumbnail_path',
    ]) {
      final val = map[key];
      if (val != null) {
        final formatted = ImageUrlFormatter.format(val);
        if (formatted.isNotEmpty) {
          debugPrint("[IMG_EXTRACT] Generic key '$key' -> '$formatted'");
          return formatted;
        }
      }
    }

    // 6. Full ImageUrlFormatter.extractFromMap for any remaining candidate keys
    if (map.isNotEmpty) {
      final itemImg = ImageUrlFormatter.extractFromMap(map);
      if (itemImg.isNotEmpty) {
        debugPrint("[IMG_EXTRACT] extractFromMap -> '$itemImg'");
        return itemImg;
      }
    }

    // 7. Fallback to place/venue/business image if item has no image of its own
    for (final placeKey in [
      'place',
      'targetPlace',
      'business',
      'venue',
      'publisher'
    ]) {
      final placeObj = map[placeKey];
      if (placeObj is Map) {
        final placeMap = Map<String, dynamic>.from(placeObj);
        for (final key in [
          'CoverImage',
          'coverImage',
          'cover_image',
          'Cover',
          'cover',
          'galleryImages',
          'GalleryImages',
          'imageUrl',
          'image_url',
          'image',
          'photo',
          'logo',
          'avatar',
          'placeImageUrl',
          'place_image_url',
          'placeImage',
          'place_image',
          'businessLogo',
          'business_logo',
        ]) {
          final val = placeMap[key];
          if (val != null) {
            final formatted = ImageUrlFormatter.format(val);
            if (formatted.isNotEmpty) {
              debugPrint(
                  "[IMG_EXTRACT] Place fallback key '$key' -> '$formatted'");
              return formatted;
            }
          }
        }
        // Last resort: extractFromMap on place data
        final placeExtracted = ImageUrlFormatter.extractFromMap(placeMap);
        if (placeExtracted.isNotEmpty) {
          debugPrint("[IMG_EXTRACT] Place extractFromMap -> '$placeExtracted'");
          return placeExtracted;
        }
      }
    }

    debugPrint("[IMG_EXTRACT] No image found for item");
    return '';
  }

  /// Legacy extractor: used by fromPlace() and as a fallback.
  static String _extractImageUrl(Map<String, dynamic> map) {
    for (final key in [
      'GalleryImages',
      'galleryImages',
      'eventImage',
      'offerImage',
      'coverImage',
      'CoverImage',
      'imageUrl',
      'image',
    ]) {
      final val = map[key];
      if (val != null) {
        final formatted = ImageUrlFormatter.format(val);
        if (formatted.isNotEmpty) return formatted;
      }
    }

    final itemImg = ImageUrlFormatter.extractFromMap(map);
    if (itemImg.isNotEmpty) return itemImg;

    final placeObj =
        map['place'] ?? map['targetPlace'] ?? map['business'] ?? map['venue'];
    if (placeObj is Map) {
      final placeMap = Map<String, dynamic>.from(placeObj);
      final placeCover = ImageUrlFormatter.extractFromMap(placeMap);
      if (placeCover.isNotEmpty) return placeCover;
    }

    return '';
  }

  static String _formatDiscount(dynamic value) {
    if (value == null) {
      return '';
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return '';
    }

    if (text.contains('%')) {
      return '$text off';
    }

    final parsed = num.tryParse(text);
    if (parsed != null) {
      final formatted =
          parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString();
      return '$formatted% off';
    }

    return text;
  }

  static String _formatDate(dynamic date) {
    if (date == null) {
      return '';
    }

    if (date is DateTime) {
      return _formatDateValue(date);
    }

    final text = date.toString().trim();
    if (text.isEmpty) {
      return '';
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      return text;
    }

    return _formatDateValue(parsed);
  }

  static String _formatDateValue(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${dateTime.day} ${months[dateTime.month - 1]}';
  }
}

class _DiscoveryStateView extends StatelessWidget {
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const _DiscoveryStateView({
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 15,
                height: 1.45,
              ),
            ),
            if (buttonLabel != null && onPressed != null) ...[
              const SizedBox(height: 14),
              CustomButton(
                onPressed: onPressed!,
                text: buttonLabel!,
                width: 150,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DiscoveryCard extends StatelessWidget {
  final DiscoveryListItem item;
  final DiscoveryPageKind pageKind;
  final VoidCallback onPrimaryAction;
  final VoidCallback onSecondaryAction;

  const DiscoveryCard({
    super.key,
    required this.item,
    required this.pageKind,
    required this.onPrimaryAction,
    required this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    if (pageKind == DiscoveryPageKind.event) {
      return _buildEventCard(context);
    }

    if (pageKind == DiscoveryPageKind.offer) {
      return _buildOfferCard(context);
    }

    // ── Place card ─────────────────────────────────────────────────────────────
    const imageHeight = 180.0;
    final finalUrl = ImageUrlFormatter.format(item.imageUrl);
    debugPrint("========== WIDGET CARD RENDER ==========");
    debugPrint("Card ID = ${item.id}");
    debugPrint("item.imageUrl = ${item.imageUrl}");
    debugPrint("item.image (from rawData) = ${item.rawData?['image']}");
    debugPrint(
        "item.coverImage (from rawData) = ${item.rawData?['coverImage']}");
    debugPrint(
        "item.galleryImages (from rawData) = ${item.rawData?['galleryImages'] ?? item.rawData?['GalleryImages']}");
    debugPrint("Exact property passed to Image.network = item.imageUrl");
    debugPrint("Final URL passed to Image.network = $finalUrl");
    debugPrint("========================================");

    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: const Color(0x14000000),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPrimaryAction,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: finalUrl.isNotEmpty
                    ? Image.network(
                        finalUrl,
                        width: double.infinity,
                        height: imageHeight,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              height: imageHeight,
                              color: const Color(0xFFE7E7E7),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Color(0xFF9E9E9E),
                                size: 30,
                              ),
                            ),
                      )
                    : Container(
                        height: imageHeight,
                        color: const Color(0xFFE7E7E7),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF9E9E9E),
                          size: 30,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              _TitleRow(
                title: item.title,
                rating: item.rating,
                showRating: pageKind == DiscoveryPageKind.place,
              ),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                style: const TextStyle(
                  color: Color(0xFF8A8A8A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.detailLine,
                style: const TextStyle(
                  color: Color(0xFF6E6E6E),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.accentText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFE5D17),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: onSecondaryAction,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      item.footerLinkLabel,
                      style: const TextStyle(
                        color: Color(0xFF75A9E0),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (item.id == 'dummy')
                    Container(
                      width: 80,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    )
                  else
                    CustomButton(
                      text: item.actionLabel,
                      onPressed: onPrimaryAction,
                      width: 90,
                      height: 36,
                      borderRadius: 999,
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-image offer card with gradient overlay — professional look.
  Widget _buildOfferCard(BuildContext context) {
    const cardHeight = 260.0;
    final finalUrl = ImageUrlFormatter.format(item.imageUrl);
    debugPrint("========== OFFER CARD RENDER ==========");
    debugPrint("Card ID = ${item.id}");
    debugPrint("Final URL = $finalUrl");
    debugPrint("=======================================");

    return Material(
      color: Colors.transparent,
      elevation: 3,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPrimaryAction,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: cardHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Background image ────────────────────────────────────────
                finalUrl.isNotEmpty
                    ? Image.network(
                        finalUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF2A2A2A),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.local_offer_outlined,
                            color: Color(0xFF555555),
                            size: 56,
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF2A2A2A),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.local_offer_outlined,
                          color: Color(0xFF555555),
                          size: 56,
                        ),
                      ),

                // ── Gradient overlay (bottom → top) ─────────────────────────
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x44000000),
                        Color(0xDD000000),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),

                // ── Discount badge (top-left) ────────────────────────────────
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFE5D17), Color(0xFFFF8C53)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55FE5D17),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flash_on_rounded,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          item.accentText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Bottom info area ─────────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            shadows: [
                              Shadow(
                                color: Color(0x88000000),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (item.detailLine.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: Color(0xFFFFB08A), size: 13),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.detailLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFFB08A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: onSecondaryAction,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                item.footerLinkLabel,
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            CustomButton(
                              text: item.actionLabel,
                              onPressed: onPrimaryAction,
                              width: 90,
                              height: 34,
                              borderRadius: 999,
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context) {
    const cardHeight = 260.0;
    final finalUrl = ImageUrlFormatter.format(item.imageUrl);
    debugPrint("========== EVENT CARD RENDER ==========");
    debugPrint("Card ID = ${item.id}");
    debugPrint("Final URL = $finalUrl");
    debugPrint("=======================================");

    final date = item.dateText ?? item.detailLine;
    final time = item.timeText ?? '';
    final price = item.priceText ?? item.accentText;
    final ticketCount = item.ticketCountText ?? 'Tickets Available';

    return Material(
      color: Colors.transparent,
      elevation: 3,
      shadowColor: const Color(0x22000000),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPrimaryAction,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: cardHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                finalUrl.isNotEmpty
                    ? Image.network(
                        finalUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF0D0D1A),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.confirmation_number_outlined,
                            color: Color(0xFF444466),
                            size: 60,
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF0D0D1A),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.confirmation_number_outlined,
                          color: Color(0xFF444466),
                          size: 60,
                        ),
                      ),

                // Gradient overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22000000),
                        Colors.transparent,
                        Color(0xEE000000),
                      ],
                      stops: [0.0, 0.35, 1.0],
                    ),
                  ),
                ),

                // Ticket / Sold-Out badge (top-left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: item.isSoldOut
                          ? const Color(0xCCD32F2F)
                          : Colors.black.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: item.isSoldOut
                            ? Colors.redAccent.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.isSoldOut
                              ? Icons.do_not_disturb_on_rounded
                              : Icons.local_activity_rounded,
                          color: item.isSoldOut ? Colors.white : const Color(0xFFFFB08A),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.isSoldOut ? 'Sold Out' : ticketCount,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: item.isSoldOut ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Price badge (top-right)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFE5D17), Color(0xFFFF8C53)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55FE5D17),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Bottom info area
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.25,
                            shadows: [
                              Shadow(color: Color(0x88000000), blurRadius: 6),
                            ],
                          ),
                        ),
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.70),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (date.isNotEmpty || time.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded,
                                  color: Color(0xFFFFB08A), size: 13),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  [if (date.isNotEmpty) date, if (time.isNotEmpty) time].join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFFFB08A),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              onPressed: onSecondaryAction,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                item.footerLinkLabel,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            CustomButton(
                              text: item.actionLabel,
                              onPressed: onPrimaryAction,
                              width: 100,
                              height: 34,
                              borderRadius: 999,
                              textStyle: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final String title;
  final double? rating;
  final bool showRating;

  const _TitleRow({
    required this.title,
    required this.rating,
    required this.showRating,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF262626),
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (showRating && rating != null) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.star_rounded,
            color: Color(0xFFFFB800),
            size: 15,
          ),
          const SizedBox(width: 2),
          Text(
            rating!.toStringAsFixed(1),
            style: const TextStyle(
              color: Color(0xFF6D6D6D),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
