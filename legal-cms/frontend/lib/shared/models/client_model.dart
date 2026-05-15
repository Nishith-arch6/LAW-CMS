import 'case_model.dart';

class ClientModel {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? notes;
  final int advocateId;
  final String? createdAt;

  ClientModel({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.notes,
    required this.advocateId,
    this.createdAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) => ClientModel(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    address: json['address'] as String?,
    notes: json['notes'] as String?,
    advocateId: json['advocate_id'] as int,
    createdAt: json['created_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'notes': notes,
  };
}

class ClientCreateRequest {
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? notes;

  ClientCreateRequest({
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'address': address,
    'notes': notes,
  };
}
