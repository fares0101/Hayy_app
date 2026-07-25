import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';

class ImageUrlFormatter {
  static const String _baseUrl = ApiConstants.baseUrl;

  /// Takes a raw string, list, or map and returns a clean, fully-qualified image URL string.
  static String format(dynamic rawValue, {String fallback = ''}) {
    if (rawValue == null) {
      debugPrint("[FORMAT INPUT] rawValue = null");
      debugPrint("[FORMAT OUTPUT] input = null -> output = ''");
      return fallback;
    }

    final String res = _formatInternal(rawValue, fallback: fallback);
    debugPrint(
        "[FORMAT INPUT] rawValue = $rawValue, type = ${rawValue.runtimeType}");
    debugPrint("[FORMAT OUTPUT] input = $rawValue -> output = $res");
    return res;
  }

  static String _formatInternal(dynamic rawValue, {String fallback = ''}) {
    if (rawValue == null) return fallback;

    // 1. String
    if (rawValue is String) {
      var text = rawValue.trim();
      text = text.replaceAll(RegExp(r'^["\[\s]+|["\]\s]+$'), '');
      if (text.contains(',')) {
        text = text.split(',').first.trim();
      }
      if (text.startsWith('[') || text.startsWith('{')) {
        try {
          final decoded = jsonDecode(text);
          final formatted = format(decoded);
          if (formatted.isNotEmpty) return formatted;
        } catch (_) {}
      }
      if (!_isValidImageString(text)) return fallback;
      return _normalizeUrl(text);
    }

    // 2. List (e.g., ["/uploads/1.jpg", "/uploads/2.jpg"])
    if (rawValue is List) {
      for (final item in rawValue) {
        final formatted = format(item);
        if (formatted.isNotEmpty) return formatted;
      }
      return fallback;
    }

    // 3. Map (e.g., {"url": "/uploads/1.jpg"} or EF Core {$values: [...]})
    if (rawValue is Map) {
      final map = Map<String, dynamic>.from(rawValue);

      // Unpack EF Core / Newtonsoft.Json reference wrappers e.g. {$values: [...]}
      for (final key in [r'$values', 'values', r'$items', 'items']) {
        if (map.containsKey(key) && map[key] != null) {
          final formatted = format(map[key]);
          if (formatted.isNotEmpty) return formatted;
        }
      }

      return extractFromMap(map, fallback: fallback);
    }

    final str = rawValue.toString().trim();
    if (!_isValidImageString(str)) return fallback;
    return _normalizeUrl(str);
  }

  /// Extracts image URL from a JSON map checking candidate keys in precise priority order.
  /// Specific item image keys (event/offer/post/cover) are checked FIRST before general
  /// or venue/place/logo keys, ensuring event & offer images are never overridden by place logos.
  static String extractFromMap(Map<String, dynamic> map,
      {String fallback = ''}) {
    if (map.isEmpty) return fallback;

    final candidateKeys = [
      // ── 1. Specific Event Image Keys ─────────────────────────────────────────
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

      // ── 2. Specific Offer & Promotion Image Keys ─────────────────────────────
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
      'offerPhotoPath',
      'offer_photo_path',
      'offerPictureUrl',
      'offer_picture_url',
      'offerPicture',
      'offer_picture',
      'offerPicturePath',
      'offer_picture_path',
      'offerCoverUrl',
      'offer_cover_url',
      'offerCover',
      'offer_cover',
      'offerCoverPath',
      'offer_cover_path',
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
      'offerAttachments',
      'offer_attachments',
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

      // ── 3. Specific Post Image Keys ──────────────────────────────────────────
      'PostAttachments',
      'postAttachments',
      'post_attachments',
      'postAttachment',
      'post_attachment',
      'postMedia',
      'post_media',
      'postImageUrl',
      'post_image_url',
      'postImage',
      'post_image',
      'postImagePath',
      'post_image_path',

      // ── 4. Cover / Banner / Poster / Main Image Keys ────────────────────────
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

      // ── 5. General / Direct Image Keys (Check Item's own image before Place) ─
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

      // ── 6. Place / Venue Image Keys (Fallback if item has no specific image) ─
      'placeImageUrl',
      'place_image_url',
      'placeImage',
      'place_image',
      'placeImagePath',
      'place_image_path',
      'placeLogo',
      'place_logo',
      'placeLogoUrl',
      'place_logo_url',
      'placeProfileImage',
      'place_profile_image',
      'placeProfileImageUrl',
      'place_profile_image_url',
      'businessImage',
      'business_image',
      'businessImageUrl',
      'business_image_url',
      'businessLogo',
      'business_logo',
      'businessLogoUrl',
      'business_logo_url',

      // ── 7. Profile / Avatar / Logo Keys ──────────────────────────────────────
      'profileImage',
      'profile_image',
      'profileImageUrl',
      'profile_image_url',
      'profileImagePath',
      'profile_image_path',
      'avatarUrl',
      'avatar_url',
      'avatarPath',
      'avatar_path',
      'avatar',
      'logoUrl',
      'logo_url',
      'logoPath',
      'logo_path',
      'logo',
      'icon',
      'iconUrl',
      'icon_url',
    ];

    // Case-insensitive map lookup
    final lowerMap = <String, dynamic>{};
    for (final entry in map.entries) {
      lowerMap[entry.key.toLowerCase()] = entry.value;
    }

    debugPrint(
        "[EXTRACT_MAP] Checking candidate keys for map containing keys: ${map.keys.toList()}");

    for (final key in candidateKeys) {
      final val = lowerMap[key.toLowerCase()];
      if (val != null) {
        debugPrint(
            "[EXTRACT_MAP CANDIDATE FOUND] Candidate key: '$key' | Found val: '$val' | Type: ${val.runtimeType}");
        final formatted = format(val);
        if (formatted.isNotEmpty) {
          debugPrint(
              "[EXTRACT_MAP SELECTED KEY] Selected key: '$key' | Val before: '$val' | Val after formatting: '$formatted'");
          return formatted;
        }
      }
    }

    // Check nested candidates with item priority before publisher/venue/place
    final nestedCandidates = [
      map['offer'],
      map['Offer'],
      map['targetOffer'],
      map['TargetOffer'],
      map['offerDetails'],
      map['OfferDetails'],
      map['discount'],
      map['Discount'],
      map['promotion'],
      map['Promotion'],
      map['deal'],
      map['Deal'],
      map['event'],
      map['Event'],
      map['targetEvent'],
      map['TargetEvent'],
      map['post'],
      map['Post'],
      map['businessPost'],
      map['BusinessPost'],
      map['targetPost'],
      map['TargetPost'],
      map['details'],
      map['Details'],
      map['item'],
      map['Item'],
      map['data'],
      map['Data'],
      map['payload'],
      map['Payload'],
      map['images'],
      map['photos'],
      map['pictures'],
      map['attachments'],
      map['place'],
      map['Place'],
      map['targetPlace'],
      map['TargetPlace'],
      map['venue'],
      map['Venue'],
      map['business'],
      map['Business'],
      map['owner'],
      map['Owner'],
      map['publisher'],
      map['Publisher'],
      map['target'],
      map['Target'],
    ];

    for (final candidate in nestedCandidates) {
      if (candidate is Map) {
        final formatted = extractFromMap(Map<String, dynamic>.from(candidate));
        if (formatted.isNotEmpty) return formatted;
      }
    }

    return fallback;
  }

  static bool _isValidImageString(String value) {
    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty ||
        trimmed == 'null' ||
        trimmed == 'undefined' ||
        trimmed == 'placeholder' ||
        trimmed == 'none' ||
        trimmed == 'false' ||
        trimmed == '0') {
      return false;
    }
    return true;
  }

  /// Prepends baseUrl to relative paths and cleans duplicate slashes.
  static String _normalizeUrl(String url) {
    String cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return '';

    // Convert popular photo sharing webpage URLs (Unsplash, Pexels, Imgur, Pixabay) to direct CDN image URLs
    cleanUrl = _convertWebPageToCdnUrl(cleanUrl);

    // Fix backslashes if server sent Windows paths e.g. "uploads\images\1.jpg"
    cleanUrl = cleanUrl.replaceAll('\\', '/');

    // Upgrade cleartext HTTP to HTTPS for hayy-api
    if (cleanUrl.toLowerCase().startsWith('http://hayy-api')) {
      cleanUrl = cleanUrl.replaceFirst(
          RegExp(r'^http://', caseSensitive: false), 'https://');
    }

    // Rewrite dev localhost / 127.0.0.1 / 10.0.2.2 URLs to target server path
    final lower = cleanUrl.toLowerCase();
    if (lower.startsWith('http://localhost') ||
        lower.startsWith('https://localhost') ||
        lower.startsWith('http://127.0.0.1') ||
        lower.startsWith('https://127.0.0.1') ||
        lower.startsWith('http://10.0.2.2') ||
        lower.startsWith('https://10.0.2.2')) {
      final uri = Uri.tryParse(cleanUrl);
      if (uri != null && uri.path.isNotEmpty) {
        cleanUrl = uri.path;
      }
    }

    // Check if absolute URL or data URI
    if (cleanUrl.toLowerCase().startsWith('http://') ||
        cleanUrl.toLowerCase().startsWith('https://') ||
        cleanUrl.toLowerCase().startsWith('data:image/')) {
      return Uri.encodeFull(cleanUrl);
    }

    // Handle ASP.NET ~/ relative paths or wwwroot/ or public/
    if (cleanUrl.startsWith('~/')) {
      cleanUrl = cleanUrl.substring(1);
    }

    cleanUrl = _extractPublicPath(cleanUrl);
    if (cleanUrl.isEmpty || cleanUrl == '/' || cleanUrl == 'null') return '';

    // Clean slashes
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final path = cleanUrl.startsWith('/') ? cleanUrl : '/$cleanUrl';

    final result = '$base$path';
    if (result == '$_baseUrl/' || result == _baseUrl || result == '$base/') {
      return '';
    }
    return Uri.encodeFull(result);
  }

  static String _extractPublicPath(String path) {
    var normalized = path.trim();
    final lower = normalized.toLowerCase();
    for (final marker in const [
      '/wwwroot/',
      '/public/',
      '/uploads/',
      '/upload/',
      '/images/',
      '/image/',
      '/post-images/',
      '/event-images/',
      '/events/',
      '/event/',
      '/place-images/',
      '/offer-images/',
      '/offers/',
      '/discounts/',
      '/promotions/',
      '/deals/',
      '/gallery/',
      '/gallery-images/',
      '/galleryimages/',
      '/gallery_images/',
      '/post-attachments/',
      '/profile-images/',
      '/storage/',
      '/media/',
      '/files/',
      '/attachments/',
      '/assets/',
    ]) {
      final index = lower.indexOf(marker);
      if (index >= 0) {
        if (marker == '/wwwroot/' || marker == '/public/') {
          return normalized.substring(index + marker.length - 1);
        }
        return normalized.substring(index);
      }
    }

    // If string starts with uploads/ or images/ without leading slash
    for (final prefix in const [
      'uploads/',
      'upload/',
      'images/',
      'image/',
      'post-images/',
      'event-images/',
      'events/',
      'event/',
      'place-images/',
      'offer-images/',
      'offers/',
      'discounts/',
      'promotions/',
      'deals/',
      'gallery/',
      'gallery-images/',
      'galleryimages/',
      'gallery_images/',
      'post-attachments/',
      'profile-images/',
      'storage/',
      'media/',
      'files/',
      'attachments/',
      'assets/',
      'wwwroot/',
      'public/',
    ]) {
      if (lower.startsWith(prefix)) {
        if (prefix == 'wwwroot/' || prefix == 'public/') {
          return '/${normalized.substring(prefix.length)}';
        }
        return '/$normalized';
      }
    }

    return normalized;
  }

  /// Converts popular photo sharing webpage URLs (Unsplash, Pexels, Imgur, Pixabay, Freepik) into direct CDN image URLs.
  static String _convertWebPageToCdnUrl(String url) {
    String cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return '';

    final lower = cleanUrl.toLowerCase();

    // 1. Unsplash: convert webpage URL to a direct CDN-accessible URL.
    if (lower.contains('unsplash.com')) {
      try {
        final uri = Uri.parse(cleanUrl);
        final path = uri.path;

        // Already a CDN URL from images.unsplash.com – keep as-is (add params if missing)
        if (uri.host.contains('images.unsplash.com')) {
          if (!cleanUrl.contains('w=')) {
            return '$cleanUrl?auto=format&fit=crop&w=1000&q=80';
          }
          return cleanUrl;
        }

        // Webpage URL pattern: /photos/{slug-photoId} or /fotos/{slug-photoId}
        // e.g. https://unsplash.com/photos/foam-party-FK6qRjvxQZU
        // The download endpoint (with force=true) works without an API key
        // and redirects Flutter's Image.network to the actual CDN image stream.
        if (path.contains('/photos/') || path.contains('/fotos/')) {
          final segments = path.split('/').where((s) => s.isNotEmpty).toList();
          // Remove query params from last segment
          final photoSlug = segments.last.split('?').first;
          if (photoSlug.isNotEmpty) {
            return 'https://unsplash.com/photos/$photoSlug/download?force=true';
          }
        }
      } catch (_) {}
    }

    // 2. Pexels (e.g. https://www.pexels.com/photo/person-cutting-pizza-1234567/)
    if (lower.contains('pexels.com')) {
      try {
        if (lower.contains('images.pexels.com')) return cleanUrl;
        final match = RegExp(r'\d{5,}').firstMatch(cleanUrl);
        if (match != null) {
          final id = match.group(0);
          return 'https://images.pexels.com/photos/$id/pexels-photo-$id.jpeg?auto=compress&cs=tinysrgb&w=1000';
        }
      } catch (_) {}
    }

    // 3. Imgur (e.g. https://imgur.com/a/ABCDE or https://imgur.com/ABCDE)
    if (lower.contains('imgur.com')) {
      try {
        if (lower.contains('i.imgur.com')) return cleanUrl;
        final uri = Uri.parse(cleanUrl);
        final id = uri.pathSegments.last.split('.').first;
        if (id.isNotEmpty) {
          return 'https://i.imgur.com/$id.jpg';
        }
      } catch (_) {}
    }

    // 4. Pixabay (e.g. https://pixabay.com/photos/food-pizza-1234567/)
    if (lower.contains('pixabay.com')) {
      try {
        if (lower.contains('cdn.pixabay.com')) return cleanUrl;
        final match = RegExp(r'\d{5,}').firstMatch(cleanUrl);
        if (match != null) {
          final id = match.group(0);
          return 'https://cdn.pixabay.com/photo/$id/photo-$id.jpg';
        }
      } catch (_) {}
    }

    return cleanUrl;
  }
}
