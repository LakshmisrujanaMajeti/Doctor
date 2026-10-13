class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String roleName;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.roleName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String rName = 'receptionist';
    if (json['role'] != null && json['role'] is Map) {
      rName = json['role']['name'] as String? ?? 'receptionist';
    } else if (json['role_name'] != null) {
      rName = json['role_name'] as String;
    }

    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      roleName: rName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'phone': phone,
    'role_name': roleName,
  };
}

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    UserModel? user,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}
