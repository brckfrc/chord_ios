/// Invite code/link parser utility
class InviteParser {
  /// Parse invite code from input string
  /// Supports both full links and code-only formats
  /// 
  /// Examples:
  /// - "https://chord.app/invite/abc123XY" -> "abc123XY"
  /// - "http://localhost:5049/invite/abc123XY" -> "abc123XY"
  /// - "abc123XY" -> "abc123XY"
  /// 
  /// Returns null if input is invalid or empty
  static String? parseInviteCode(String? input) {
    if (input == null || input.trim().isEmpty) {
      return null;
    }

    final trimmed = input.trim();

    // Check if it's a URL (contains http:// or https://)
    if (trimmed.contains('http://') || trimmed.contains('https://')) {
      // Extract code from URL using regex
      // Pattern: /invite/([a-zA-Z0-9]+)
      final regex = RegExp(r'/invite/([a-zA-Z0-9]+)', caseSensitive: false);
      final match = regex.firstMatch(trimmed);
      
      if (match != null && match.groupCount >= 1) {
        return match.group(1);
      }
      
      // If regex doesn't match, try to extract from end of URL
      // Some URLs might have query parameters or fragments
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final pathSegments = uri.pathSegments;
        final inviteIndex = pathSegments.indexWhere(
          (segment) => segment.toLowerCase() == 'invite',
        );
        
        if (inviteIndex >= 0 && inviteIndex < pathSegments.length - 1) {
          return pathSegments[inviteIndex + 1];
        }
      }
      
      return null;
    }

    // If it's not a URL, assume it's just the code
    // Validate that it contains only alphanumeric characters
    if (RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  /// Validate invite code format
  /// Returns true if code is valid (alphanumeric, reasonable length)
  static bool isValidInviteCode(String? code) {
    if (code == null || code.isEmpty) {
      return false;
    }

    // Backend uses 8-character codes, but we'll accept any reasonable length
    if (code.length < 4 || code.length > 32) {
      return false;
    }

    // Only alphanumeric characters
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(code);
  }
}
