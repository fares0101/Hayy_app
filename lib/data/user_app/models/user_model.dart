import '../../../domain/user_app/entities/user_entity.dart';

// User Model
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.city,
    super.profileImagePath,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _readString(json['id']),
      name: _readString(json['name']),
      email: _readString(json['email']),
      city: _readString(json['city']),
      profileImagePath: _readString(json['profileImagePath']),
    );
  }

  factory UserModel.fromApiResponse(Map<String, dynamic> json) {
    return UserModel(
      id: _findValue(json, const ['id', 'userId']),
      name: _findValue(
        json,
        const ['fullName', 'name', 'userName', 'username', 'displayName'],
      ),
      email: _findValue(json, const ['email', 'mail']),
      city: _findValue(
        json,
        const ['city', 'countryRegion', 'country', 'region', 'location'],
      ),
      profileImagePath: _findValue(
        json,
        const [
          'profileImagePath',
          'ProfileImagePath',
          'profileImage',
          'profileImageUrl',
          'imageUrl',
          'avatarUrl',
          'avatar',
          'photoUrl',
          'profilePictureUrl',
          'photo',
          'picture',
          'image',
        ],
      ),
    );
  }

  static const empty = UserModel(id: '', name: '', email: '');

  String get displayName {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    if (email.trim().isNotEmpty) {
      return email.trim();
    }
    return 'Guest User';
  }

  bool get hasCoreData =>
      id.trim().isNotEmpty || name.trim().isNotEmpty || email.trim().isNotEmpty;

  bool get hasRequiredProfile =>
      name.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      city.trim().isNotEmpty;

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? city,
    String? profileImagePath,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      city: city ?? this.city,
      profileImagePath: profileImagePath ?? this.profileImagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'city': city,
      'profileImagePath': profileImagePath,
    };
  }

  static String _findValue(dynamic source, List<String> keys) {
    if (source is Map) {
      for (final key in keys) {
        final directValue = source[key];
        final normalized = _readString(directValue);
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }

      for (final value in source.values) {
        final nestedValue = _findValue(value, keys);
        if (nestedValue.isNotEmpty) {
          return nestedValue;
        }
      }
    }

    if (source is List) {
      for (final item in source) {
        final nestedValue = _findValue(item, keys);
        if (nestedValue.isNotEmpty) {
          return nestedValue;
        }
      }
    }

    return '';
  }

  static String _readString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }
}
