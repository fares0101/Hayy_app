import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/image_url_formatter.dart';

class PlacesRemoteDataSource {
  final ApiClient apiClient;
  final Map<String, dynamic> _cache = {};

  PlacesRemoteDataSource(this.apiClient);

  List<dynamic>? getCachedPlaces() {
    return _cache['places'] as List<dynamic>?;
  }

  Map<String, dynamic>? getCachedPlaceDetails(String placeId) {
    return _cache['place_details_$placeId'] as Map<String, dynamic>?;
  }

  List<dynamic>? getCachedActiveOffers() {
    return _cache['offers'] as List<dynamic>?;
  }

  Map<String, dynamic>? getCachedOfferDetails(String offerId) {
    return _cache['offer_details_$offerId'] as Map<String, dynamic>?;
  }

  List<dynamic>? getCachedActiveEvents() {
    return _cache['events'] as List<dynamic>?;
  }

  Map<String, dynamic>? getCachedEventById(String eventId) {
    return _cache['event_details_$eventId'] as Map<String, dynamic>?;
  }

  List<dynamic>? getCachedRecommendations(String userId) {
    return _cache['recommendations_$userId'] as List<dynamic>?;
  }

  Future<List<dynamic>> getPlaces() async {
    final response = await apiClient.get(ApiConstants.places);
    final data = response.data;
    List<dynamic> result = [];
    if (data is List) {
      result = data;
    } else if (data is Map) {
      result = _extractListFromMap(
        Map<String, dynamic>.from(data),
        const ['items', 'places', 'results', 'data', 'result', 'value'],
      );
    }
    _cache['places'] = result;
    return result;
  }

  Future<Map<String, dynamic>> getPlaceDetails(String placeId) async {
    final url = ApiConstants.placeDetails.replaceAll('{id}', placeId);
    final response = await apiClient.get(url);
    debugPrint("=================================");
    debugPrint(
        "HTTP Response Status Code for GET /api/Places/$placeId = ${response.statusCode}");
    debugPrint("=================================");
    final data = response.data;
    Map<String, dynamic> result = {};

    if (data is Map<String, dynamic>) {
      result = _extractDetailsMap(data, ['place', 'item']);
    } else if (data is Map) {
      result = _extractDetailsMap(
          Map<String, dynamic>.from(data), ['place', 'item']);
    } else {
      throw Exception('Unexpected place details response format.');
    }

    // Fetch actual reviews for this place to dynamically calculate the real average rating
    if (placeId.isNotEmpty) {
      try {
        final reviewsRes = await apiClient.get(
          ApiConstants.placeReviews.replaceAll('{placeId}', placeId),
          queryParameters: {'pageNumber': 1, 'pageSize': 100},
        );
        final rData = reviewsRes.data;
        List<dynamic> rList = [];
        if (rData is List) {
          rList = rData;
        } else if (rData is Map) {
          final rMap = Map<String, dynamic>.from(rData);
          rList = (rMap['items'] ??
              rMap['data'] ??
              rMap['results'] ??
              rMap['value'] ??
              []) as List;
        }

        if (rList.isNotEmpty) {
          double sum = 0;
          int count = 0;
          for (final r in rList) {
            if (r is Map) {
              final rate = r['rating'] ?? r['rate'] ?? r['score'];
              if (rate is num) {
                sum += rate.toDouble();
                count++;
              }
            }
          }
          if (count > 0) {
            final avg = sum / count;
            result['rating'] = avg;
            result['averageRating'] = avg;
            result['avgRating'] = avg;
            result['reviewsCount'] = count;
          }
        }
      } catch (_) {}
    }

    _cache['place_details_$placeId'] = result;
    return result;
  }

  Future<List<dynamic>> getActiveOffers() async {
    final response = await apiClient.get(ApiConstants.activeOffers);
    final data = response.data;
    debugPrint("=== [DEBUG] RAW API RESPONSE /api/Offers/active ===");
    debugPrint(jsonEncode(data));
    List<dynamic> list = [];

    if (data is List) {
      list = data;
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      list = _extractOffersList(map);
    }

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is Map) {
        debugPrint("--- Offer Raw Item [$i] ---");
        debugPrint("id: ${item['id'] ?? item['offerId']}");
        debugPrint("title: ${item['title'] ?? item['name']}");
        debugPrint("CoverImage: ${item['CoverImage'] ?? item['coverImage']}");
        debugPrint(
            "GalleryImages: ${item['GalleryImages'] ?? item['galleryImages']}");
        debugPrint("image: ${item['image'] ?? item['imageUrl']}");
        debugPrint("placeId: ${item['placeId']}");
        debugPrint("full json: ${jsonEncode(item)}");
      }
    }

    final enriched = await _enrichItemsWithPlaceDetails(list);

    for (int i = 0; i < enriched.length; i++) {
      final item = enriched[i];
      if (item is Map) {
        debugPrint("--- Offer Enriched Item [$i] ---");
        debugPrint("id: ${item['id'] ?? item['offerId']}");
        debugPrint("imageUrl: ${item['imageUrl']}");
        debugPrint("image: ${item['image']}");
        debugPrint("coverImage: ${item['coverImage']}");
      }
    }

    _cache['offers'] = enriched;
    return enriched;
  }

  Future<Map<String, dynamic>> getOfferDetails(String offerId) async {
    Map<String, dynamic>? result;
    try {
      final response = await apiClient.get('/api/Offers/offer/$offerId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        result = _extractOfferDetailsMap(data);
      } else if (data is Map) {
        result = _extractOfferDetailsMap(Map<String, dynamic>.from(data));
      }
    } catch (_) {}

    if (result == null) {
      final response = await apiClient.get(
        ApiConstants.offerDetails.replaceAll('{id}', offerId),
      );
      final data = response.data;

      if (data is Map<String, dynamic>) {
        result = _extractOfferDetailsMap(data);
      } else if (data is Map) {
        result = _extractOfferDetailsMap(Map<String, dynamic>.from(data));
      }
    }

    if (result != null) {
      _cache['offer_details_$offerId'] = result;
      return result;
    }

    throw Exception('Unexpected offer details response format.');
  }

  Future<Map<String, dynamic>> getOfferPlaceDetails(String placeId) async {
    final response = await apiClient.get(
      ApiConstants.offerPlaceDetails.replaceAll('{placeId}', placeId),
    );
    return response.data;
  }

  Future<List<dynamic>> getActiveEvents() async {
    final response = await apiClient.get(ApiConstants.activeEvents);
    final data = response.data;
    debugPrint("=== [DEBUG] RAW API RESPONSE /api/Events/active ===");
    debugPrint(jsonEncode(data));
    List<dynamic> list = [];

    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      list = _extractEventsList(data);
    } else if (data is Map) {
      list = _extractEventsList(Map<String, dynamic>.from(data));
    }

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is Map) {
        debugPrint("--- Event Raw Item [$i] ---");
        debugPrint("id: ${item['id'] ?? item['eventId']}");
        debugPrint("title: ${item['title'] ?? item['name']}");
        debugPrint("CoverImage: ${item['CoverImage'] ?? item['coverImage']}");
        debugPrint(
            "GalleryImages: ${item['GalleryImages'] ?? item['galleryImages']}");
        debugPrint("image: ${item['image'] ?? item['imageUrl']}");
        debugPrint("placeId: ${item['placeId']}");
        debugPrint("full json: ${jsonEncode(item)}");
      }
    }

    final enriched = await _enrichItemsWithPlaceDetails(list);

    for (int i = 0; i < enriched.length; i++) {
      final item = enriched[i];
      if (item is Map) {
        debugPrint("--- Event Enriched Item [$i] ---");
        debugPrint("id: ${item['id'] ?? item['eventId']}");
        debugPrint("imageUrl: ${item['imageUrl']}");
        debugPrint("image: ${item['image']}");
        debugPrint("coverImage: ${item['coverImage']}");
      }
    }

    _cache['events'] = enriched;
    return enriched;
  }

  Future<Map<String, dynamic>> getEventById(String eventId) async {
    Map<String, dynamic>? result;
    try {
      final response = await apiClient.get(
        ApiConstants.eventById.replaceAll('{id}', eventId),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        result = _extractDetailsMap(data, ['event', 'item', 'data']);
      } else if (data is Map) {
        result = _extractDetailsMap(
            Map<String, dynamic>.from(data), ['event', 'item', 'data']);
      }
    } catch (_) {}

    if (result == null) {
      try {
        final response = await apiClient.get('/api/Events/event/$eventId');
        final data = response.data;
        if (data is Map<String, dynamic>) {
          result = _extractDetailsMap(data, ['event', 'item', 'data']);
        } else if (data is Map) {
          result = _extractDetailsMap(
              Map<String, dynamic>.from(data), ['event', 'item', 'data']);
        }
      } catch (_) {}
    }

    if (result == null) {
      // Fallback: search active events list for matching eventId
      try {
        final activeEvents = await getActiveEvents();
        for (final item in activeEvents) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final id = (map['id'] ?? map['eventId'] ?? map['eventID'])
                ?.toString()
                .trim();
            if (id == eventId) {
              result = map;
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (result != null) {
      _cache['event_details_$eventId'] = result;
      return result;
    }

    throw Exception('Unexpected event details response format.');
  }

  Future<List<dynamic>> searchPlaces(String query) async {
    final response = await apiClient.get(
      ApiConstants.searchPlaces,
      queryParameters: {'query': query},
    );
    final data = response.data;
    if (data is List) {
      return data;
    }
    if (data is Map) {
      return _extractListFromMap(
        Map<String, dynamic>.from(data),
        const ['items', 'places', 'results', 'data', 'result', 'value'],
      );
    }
    return [];
  }

  Future<List<dynamic>> smartSearch({
    required String userId,
    required String searchTerm,
  }) async {
    final response = await apiClient.post(
      ApiConstants.smartSearch,
      data: {
        'userId': userId,
        'searchTerm': searchTerm,
      },
    );

    final data = response.data;
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      final list = _extractListFromMap(
          data, ['items', 'results', 'data', 'result', 'value']);
      return list.isNotEmpty ? list : [data];
    }
    return [];
  }

  Future<bool?> toggleFollowPlace(String placeId) async {
    // POST /api/PlaceFollows/toggle
    final response = await apiClient.post(
      ApiConstants.togglePlaceFollow,
      data: {'placeId': placeId},
    );
    final data = response.data;
    if (data is bool) return data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in [
        'isFollowing',
        'isFollowed',
        'following',
        'isFavorite',
        'value',
        'status'
      ]) {
        final val = map[key];
        if (val is bool) return val;
        if (val is String) {
          if (val.toLowerCase() == 'true') return true;
          if (val.toLowerCase() == 'false') return false;
        }
      }

      if (map['data'] is bool) return map['data'] as bool;
      if (map['data'] is Map) {
        final nested = Map<String, dynamic>.from(map['data']);
        for (final key in [
          'isFollowing',
          'isFollowed',
          'following',
          'isFavorite',
          'value'
        ]) {
          if (nested[key] is bool) return nested[key] as bool;
        }
      }

      final msg = (map['message'] ?? map['msg'] ?? map['detail'] ?? '')
          .toString()
          .toLowerCase();
      if (msg.contains('unfollow') ||
          msg.contains('remove') ||
          msg.contains('delete')) {
        return false;
      }
      if (msg.contains('follow') ||
          msg.contains('add') ||
          msg.contains('success')) {
        return true;
      }
    }
    return null;
  }

  Future<List<dynamic>> getNearbyPlaces(
      double lat, double lng, double radius) async {
    final response = await apiClient.get(
      ApiConstants.nearbyPlaces,
      queryParameters: {'lat': lat, 'lng': lng, 'radius': radius},
    );
    return response.data;
  }

  Future<List<dynamic>> getRecommendations(String userId) async {
    final url = ApiConstants.recommendations.replaceAll('{userId}', userId);
    final response = await apiClient.get(url);
    final data = response.data;
    List<dynamic> result = [];

    if (data is List) {
      result = data;
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      // Try common wrapper keys
      result = _extractListFromMap(map, [
        'recommendations',
        'items',
        'data',
        'results',
        'result',
        'value',
      ]);
    }

    _cache['recommendations_$userId'] = result;
    return result;
  }

  /// Fetches similar places to a given place by trying category-based search
  /// or falling back to the general places list, then filtering out the current place.
  Future<List<Map<String, dynamic>>> getSimilarPlaces({
    required String currentPlaceId,
    String? categoryName,
    String? categoryId,
    int limit = 6,
  }) async {
    List<dynamic> candidates = [];

    // 1. Try category-based search first
    if (categoryName != null && categoryName.trim().isNotEmpty) {
      try {
        candidates = await searchPlaces(categoryName.trim());
      } catch (_) {}
    }

    // 2. Try fetching by categoryId via query param
    if (candidates.isEmpty &&
        categoryId != null &&
        categoryId.trim().isNotEmpty) {
      try {
        final response = await apiClient.get(
          ApiConstants.places,
          queryParameters: {'categoryId': categoryId.trim()},
        );
        final data = response.data;
        if (data is List) {
          candidates = data;
        } else if (data is Map) {
          candidates = _extractListFromMap(
            Map<String, dynamic>.from(data),
            const ['items', 'places', 'results', 'data', 'result', 'value'],
          );
        }
      } catch (_) {}
    }

    // 3. Fallback: all places
    if (candidates.isEmpty) {
      try {
        candidates = await getPlaces();
      } catch (_) {}
    }

    // Filter & convert
    return candidates
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((p) {
          final id = (p['id'] ?? p['placeId'] ?? '').toString();
          return id != currentPlaceId;
        })
        .take(limit)
        .toList();
  }

  List<dynamic> _extractOffersList(Map<String, dynamic> data) {
    return _extractListFromMap(data, [
      'items',
      'offers',
      'results',
      'data',
      'result',
      'value',
    ]);
  }

  List<dynamic> _extractEventsList(Map<String, dynamic> data) {
    return _extractListFromMap(data, [
      'items',
      'events',
      'results',
      'data',
      'result',
      'value',
    ]);
  }

  List<dynamic> _extractListFromMap(
    Map<String, dynamic> data,
    List<String> directKeys,
  ) {
    // Unpack top-level EF Core $values if present
    for (final valKey in [r'$values', 'values', r'$items', 'items']) {
      if (data[valKey] is List) {
        return data[valKey] as List;
      }
    }

    final directCandidates = <dynamic>[
      for (final key in directKeys) data[key],
    ];

    for (final candidate in directCandidates) {
      if (candidate is List) {
        return candidate;
      }
      if (candidate is Map) {
        final map = Map<String, dynamic>.from(candidate);
        for (final valKey in [r'$values', 'values', r'$items', 'items']) {
          if (map[valKey] is List) {
            return map[valKey] as List;
          }
        }
      }
    }

    final nestedCandidates = <dynamic>[
      data['data'],
      data['result'],
      data['value'],
      data['payload'],
    ];

    for (final nested in nestedCandidates) {
      if (nested is Map) {
        final list = _extractListFromMap(
          Map<String, dynamic>.from(nested),
          directKeys,
        );
        if (list.isNotEmpty) {
          return list;
        }
      }
    }

    return const [];
  }

  Map<String, dynamic> _extractOfferDetailsMap(Map<String, dynamic> data) {
    return _extractDetailsMap(
      data,
      ['offer', 'item'],
    );
  }

  Map<String, dynamic> _extractDetailsMap(
    Map<String, dynamic> data,
    List<String> preferredNestedKeys,
  ) {
    final nestedMapCandidates = <dynamic>[
      data['data'],
      data['result'],
      data['value'],
      data['payload'],
      for (final key in preferredNestedKeys) data[key],
    ];

    for (final candidate in nestedMapCandidates) {
      if (candidate is Map) {
        return Map<String, dynamic>.from(candidate);
      }
    }

    return data;
  }

  Future<List<dynamic>> _enrichItemsWithPlaceDetails(
      List<dynamic> rawList) async {
    if (rawList.isEmpty) return rawList;

    final placeCache = <String, Map<String, dynamic>>{};

    final enriched = await Future.wait(rawList.map((item) async {
      if (item is! Map) return item;
      final map = Map<String, dynamic>.from(item);

      final existingImage = ImageUrlFormatter.extractFromMap(map);

      // Check if item already has a valid image - but DO NOT set imageUrl/coverImage if
      // it came from a generic/stale source that might have been overridden by galleryImages.
      // Gallery images (GalleryImages/galleryImages) are ALWAYS the most current.
      final galleryVal = map['GalleryImages'] ?? map['galleryImages'];

      // Gallery images have highest priority - if present, ALWAYS use the first one
      if (galleryVal != null) {
        final galleryUrl = ImageUrlFormatter.format(galleryVal);
        if (galleryUrl.isNotEmpty) {
          debugPrint(
              "[ENRICH ITEM] Gallery present for ${map['id']} - overriding with gallery URL: '$galleryUrl'");
          map['imageUrl'] = galleryUrl;
          map['image'] = galleryUrl;
          map['coverImage'] = galleryUrl;
        }
      } else if (existingImage.isNotEmpty) {
        debugPrint(
            "[ENRICH ITEM] Item ID: ${map['id']} | extracted existingImage = '$existingImage'");
        map['imageUrl'] = existingImage;
        map['image'] = existingImage;
        map['coverImage'] = existingImage;
      }

      final placeId = (map['placeId'] ?? map['place_id'] ?? map['place']?['id'])
          ?.toString()
          .trim();

      if (placeId != null && placeId.isNotEmpty) {
        Map<String, dynamic>? placeData = placeCache[placeId];
        if (placeData == null) {
          debugPrint("--------------------------------");
          debugPrint("Fetching Place Details");
          debugPrint("placeId = $placeId");
          debugPrint("--------------------------------");

          try {
            placeData = await getPlaceDetails(placeId);
            debugPrint("================================");
            debugPrint("PLACE DETAILS RESPONSE");
            debugPrint("================================");
            debugPrint(jsonEncode(placeData));

            if (placeData.isNotEmpty) {
              placeCache[placeId] = placeData;
            }
          } catch (e, stack) {
            debugPrint("================================");
            debugPrint("PLACE DETAILS REQUEST FAILED");
            debugPrint("placeId = $placeId");
            debugPrint("Error = $e");
            debugPrint(stack.toString());
            debugPrint("================================");
          }
        }

        if (placeData != null && placeData.isNotEmpty) {
          map['place'] = placeData;
          if (map['placeName'] == null ||
              map['placeName'].toString().trim().isEmpty) {
            map['placeName'] = placeData['name'] ??
                placeData['title'] ??
                placeData['placeName'];
          }
          if (map['address'] == null ||
              map['address'].toString().trim().isEmpty) {
            map['address'] = placeData['address'] ??
                placeData['location'] ??
                placeData['city'];
          }

          final placeCoverImg = ImageUrlFormatter.extractFromMap(placeData);
          debugPrint("Extracted Cover Image = $placeCoverImg");

          if (placeCoverImg.isNotEmpty) {
            map['placeImage'] = placeCoverImg;
            map['placeCoverImage'] = placeCoverImg;

            // Use place image as fallback only if item has NO gallery image of its own.
            // existingImage may be stale (pre-gallery) so re-check the final map image.
            final finalItemImg =
                (map['imageUrl'] ?? map['image'] ?? '').toString().trim();
            if (finalItemImg.isEmpty) {
              map['imageUrl'] = placeCoverImg;
              map['image'] = placeCoverImg;
              map['coverImage'] = placeCoverImg;
            }
          }
        }

      }

      debugPrint("--------------------------------");
      debugPrint(
          "FINAL ENRICHED MAP VALUES for Item ID ${map['id'] ?? map['offerId'] ?? map['eventId']}:");
      debugPrint("imageUrl = ${map['imageUrl']}");
      debugPrint("image = ${map['image']}");
      debugPrint("coverImage = ${map['coverImage']}");
      debugPrint("--------------------------------");

      return map;
    }));

    return enriched;
  }
}
