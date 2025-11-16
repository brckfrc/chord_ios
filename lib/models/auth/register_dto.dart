/// Register request DTO
class RegisterDto {
  final String username;
  final String email;
  final String password;
  final String? displayName;

  RegisterDto({
    required this.username,
    required this.email,
    required this.password,
    this.displayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'password': password,
      if (displayName != null && displayName!.isNotEmpty)
        'displayName': displayName,
    };
  }
}
