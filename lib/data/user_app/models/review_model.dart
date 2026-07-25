import '../../../core/utils/image_url_formatter.dart';

class ReviewModel {
  final String id;
  final String placeId;
  final String userId;
  final double rating;
  final String comment;
  final String reviewImages;
  final DateTime createdAt;
  final String userName;
  final String userImage;
  final String placeName;
  final String placeImageUrl;

  ReviewModel({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.rating,
    required this.comment,
    required this.reviewImages,
    required this.createdAt,
    this.userName = 'User',
    this.userImage = '',
    this.placeName = '',
    this.placeImageUrl = '',
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    // 1. Place nested object if available
    final rawPlaceObj = json['place'] ?? json['Place'] ?? json['targetPlace'] ?? json['businessPlace'];
    final placeMap = rawPlaceObj is Map<String, dynamic>
        ? rawPlaceObj
        : (rawPlaceObj is Map ? Map<String, dynamic>.from(rawPlaceObj) : null);

    // 2. Place Name
    final extractedPlaceName = _firstString([
      json['placeName'],
      json['place_name'],
      json['placeTitle'],
      json['businessName'],
      json['name'],
      placeMap?['name'],
      placeMap?['title'],
      placeMap?['placeName'],
      placeMap?['businessName'],
    ]) ?? '';

    // 3. Place Image URL
    String extractedPlaceImageUrl = ImageUrlFormatter.extractFromMap(json);
    if (extractedPlaceImageUrl.isEmpty && placeMap != null) {
      extractedPlaceImageUrl = ImageUrlFormatter.extractFromMap(placeMap);
    }

    // 4. User Name
    final extractedUserName = _firstString([
      json['userName'],
      json['user_name'],
      json['userFullName'],
      json['user_full_name'],
      json['fullName'],
      json['authorName'],
      json['user']?['name'],
      json['user']?['fullName'],
    ]) ?? 'User';

    // 5. User Image URL
    final userMap = json['user'] is Map ? Map<String, dynamic>.from(json['user']) : <String, dynamic>{};
    final userSearchMap = {...json, ...userMap};
    final extractedUserImage = ImageUrlFormatter.extractFromMap(userSearchMap);

    // 6. CreatedAt Timestamp
    DateTime parsedCreatedAt = DateTime.now();
    for (final key in [
      'createdAt',
      'created_at',
      'createDate',
      'create_date',
      'createdDate',
      'dateCreated',
      'date_created',
      'timestamp',
      'date',
      'time',
      'publishedAt',
      'published_at'
    ]) {
      final val = json[key];
      if (val != null && val.toString().trim().isNotEmpty) {
        final parsed = DateTime.tryParse(val.toString());
        if (parsed != null) {
          parsedCreatedAt = parsed.toLocal();
          break;
        }
      }
    }

    return ReviewModel(
      id: json['id']?.toString() ?? json['reviewId']?.toString() ?? '',
      placeId: json['placeId']?.toString() ?? json['place_id']?.toString() ?? placeMap?['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      comment: json['comment']?.toString() ?? json['content']?.toString() ?? json['reviewText']?.toString() ?? '',
      reviewImages: _extractReviewImage(json),
      createdAt: parsedCreatedAt,
      userName: extractedUserName,
      userImage: extractedUserImage,
      placeName: extractedPlaceName,
      placeImageUrl: extractedPlaceImageUrl,
    );
  }

  static String? _firstString(List<dynamic> items) {
    for (final item in items) {
      if (item != null) {
        final str = item.toString().trim();
        if (str.isNotEmpty && str.toLowerCase() != 'null') return str;
      }
    }
    return null;
  }

  static String _extractReviewImage(Map<String, dynamic> json) {
    for (final key in const [
      'reviewImages',
      'review_images',
      'reviewImage',
      'review_image',
      'reviewImageUrl',
      'review_image_url',
      'imageFile',
      'image_file',
      'imageUrl',
      'image_url',
      'image',
      'photoUrl',
      'photo_url',
      'photo',
    ]) {
      final value = json[key];
      if (value == null) continue;
      final formatted = ImageUrlFormatter.format(value);
      if (formatted.isNotEmpty) return formatted;
    }
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'placeId': placeId,
      'userId': userId,
      'rating': rating,
      'comment': comment,
      'reviewImages': reviewImages,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static final ReviewModel empty = ReviewModel(
    id: '',
    placeId: '',
    userId: '',
    rating: 0,
    comment: '',
    reviewImages: '',
    createdAt: DateTime.now(),
  );
}
