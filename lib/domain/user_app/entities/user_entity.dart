// User Entity
class UserEntity {
  final String id;
  final String name;
  final String email;
  final String city;
  final String profileImagePath;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.city = '',
    this.profileImagePath = '',
  });
}
