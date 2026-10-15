class UserModel {
  final int? id;
  final String? supabaseId;
  final String name;
  final String email;
  final String passwordHash;
  final String? profilePhoto;
  final bool isBiometricEnabled;
  final String createdAt;

  const UserModel({
    this.id,
    this.supabaseId,
    required this.name,
    required this.email,
    required this.passwordHash,
    this.profilePhoto,
    this.isBiometricEnabled = false,
    required this.createdAt,
  });

  UserModel copyWith({
    int? id,
    String? supabaseId,
    String? name,
    String? email,
    String? passwordHash,
    String? profilePhoto,
    bool? isBiometricEnabled,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      supabaseId: supabaseId ?? this.supabaseId,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (supabaseId != null) 'supabase_id': supabaseId,
      'name': name,
      'email': email,
      'password_hash': passwordHash,
      'profile_photo': profilePhoto,
      'is_biometric_enabled': isBiometricEnabled ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      supabaseId: map['supabase_id'] as String?,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      passwordHash: map['password_hash'] as String? ?? '',
      profilePhoto: map['profile_photo'] as String?,
      isBiometricEnabled: (map['is_biometric_enabled'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}
