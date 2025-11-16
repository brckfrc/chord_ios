/// Login request DTO
class LoginDto {
  final String emailOrUsername;
  final String password;

  LoginDto({required this.emailOrUsername, required this.password});

  Map<String, dynamic> toJson() {
    return {'emailOrUsername': emailOrUsername, 'password': password};
  }
}
