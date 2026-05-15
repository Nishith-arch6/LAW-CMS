class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}

class RegisterRequest {
  final String email;
  final String password;
  final String fullName;
  final String? barNumber;
  final String? phone;
  final String? address;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.fullName,
    this.barNumber,
    this.phone,
    this.address,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'full_name': fullName,
    'bar_number': barNumber,
    'phone': phone,
    'address': address,
  };
}

class AuthResponse {
  final String accessToken;
  final String tokenType;
  final UserModel user;

  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    accessToken: json['access_token'] as String,
    tokenType: json['token_type'] as String,
    user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String? barNumber;
  final String? phone;
  final String? address;
  final String? photoUrl;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.barNumber,
    this.phone,
    this.address,
    this.photoUrl,
    required this.isActive,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as int,
    email: json['email'] as String,
    fullName: json['full_name'] as String,
    barNumber: json['bar_number'] as String?,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    photoUrl: json['photo_url'] as String?,
    isActive: json['is_active'] as bool,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'bar_number': barNumber,
    'phone': phone,
    'address': address,
    'photo_url': photoUrl,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };
}
