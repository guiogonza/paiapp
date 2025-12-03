class UserEntity {
  final String id;
  final String email;
  final String? name;

  const UserEntity({
    required this.id,
    required this.email,
    this.name,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserEntity &&
        other.id == id &&
        other.email == email &&
        other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ (name?.hashCode ?? 0);
}

