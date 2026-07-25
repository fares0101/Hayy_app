import 'dart:developer' as dev;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../injection_container.dart';
import 'places_remote_data_source.dart';

class FavoritesRemoteDataSource {
  final ApiClient apiClient;
  List<Map<String, dynamic>>? _favoritesCache;

  FavoritesRemoteDataSource(this.apiClient);

  List<Map<String, dynamic>>? getCachedFavorites() {
    return _favoritesCache;
  }

  /// GET /api/PlaceFollows/user/follows
  /// Returns paginated list of places followed by the authenticated user.
  Future<List<Map<String, dynamic>>> getMyFavorites({
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final userId = sl<UserSessionManager>().getUser()?.id ?? '';
    final endpoint = ApiConstants.myFollowedPlaces.replaceAll('{userId}', userId);

    final response = await apiClient.get(
      endpoint,
      queryParameters: {
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      },
    );

    final raw = response.data;
    dev.log('[Favorites] raw response: $raw', name: 'FavoritesDS');
    List<dynamic> items = const [];

    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      for (final key in ['items', 'places', 'follows', 'results', 'data', 'value']) {
        if (map[key] is List) {
          items = map[key] as List;
          break;
        }
      }
    }

    final result = items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    dev.log('[Favorites] parsed ${result.length} items', name: 'FavoritesDS');

    // Enrich items with real place details and calculated star ratings
    final enriched = await Future.wait(result.map((item) async {
      final map = Map<String, dynamic>.from(item);
      final rawPlace = map['place'] ?? map['targetPlace'] ?? map['businessPlace'] ?? map['followedPlace'];
      final placeMap = rawPlace is Map ? Map<String, dynamic>.from(rawPlace) : <String, dynamic>{};
      final merged = {...map, ...placeMap};

      final placeId = (merged['placeId'] ?? merged['id'] ?? merged['targetPlaceId'] ?? map['placeId'] ?? map['id'])?.toString().trim();

      if (placeId != null && placeId.isNotEmpty) {
        try {
          final details = await sl<PlacesRemoteDataSource>().getPlaceDetails(placeId);
          if (details.isNotEmpty) {
            map['place'] = details;
          }
        } catch (_) {}
      }
      return map;
    }));

    _favoritesCache = enriched;
    return enriched;
  }

  /// POST /api/PlaceFollows/toggle
  /// Toggles follow (bookmark) status for a place.
  /// Returns explicit bool if provided by backend, or null if toggle succeeded without returning explicit bool.
  Future<bool?> toggleFavorite(String placeId) async {
    dev.log('[Favorites] toggling placeId: $placeId', name: 'FavoritesDS');
    try {
      final response = await apiClient.post(
        ApiConstants.togglePlaceFollow,
        data: {'placeId': placeId},
      );
      final data = response.data;
      dev.log('[Favorites] toggle response: $data (statusCode=${response.statusCode})', name: 'FavoritesDS');

      bool? isFollowing;

      if (data is bool) {
        isFollowing = data;
      } else if (data is Map) {
        final map = Map<String, dynamic>.from(data);

        // Check direct boolean/string fields
        for (final key in ['isFollowing', 'isFollowed', 'following', 'isFavorite', 'value', 'status']) {
          final val = map[key];
          if (val is bool) {
            isFollowing = val;
            break;
          }
          if (val is String) {
            if (val.toLowerCase() == 'true') {
              isFollowing = true;
              break;
            }
            if (val.toLowerCase() == 'false') {
              isFollowing = false;
              break;
            }
          }
        }

        if (isFollowing == null) {
          // Check nested data objects
          if (map['data'] is bool) {
            isFollowing = map['data'] as bool;
          } else if (map['data'] is Map) {
            final nested = Map<String, dynamic>.from(map['data']);
            for (final key in ['isFollowing', 'isFollowed', 'following', 'isFavorite', 'value']) {
              if (nested[key] is bool) {
                isFollowing = nested[key] as bool;
                break;
              }
            }
          }
        }

        if (isFollowing == null) {
          // Check message strings
          final msg = (map['message'] ?? map['msg'] ?? map['detail'] ?? '').toString().toLowerCase();
          if (msg.contains('unfollow') || msg.contains('remove') || msg.contains('delete')) {
            isFollowing = false;
          } else if (msg.contains('follow') || msg.contains('add') || msg.contains('success')) {
            isFollowing = true;
          }
        }
      }

      if (isFollowing == false) {
        _favoritesCache?.removeWhere((item) {
          final id = (item['placeId'] ?? item['id'] ?? item['targetPlaceId'])?.toString().trim();
          final rawPlace = item['place'] ?? item['targetPlace'] ?? item['businessPlace'] ?? item['followedPlace'];
          final placeMap = rawPlace is Map ? Map<String, dynamic>.from(rawPlace) : <String, dynamic>{};
          final itemPlaceId = (placeMap['id'] ?? placeMap['placeId'])?.toString().trim();
          return id == placeId.trim() || itemPlaceId == placeId.trim();
        });
      }

      return isFollowing;
    } catch (e) {
      dev.log('[Favorites] toggleFavorite error for placeId=$placeId: $e', name: 'FavoritesDS');
      rethrow;
    }
  }
}
