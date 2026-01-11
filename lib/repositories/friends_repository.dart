import '../models/friends/friendship_dto.dart';
import '../services/api/api_client.dart';

/// Friends Repository
class FriendsRepository {
  final ApiClient _apiClient;

  FriendsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetch all friends (accepted friendships)
  Future<List<FriendshipDto>> getFriends() async {
    try {
      final response = await _apiClient.get('/Friends');
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => FriendshipDto.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map) {
        final responseMap = response.data as Map<String, dynamic>;
        if (responseMap.containsKey('data') && responseMap['data'] is List) {
          return (responseMap['data'] as List)
              .map((json) => FriendshipDto.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      throw Exception('Unexpected response format from /Friends endpoint');
    } catch (e) {
      throw Exception('Failed to fetch friends: $e');
    }
  }

  /// Fetch pending friend requests
  Future<List<FriendshipDto>> getPendingRequests() async {
    try {
      final response = await _apiClient.get('/Friends/pending');
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => FriendshipDto.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map) {
        final responseMap = response.data as Map<String, dynamic>;
        if (responseMap.containsKey('data') && responseMap['data'] is List) {
          return (responseMap['data'] as List)
              .map((json) => FriendshipDto.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      throw Exception('Unexpected response format from /Friends/pending endpoint');
    } catch (e) {
      throw Exception('Failed to fetch pending requests: $e');
    }
  }

  /// Fetch blocked users
  Future<List<FriendshipDto>> getBlockedUsers() async {
    try {
      final response = await _apiClient.get('/Friends/blocked');
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => FriendshipDto.fromJson(json as Map<String, dynamic>))
            .toList();
      } else if (response.data is Map) {
        final responseMap = response.data as Map<String, dynamic>;
        if (responseMap.containsKey('data') && responseMap['data'] is List) {
          return (responseMap['data'] as List)
              .map((json) => FriendshipDto.fromJson(json as Map<String, dynamic>))
              .toList();
        }
      }
      
      throw Exception('Unexpected response format from /Friends/blocked endpoint');
    } catch (e) {
      throw Exception('Failed to fetch blocked users: $e');
    }
  }

  /// Send friend request
  /// Backend accepts username and converts it to userId internally
  Future<FriendshipDto> sendFriendRequest(String username) async {
    try {
      final response = await _apiClient.post(
        '/Friends/request',
        data: {'username': username},
      );
      return FriendshipDto.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to send friend request: $e');
    }
  }

  /// Accept friend request
  Future<void> acceptRequest(String friendshipId) async {
    try {
      await _apiClient.post('/Friends/$friendshipId/accept');
    } catch (e) {
      throw Exception('Failed to accept friend request: $e');
    }
  }

  /// Decline friend request
  Future<void> declineRequest(String friendshipId) async {
    try {
      await _apiClient.post('/Friends/$friendshipId/decline');
    } catch (e) {
      throw Exception('Failed to decline friend request: $e');
    }
  }

  /// Remove friend (unfriend)
  Future<void> unfriend(String friendshipId) async {
    try {
      await _apiClient.delete('/Friends/$friendshipId');
    } catch (e) {
      throw Exception('Failed to unfriend: $e');
    }
  }

  /// Block user
  Future<void> blockUser(String userId) async {
    try {
      await _apiClient.post('/Friends/block/$userId');
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  /// Unblock user
  Future<void> unblockUser(String userId) async {
    try {
      await _apiClient.delete('/Friends/block/$userId');
    } catch (e) {
      throw Exception('Failed to unblock user: $e');
    }
  }
}
