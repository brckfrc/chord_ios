/// Create guild request DTO
class CreateGuildDto {
  final String name;
  final String? description;
  final String? iconUrl;

  CreateGuildDto({
    required this.name,
    this.description,
    this.iconUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty) 'description': description,
      if (iconUrl != null && iconUrl!.isNotEmpty) 'iconUrl': iconUrl,
    };
  }
}

