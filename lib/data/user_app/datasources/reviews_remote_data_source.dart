import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/image_url_formatter.dart';
import '../models/review_model.dart';

class ReviewsRemoteDataSource {
  final ApiClient apiClient;

  ReviewsRemoteDataSource({required this.apiClient});

  /// GET /api/Reviews/user/{userId} — paginated list of reviews by a specific user
  Future<List<ReviewModel>> getUserReviews(
    String userId, {
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    try {
      final endpoint = ApiConstants.userReviews.replaceAll('{userId}', userId);
      final response = await apiClient.get(
        endpoint,
        queryParameters: {
          'pageNumber': pageNumber,
          'pageSize': pageSize,
        },
      );

      final reviews = _parseReviewList(response.data);
      return await _enrichUserReviewsWithPlaceDetails(reviews);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to load user reviews: $e');
    }
  }

  Future<List<ReviewModel>> _enrichUserReviewsWithPlaceDetails(List<ReviewModel> reviews) async {
    if (reviews.isEmpty) return reviews;
    final placeCache = <String, Map<String, dynamic>>{};

    final enriched = await Future.wait(reviews.map((r) async {
      if (r.placeId.isEmpty) return r;
      final hasPlaceName = r.placeName.trim().isNotEmpty && r.placeName != 'Unknown Place';
      final hasPlaceImage = r.placeImageUrl.trim().isNotEmpty;
      if (hasPlaceName && hasPlaceImage) return r;

      Map<String, dynamic>? placeData = placeCache[r.placeId];
      if (placeData == null) {
        try {
          final res = await apiClient.get(ApiConstants.placeDetails.replaceAll('{id}', r.placeId));
          final raw = res.data;
          if (raw is Map<String, dynamic>) {
            placeData = (raw['place'] is Map) ? Map<String, dynamic>.from(raw['place'] as Map) : raw;
          } else if (raw is Map) {
            placeData = Map<String, dynamic>.from(raw);
          }
          if (placeData != null) placeCache[r.placeId] = placeData;
        } catch (_) {}
      }

      if (placeData != null && placeData.isNotEmpty) {
        final fetchedName = (placeData['name'] ?? placeData['title'] ?? placeData['placeName'] ?? '').toString().trim();
        final fetchedImage = ImageUrlFormatter.extractFromMap(placeData);

        return ReviewModel(
          id: r.id,
          placeId: r.placeId,
          userId: r.userId,
          rating: r.rating,
          comment: r.comment,
          reviewImages: r.reviewImages,
          createdAt: r.createdAt,
          userName: r.userName,
          userImage: r.userImage,
          placeName: hasPlaceName ? r.placeName : (fetchedName.isNotEmpty ? fetchedName : r.placeName),
          placeImageUrl: hasPlaceImage ? r.placeImageUrl : (fetchedImage.isNotEmpty ? fetchedImage : r.placeImageUrl),
        );
      }
      return r;
    }));

    return enriched;
  }

  Future<List<ReviewModel>> getPlaceReviews(String placeId, {int pageNumber = 1, int pageSize = 10}) async {
    try {
      final endpoint = ApiConstants.placeReviews.replaceAll('{placeId}', placeId);
      final response = await apiClient.get(
        endpoint,
        queryParameters: {
          'pageNumber': pageNumber,
          'pageSize': pageSize,
        },
      );
      return _parseReviewList(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to load reviews: $e');
    }
  }

  Future<ReviewModel> addReview({
    required String placeId,
    required double rating,
    required String comment,
    String? imageFilePath,
  }) async {
    try {
      final userId = apiClient.userSessionManager?.getUser()?.id ?? '';
      final imagePath = imageFilePath?.trim() ?? '';
      final formData = FormData.fromMap({
        'PlaceId': placeId,
        'UserId': userId.isNotEmpty
            ? userId
            : '00000000-0000-0000-0000-000000000000',
        'Rating': rating.toInt(),
        'Comment': comment,
        if (imagePath.isNotEmpty)
          'ImageFile': await MultipartFile.fromFile(
            imagePath,
            filename: _fileNameFromPath(imagePath),
          ),
      });

      final response = await apiClient.dio.post(
        ApiConstants.reviews,
        data: formData,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );

      final data = response.data;
      if (data != null && data is Map<String, dynamic>) {
        if (imagePath.isNotEmpty &&
            _extractReviewImage(data).trim().isEmpty) {
          data['reviewImages'] = imagePath;
        }
        final currentUser = apiClient.userSessionManager?.getUser();
        if (currentUser != null) {
          // Always use the locally-saved name/image — they are guaranteed to be
          // the most up-to-date (updated on every profile save), whereas the
          // server may still echo the previous name in the review response.
          if (currentUser.name.trim().isNotEmpty) {
            data['userName'] = currentUser.name;
          }
          if (currentUser.profileImagePath.trim().isNotEmpty) {
            data['userImage'] = currentUser.profileImagePath;
          }
        }
        return ReviewModel.fromJson(data);
      }
      return ReviewModel.empty;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to add review: $e');
    }
  }

  String _fileNameFromPath(String path) {
    final parts = path.split(RegExp(r'[\\/]'));
    final name = parts.isNotEmpty ? parts.last.trim() : '';
    return name.isNotEmpty ? name : 'review_image.jpg';
  }

  String _extractReviewImage(Map<String, dynamic> data) {
    for (final key in const [
      'reviewImages',
      'review_images',
      'reviewImage',
      'review_image',
      'reviewImageUrl',
      'review_image_url',
      'imageUrl',
      'image_url',
      'imageFile',
      'image_file',
      'image',
    ]) {
      final value = data[key];
      if (value == null) continue;
      final formatted = ImageUrlFormatter.format(value);
      if (formatted.isNotEmpty) return formatted;
    }
    return '';
  }

  Future<ReviewModel> updateReview({
    required String reviewId,
    required double rating,
    required String comment,
    /// Local file path of a newly selected image.
    String? imageFilePath,
    /// Existing remote image URL — sent as-is when no new image is picked.
    String? existingImageUrl,
  }) async {
    try {
      final endpoint = ApiConstants.updateReview.replaceAll('{reviewId}', reviewId);

      final newPath = imageFilePath?.trim() ?? '';
      final keepUrl = existingImageUrl?.trim() ?? '';

      final formMap = <String, dynamic>{
        'Rating': rating.toInt(),
        'Comment': comment,
      };

      if (newPath.isNotEmpty) {
        // Upload a freshly picked image
        formMap['ImageFile'] = await MultipartFile.fromFile(
          newPath,
          filename: _fileNameFromPath(newPath),
        );
      } else if (keepUrl.isNotEmpty) {
        // Keep the old image by passing its URL as a text field
        formMap['ReviewImages'] = keepUrl;
      }

      final response = await apiClient.dio.put(
        endpoint,
        data: FormData.fromMap(formMap),
        options: Options(contentType: Headers.multipartFormDataContentType),
      );

      final data = response.data;
      if (data != null && data is Map<String, dynamic>) {
        // If the server returned no image but we uploaded one, fall back locally
        if (newPath.isNotEmpty && _extractReviewImage(data).trim().isEmpty) {
          data['reviewImages'] = newPath;
        }
        // Inject current user's name/image from session
        final currentUser = apiClient.userSessionManager?.getUser();
        if (currentUser != null) {
          if (currentUser.name.trim().isNotEmpty) {
            data['userName'] = currentUser.name;
          }
          if (currentUser.profileImagePath.trim().isNotEmpty) {
            data['userImage'] = currentUser.profileImagePath;
          }
        }
        return ReviewModel.fromJson(data);
      }
      return ReviewModel.empty;
    } on DioException catch (e) {
      throw _handleError(e);
    } catch (e) {
      throw Exception('Failed to update review: $e');
    }
  }

  /// Parses any common API response shape into a list of [ReviewModel].
  List<ReviewModel> _parseReviewList(dynamic data) {
    List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      items = (data['items'] ?? data['data'] ?? data['results'] ?? data['value'] ?? []) as List;
    } else {
      return [];
    }

    final currentUser = apiClient.userSessionManager?.getUser();
    final currentUserId = currentUser?.id.trim() ?? '';
    final currentUserName = currentUser?.name.trim() ?? '';
    final currentUserImage = currentUser?.profileImagePath.trim() ?? '';

    return items.whereType<Map<String, dynamic>>().map((json) {
      final model = ReviewModel.fromJson(json);
      if (currentUserId.isNotEmpty && model.userId.trim().toLowerCase() == currentUserId.toLowerCase()) {
        final hasImage = model.userImage.trim().isNotEmpty;
        final hasName = model.userName.trim().isNotEmpty && model.userName != 'User';
        return ReviewModel(
          id: model.id,
          placeId: model.placeId,
          userId: model.userId,
          rating: model.rating,
          comment: model.comment,
          reviewImages: model.reviewImages,
          createdAt: model.createdAt,
          userName: hasName ? model.userName : (currentUserName.isNotEmpty ? currentUserName : 'User'),
          userImage: hasImage ? model.userImage : currentUserImage,
          placeName: model.placeName,
          placeImageUrl: model.placeImageUrl,
        );
      }
      return model;
    }).toList();
  }


  Exception _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic>) {
        if (data['message'] != null) {
          return Exception(data['message']);
        }
        if (data['errors'] != null) {
          final errors = data['errors'];
          if (errors is Map && errors.isNotEmpty) {
            final firstError = errors.values.first;
            if (firstError is List && firstError.isNotEmpty) {
              return Exception(firstError.first.toString());
            }
            return Exception(firstError.toString());
          }
        }
        if (data['title'] != null) {
          return Exception(data['title']);
        }
      } else if (data is String && data.isNotEmpty) {
        return Exception(data);
      }
      return Exception('Server error: ${e.response!.statusCode}');
    }
    return Exception('Network error: ${e.message}');
  }
}
