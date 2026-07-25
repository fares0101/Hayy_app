import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/user_session_manager.dart';
import '../../../injection_container.dart';

class PostLikesResult {
  final int count;
  final bool? isLiked;

  const PostLikesResult({required this.count, this.isLiked});
}

class BusinessPostsRemoteDataSource {
  final ApiClient apiClient;

  final Map<String, List<Map<String, dynamic>>> _postsCache = {};
  final Map<String, DateTime> _postsCacheTime = {};
  static const Duration _cacheTtl = Duration(seconds: 30);

  BusinessPostsRemoteDataSource(this.apiClient);

  List<Map<String, dynamic>>? getCachedBusinessPosts({
    int pageNumber = 1,
    int pageSize = 10,
  }) {
    final cacheKey = 'all_${pageNumber}_$pageSize';
    return _postsCache[cacheKey];
  }

  List<Map<String, dynamic>>? getCachedPostsByPlaceId(
    String placeId, {
    int pageNumber = 1,
    int pageSize = 10,
  }) {
    final cacheKey = 'place_${placeId}_${pageNumber}_$pageSize';
    return _postsCache[cacheKey];
  }

  Future<List<Map<String, dynamic>>> getBusinessPosts({
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final cacheKey = 'all_${pageNumber}_$pageSize';
    final cachedTime = _postsCacheTime[cacheKey];
    if (cachedTime != null && DateTime.now().difference(cachedTime) < _cacheTtl) {
      if (_postsCache.containsKey(cacheKey)) {
        return _postsCache[cacheKey]!;
      }
    }

    final response = await apiClient.get(
      ApiConstants.allBusinessPosts,
      queryParameters: {
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      },
    );

    final items = _extractList(response.data, const [
      'items',
      'posts',
      'businessPosts',
      'results',
      'data',
      'result',
      'value',
    ]);

    final result = items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    _postsCache[cacheKey] = result;
    _postsCacheTime[cacheKey] = DateTime.now();
    return result;
  }

  /// GET /api/BusinessPosts/{placeId}
  /// Retrieves a paginated list of posts associated with the specified place.
  Future<List<Map<String, dynamic>>> getPostsByPlaceId(
    String placeId, {
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    if (placeId.isEmpty) return [];

    final cacheKey = 'place_${placeId}_${pageNumber}_$pageSize';
    final cachedTime = _postsCacheTime[cacheKey];
    if (cachedTime != null && DateTime.now().difference(cachedTime) < _cacheTtl) {
      if (_postsCache.containsKey(cacheKey)) {
        return _postsCache[cacheKey]!;
      }
    }
    try {
      final endpoint = ApiConstants.businessPostsByPlaceId.replaceAll('{placeId}', placeId);
      final response = await apiClient.get(
        endpoint,
        queryParameters: {
          'pageNumber': pageNumber,
          'pageSize': pageSize,
        },
      );

      final items = _extractList(response.data, const [
        'items',
        'posts',
        'businessPosts',
        'results',
        'data',
        'result',
        'value',
      ]);

      final result = items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      _postsCache[cacheKey] = result;
      _postsCacheTime[cacheKey] = DateTime.now();
      return result;
    } catch (_) {
      return [];
    }
  }

  /// GET /api/BusinessPosts/post/{postId}
  /// Gets a specific business post by its ID.
  Future<Map<String, dynamic>> getPostById(String postId) async {
    try {
      final response = await apiClient.get('/api/BusinessPosts/post/$postId');
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final post = data['post'] ?? data['data'] ?? data['item'];
        if (post is Map) return Map<String, dynamic>.from(post);
        return data;
      }
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final post = map['post'] ?? map['data'] ?? map['item'];
        if (post is Map) return Map<String, dynamic>.from(post);
        return map;
      }
    } catch (_) {}
    return {};
  }

  Future<int> getPostLikesCount(String postId) async {
    final details = await getPostLikesDetails(postId);
    return details.count;
  }

  /// GET /api/Likes/post/{postId}
  /// Returns both total likes count and whether current user has liked the post.
  Future<PostLikesResult> getPostLikesDetails(String postId, {String? currentUserId}) async {
    try {
      final response = await apiClient.get(
        ApiConstants.likesByPostId.replaceAll('{postId}', postId),
      );
      final data = response.data;

      final count = _extractCount(data);
      bool? isLiked;

      final uid = (currentUserId != null && currentUserId.isNotEmpty)
          ? currentUserId
          : (sl.isRegistered<UserSessionManager>() ? sl<UserSessionManager>().getUser()?.id : null);

      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        isLiked = extractIsLikedFromMap(map);
      }

      if (isLiked == null && uid != null && uid.isNotEmpty) {
        final userList = _extractLikesUserList(data);
        if (userList != null) {
          isLiked = userList.any((u) => _matchesUserId(u, uid));
        }
      }

      return PostLikesResult(count: count, isLiked: isLiked);
    } catch (_) {
      return const PostLikesResult(count: -1, isLiked: null);
    }
  }

  /// Calls POST /api/Likes/toggle — body: { "postId": "...", "title": "..." }
  /// Returns PostLikesResult with new count and confirmed isLiked state.
  Future<PostLikesResult> toggleLike(String postId, {String title = ''}) async {
    dynamic responseData;
    try {
      final res = await apiClient.post(
        ApiConstants.likesToggle,
        data: {'postId': postId, 'title': title},
      );
      responseData = res.data;
    } catch (e) {
      return const PostLikesResult(count: -1, isLiked: null);
    }

    // Check if response contains direct like status/count
    int? directCount;
    bool? directIsLiked;
    if (responseData is Map) {
      final map = Map<String, dynamic>.from(responseData);
      directCount = _extractCountFromMap(map);
      directIsLiked = extractIsLikedFromMap(map);
    }

    // Fetch fresh likes details from server to guarantee accuracy
    try {
      final fresh = await getPostLikesDetails(postId);
      final finalCount = fresh.count >= 0 ? fresh.count : (directCount ?? -1);
      final finalIsLiked = fresh.isLiked ?? directIsLiked;
      return PostLikesResult(count: finalCount, isLiked: finalIsLiked);
    } catch (_) {
      return PostLikesResult(count: directCount ?? -1, isLiked: directIsLiked);
    }
  }

  /// Calls POST /api/PostBookmarks/toggle — body: { "postId": "..." }
  /// Returns true if the post is now bookmarked.
  Future<bool> togglePostBookmark(String postId) async {
    try {
      final response = await apiClient.post(
        ApiConstants.postBookmarksToggle,
        data: {'postId': postId},
      );
      final data = response.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final val = map['isBookmarked'] ?? map['bookmarked'] ?? map['value'] ?? map['isFollowing'];
        if (val is bool) return val;
      }
      return false;
    } catch (_) {
      // Endpoint not implemented yet on backend — ignore silently
      return false;
    }
  }

  /// GET /api/PostBookmarks/my-bookmarks
  /// Returns list of bookmarked posts for the current user.
  Future<List<Map<String, dynamic>>> getMyPostBookmarks({
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    try {
      final response = await apiClient.get(
        ApiConstants.myPostBookmarks,
        queryParameters: {
          'pageNumber': pageNumber,
          'pageSize': pageSize,
        },
      );
      final items = _extractList(response.data, const [
        'items',
        'posts',
        'bookmarks',
        'results',
        'data',
        'result',
        'value',
      ]);
      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      // Endpoint not implemented yet on backend — return empty list
      return [];
    }
  }

  static bool? extractIsLikedFromMap(Map<String, dynamic> map) {
    const keys = [
      'isLiked',
      'isLikedByMe',
      'liked',
      'hasLiked',
      'isLikedByUser',
      'userLiked',
      'isLikedByCurrentUser',
      'is_liked',
      'is_liked_by_me',
      'user_liked',
      'has_liked',
      'is_liked_by_user',
    ];

    for (final key in keys) {
      if (map.containsKey(key)) {
        final value = map[key];
        if (value is bool) return value;
        if (value is String) {
          final lower = value.trim().toLowerCase();
          if (lower == 'true' || lower == '1') return true;
          if (lower == 'false' || lower == '0') return false;
        }
        if (value is num) {
          return value > 0;
        }
      }
    }

    for (final nestedKey in ['data', 'post', 'item', 'userState', 'metadata']) {
      final nested = map[nestedKey];
      if (nested is Map) {
        final res = extractIsLikedFromMap(Map<String, dynamic>.from(nested));
        if (res != null) return res;
      }
    }

    return null;
  }

  bool _matchesUserId(dynamic userItem, String currentUserId) {
    if (userItem == null) return false;
    final cleanCurrent = currentUserId.trim().toLowerCase();
    if (cleanCurrent.isEmpty) return false;

    if (userItem is String) {
      return userItem.trim().toLowerCase() == cleanCurrent;
    }

    if (userItem is Map) {
      final map = Map<String, dynamic>.from(userItem);
      for (final key in ['userId', 'id', 'user_id', 'appUserId', 'ownerId', 'accountUserId', 'creatorId']) {
        final val = map[key];
        if (val != null && val.toString().trim().toLowerCase() == cleanCurrent) {
          return true;
        }
      }
      final nestedUser = map['user'] ?? map['appUser'] ?? map['account'];
      if (nestedUser is Map) {
        return _matchesUserId(nestedUser, currentUserId);
      }
    }

    return false;
  }

  List<dynamic>? _extractLikesUserList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in ['likes', 'items', 'results', 'data', 'users', 'likesList', 'usersList', 'val', 'value']) {
        final val = map[key];
        if (val is List) return val;
      }
    }
    return null;
  }

  List<dynamic> _extractList(dynamic data, List<String> keys) {
    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      return _extractListFromMap(data, keys);
    }

    if (data is Map) {
      return _extractListFromMap(Map<String, dynamic>.from(data), keys);
    }

    return const [];
  }

  List<dynamic> _extractListFromMap(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is List) {
        return value;
      }
    }

    for (final nestedKey in ['data', 'result', 'payload', 'value']) {
      final nested = map[nestedKey];
      if (nested is List) {
        return nested;
      }
      if (nested is Map) {
        final list =
            _extractListFromMap(Map<String, dynamic>.from(nested), keys);
        if (list.isNotEmpty) {
          return list;
        }
      }
    }

    return const [];
  }

  int _extractCount(dynamic data) {
    if (data is List) {
      return data.length;
    }

    if (data is int) {
      return data;
    }

    if (data is String) {
      return int.tryParse(data.trim()) ?? 0;
    }

    if (data is Map<String, dynamic>) {
      return _extractCountFromMap(data);
    }

    if (data is Map) {
      return _extractCountFromMap(Map<String, dynamic>.from(data));
    }

    return 0;
  }

  int _extractCountFromMap(Map<String, dynamic> map) {
    for (final key in [
      'count',
      'totalCount',
      'likesCount',
      'likeCount',
      'total'
    ]) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }

    final list = _extractListFromMap(
      map,
      const ['likes', 'items', 'results', 'data', 'users'],
    );
    if (list.isNotEmpty) {
      return list.length;
    }

    return 0;
  }
}

