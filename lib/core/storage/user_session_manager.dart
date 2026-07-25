import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/user_app/models/user_model.dart';
import '../helpers/profile_image_helper.dart';

class UserSessionManager {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'auth_user';
  static const String _recentSearchesKeyPrefix = 'recent_searches';
  static const String _interestPreferencesKeyPrefix = 'interest_preferences';

  final SharedPreferences sharedPreferences;

  UserSessionManager(this.sharedPreferences);

  Future<void> saveAuthSession(Map<String, dynamic> response) async {
    print('Saving Auth Session - Response: $response');

    final token = _extractToken(response);
    final refreshToken = _extractRefreshToken(response);
    print(
        'Extracted Token: ${token.isEmpty ? "EMPTY" : "Found (${token.length} chars)"}');
    print(
        'Extracted Refresh Token: ${refreshToken.isEmpty ? "EMPTY" : "Found (${refreshToken.length} chars)"}');

    if (token.isNotEmpty) {
      await sharedPreferences.setString(_tokenKey, token);
    }
    if (refreshToken.isNotEmpty) {
      await sharedPreferences.setString(_refreshTokenKey, refreshToken);
    }

    final existingUser = getUser() ?? UserModel.empty;
    final apiUser = UserModel.fromApiResponse(response);

    // Local paths (user-picked photos) take priority.
    // Fall back to the URL returned by the API if nothing is stored locally.
    final existingImage =
        ProfileImageHelper.resolve(existingUser.profileImagePath);
    final apiImage = ProfileImageHelper.resolve(apiUser.profileImagePath);
    final resolvedImage = existingImage.isNotEmpty ? existingImage : apiImage;

    final user = existingUser.copyWith(
      id: apiUser.id.isNotEmpty ? apiUser.id : existingUser.id,
      name: apiUser.name.isNotEmpty ? apiUser.name : existingUser.name,
      email: apiUser.email.isNotEmpty ? apiUser.email : existingUser.email,
      city: apiUser.city.isNotEmpty ? apiUser.city : existingUser.city,
      profileImagePath: resolvedImage,
    );

    print('Parsed User from Response: ${user.toJson()}');
    print('User has core data: ${user.hasCoreData}');

    // Always save user even if incomplete
    await saveUser(user);
    print('User saved successfully');
  }

  Future<void> saveUser(UserModel user) async {
    final normalizedImage = ProfileImageHelper.resolve(user.profileImagePath);
    final normalizedUser = user.copyWith(profileImagePath: normalizedImage);
    await sharedPreferences.setString(
      _userKey,
      jsonEncode(normalizedUser.toJson()),
    );
  }

  Future<void> mergeUserData({
    String? id,
    String? name,
    String? email,
    String? city,
    String? profileImagePath,
  }) async {
    final existingUser = getUser() ?? UserModel.empty;

    await saveUser(
      existingUser.copyWith(
        id: _coalesceValue(id, existingUser.id),
        name: _coalesceValue(name, existingUser.name),
        email: _coalesceValue(email, existingUser.email),
        city: _coalesceValue(city, existingUser.city),
        profileImagePath: _coalesceValue(
          ProfileImageHelper.resolve(profileImagePath),
          existingUser.profileImagePath,
        ),
      ),
    );
  }

  Future<void> clearUserData() async {
    await sharedPreferences.remove(_userKey);
  }

  UserModel? getUser() {
    final rawUser = sharedPreferences.getString(_userKey);
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return UserModel.fromJson(decoded);
      }
      if (decoded is Map) {
        return UserModel.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String? getToken() {
    final token = sharedPreferences.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  String? getRefreshToken() {
    final token = sharedPreferences.getString(_refreshTokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  Future<void> clearSession() async {
    await sharedPreferences.remove(_tokenKey);
    await sharedPreferences.remove(_refreshTokenKey);
    await sharedPreferences.remove(_userKey);
  }

  List<String> getRecentSearches({String? userId}) {
    final key = _buildRecentSearchesKey(userId);
    final values = sharedPreferences.getStringList(key) ?? const [];
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<void> saveRecentSearch(
    String query, {
    String? userId,
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return;
    }

    final updated = getRecentSearches(userId: userId)
      ..removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase())
      ..insert(0, trimmed);

    await sharedPreferences.setStringList(
      _buildRecentSearchesKey(userId),
      updated.take(limit).toList(),
    );
  }

  Future<void> removeRecentSearch(
    String query, {
    String? userId,
  }) async {
    final trimmed = query.trim();
    final updated = getRecentSearches(userId: userId)
      ..removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());

    await sharedPreferences.setStringList(
      _buildRecentSearchesKey(userId),
      updated,
    );
  }

  Future<void> clearRecentSearches({String? userId}) async {
    await sharedPreferences.remove(_buildRecentSearchesKey(userId));
  }

  Future<void> saveInterestPreferences({
    String? userId,
    required List<String> selectedCategoryIds,
    required List<String> selectedCategoryLabels,
    required List<String> selectedSubInterestIds,
    required List<String> selectedSubInterestLabels,
    required String location,
  }) async {
    final payload = <String, dynamic>{
      'completed': true,
      'selectedCategoryIds': selectedCategoryIds,
      'selectedCategoryLabels': selectedCategoryLabels,
      'selectedSubInterestIds': selectedSubInterestIds,
      'selectedSubInterestLabels': selectedSubInterestLabels,
      'location': location.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await sharedPreferences.setString(
      _buildInterestPreferencesKey(userId),
      jsonEncode(payload),
    );
  }

  Map<String, dynamic>? getInterestPreferences({String? userId}) {
    final raw =
        sharedPreferences.getString(_buildInterestPreferencesKey(userId));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  bool hasCompletedInterests({String? userId}) {
    final preferences = getInterestPreferences(userId: userId);
    if (preferences == null) {
      return false;
    }

    return preferences['completed'] == true;
  }

  Future<void> clearInterestPreferences({String? userId}) async {
    await sharedPreferences.remove(_buildInterestPreferencesKey(userId));
  }

  // ── Liked Posts Persistence ──────────────────────────────────────────────
  static const String _likedPostsKeyPrefix = 'liked_posts';

  Set<String> getLikedPostIds({String? userId}) {
    final effectiveUserId = userId ?? getUser()?.id;
    final key = _buildUserScopedKey(_likedPostsKeyPrefix, effectiveUserId);
    final values = sharedPreferences.getStringList(key) ?? const [];
    return values.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> saveLikedPostId(String postId, {String? userId}) async {
    final trimmed = postId.trim();
    if (trimmed.isEmpty) return;
    final effectiveUserId = userId ?? getUser()?.id;
    final set = getLikedPostIds(userId: effectiveUserId)..add(trimmed);
    final key = _buildUserScopedKey(_likedPostsKeyPrefix, effectiveUserId);
    await sharedPreferences.setStringList(key, set.toList());
  }

  Future<void> removeLikedPostId(String postId, {String? userId}) async {
    final trimmed = postId.trim();
    if (trimmed.isEmpty) return;
    final effectiveUserId = userId ?? getUser()?.id;
    final set = getLikedPostIds(userId: effectiveUserId)..remove(trimmed);
    final key = _buildUserScopedKey(_likedPostsKeyPrefix, effectiveUserId);
    await sharedPreferences.setStringList(key, set.toList());
  }

  bool isPostLikedLocally(String postId, {String? userId}) {
    if (postId.trim().isEmpty) return false;
    final effectiveUserId = userId ?? getUser()?.id;
    return getLikedPostIds(userId: effectiveUserId).contains(postId.trim());
  }

  String _coalesceValue(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }

  String _extractToken(Map<String, dynamic> response) {
    const tokenKeys = ['token', 'accessToken', 'jwtToken'];

    for (final key in tokenKeys) {
      final value = response[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      for (final key in tokenKeys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    return '';
  }

  String _extractRefreshToken(Map<String, dynamic> response) {
    const refreshTokenKeys = ['refreshToken', 'refresh_token'];

    for (final key in refreshTokenKeys) {
      final value = response[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      for (final key in refreshTokenKeys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    return '';
  }

  String _buildRecentSearchesKey(String? userId) {
    return _buildUserScopedKey(_recentSearchesKeyPrefix, userId);
  }

  String _buildInterestPreferencesKey(String? userId) {
    return _buildUserScopedKey(_interestPreferencesKeyPrefix, userId);
  }

  String _buildUserScopedKey(String prefix, String? userId) {
    final normalizedUserId = userId?.trim();
    if (normalizedUserId == null || normalizedUserId.isEmpty) {
      return '$prefix.guest';
    }
    return '$prefix.$normalizedUserId';
  }
}
