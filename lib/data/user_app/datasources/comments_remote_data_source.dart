import '../../../core/constants/api_constants.dart';
import '../../../core/helpers/profile_image_helper.dart';
import '../../../core/network/api_client.dart';

class CommentsRemoteDataSource {
  final ApiClient apiClient;

  CommentsRemoteDataSource(this.apiClient);

  // ── GET /api/Comments/{postId} ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getComments(
    String postId, {
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final response = await apiClient.get(
      ApiConstants.commentsByPostId.replaceAll('{postId}', postId),
      queryParameters: {
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      },
    );

    final raw = response.data;

    // Handle paginated wrapper OR plain list
    List<dynamic> items = const [];
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      for (final key in ['items', 'comments', 'results', 'data', 'value']) {
        if (map[key] is List) {
          items = map[key] as List;
          break;
        }
      }
    }

    final currentUser = apiClient.userSessionManager?.getUser();
    final currentUserId = currentUser?.id.trim() ?? '';
    final currentUserImage =
        ProfileImageHelper.resolve(currentUser?.profileImagePath);
    final currentUserName = currentUser?.name.trim() ?? '';

    return items.whereType<Map>().map((e) {
      final comment = Map<String, dynamic>.from(e);
      // Keep the logged-in user's comments in sync with the latest local
      // session profile data, even if the API returns stale author fields.
      if (currentUserId.isNotEmpty) {
        final userId = _extractUserId(comment);
        if (userId.trim().toLowerCase() == currentUserId.trim().toLowerCase()) {
          final user = comment['user'];
          if (user is Map) {
            final userMap = Map<String, dynamic>.from(user);
            if (currentUserImage.isNotEmpty) {
              userMap['avatar'] = currentUserImage;
            }
            if (currentUserName.isNotEmpty) userMap['name'] = currentUserName;
            comment['user'] = userMap;
          } else {
            // No nested user object — inject flat fields
            if (currentUserImage.isNotEmpty) {
              comment['userAvatar'] = currentUserImage;
            }
            if (currentUserName.isNotEmpty) {
              comment['userName'] = currentUserName;
            }
          }
        }
      }
      return comment;
    }).toList();
  }

  // ── POST /api/Comments ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    final body = <String, dynamic>{
      'postId': postId,
      'content': content,
      'parentCommentId': (parentCommentId != null && parentCommentId.isNotEmpty)
          ? parentCommentId
          : null,
    };

    final response = await apiClient.post(
      ApiConstants.comments,
      data: body,
    );

    final data = response.data;
    final result =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

    // Inject current user's name and image — server rarely returns them on POST.
    final currentUser = apiClient.userSessionManager?.getUser();
    if (currentUser != null) {
      final existingUser = result['user'];
      final userMap = existingUser is Map
          ? Map<String, dynamic>.from(existingUser)
          : <String, dynamic>{};

      if (currentUser.name.trim().isNotEmpty) {
        userMap['name'] = currentUser.name.trim();
      }
      final currentUserImage =
          ProfileImageHelper.resolve(currentUser.profileImagePath);
      if (currentUserImage.isNotEmpty) {
        userMap['avatar'] = currentUserImage;
      }
      if (currentUser.id.trim().isNotEmpty) {
        userMap['id'] = currentUser.id.trim();
      }
      result['user'] = userMap;
    }

    return result;
  }

  // ── PUT /api/Comments/{commentId} ──────────────────────────────────────────
  Future<void> updateComment({
    required String commentId,
    required String content,
  }) async {
    await apiClient.put(
      ApiConstants.updateComment.replaceAll('{commentId}', commentId),
      data: {'content': content},
    );
  }

  // ── DELETE /api/Comments/{commentId} ──────────────────────────────────────
  Future<void> deleteComment(String commentId) async {
    await apiClient.delete(
      ApiConstants.deleteComment.replaceAll('{commentId}', commentId),
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _extractUserId(Map<String, dynamic> comment) {
    final user = comment['user'] ?? comment['author'];
    if (user is Map) {
      return _asString(user['id'] ?? user['userId']);
    }
    return _asString(comment['userId'] ?? comment['authorId']);
  }

  String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}
