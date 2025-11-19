import '../models/dm/dm_dto.dart';
import '../models/auth/user_dto.dart';
import '../models/auth/user_status.dart';
import '../services/api/api_client.dart';

/// DM Repository
class DMRepository {
  final ApiClient _apiClient;

  DMRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetch all DMs for current user
  Future<List<DMDto>> fetchDMs() async {
    try {
      // TODO: Replace with real API endpoint when backend is ready
      // For now, return empty list (backend doesn't have DM endpoints yet)
      // const response = await _apiClient.get('/users/me/dms');
      // return (response.data as List)
      //     .map((json) => DMDto.fromJson(json))
      //     .toList();
      
      // Mock data for testing
      await Future.delayed(const Duration(milliseconds: 500));
      
      final now = DateTime.now();
      final mockDMs = [
        DMDto(
          id: 'dm_1',
          userId: 'current_user_id',
          otherUserId: 'user_1',
          otherUser: UserDto(
            id: 'user_1',
            username: 'johndoe',
            email: 'john@example.com',
            displayName: 'John Doe',
            avatarUrl: null,
            createdAt: now.subtract(const Duration(days: 365)),
            lastSeenAt: now.subtract(const Duration(minutes: 5)),
            status: UserStatus.online,
            customStatus: null,
          ),
          lastMessage: DMLastMessage(
            id: 'msg_1',
            content: 'Hey, how are you doing?',
            createdAt: now.subtract(const Duration(minutes: 10)),
          ),
          unreadCount: 2,
          createdAt: now.subtract(const Duration(days: 7)),
        ),
        DMDto(
          id: 'dm_2',
          userId: 'current_user_id',
          otherUserId: 'user_2',
          otherUser: UserDto(
            id: 'user_2',
            username: 'janedoe',
            email: 'jane@example.com',
            displayName: 'Jane Doe',
            avatarUrl: null,
            createdAt: now.subtract(const Duration(days: 300)),
            lastSeenAt: now.subtract(const Duration(hours: 2)),
            status: UserStatus.idle,
            customStatus: 'Working on a project',
          ),
          lastMessage: DMLastMessage(
            id: 'msg_2',
            content: 'Thanks for the help earlier!',
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
          unreadCount: 0,
          createdAt: now.subtract(const Duration(days: 14)),
        ),
        DMDto(
          id: 'dm_3',
          userId: 'current_user_id',
          otherUserId: 'user_3',
          otherUser: UserDto(
            id: 'user_3',
            username: 'bobsmith',
            email: 'bob@example.com',
            displayName: 'Bob Smith',
            avatarUrl: null,
            createdAt: now.subtract(const Duration(days: 200)),
            lastSeenAt: now.subtract(const Duration(days: 1)),
            status: UserStatus.offline,
            customStatus: null,
          ),
          lastMessage: DMLastMessage(
            id: 'msg_3',
            content: 'See you tomorrow!',
            createdAt: now.subtract(const Duration(days: 2)),
          ),
          unreadCount: 0,
          createdAt: now.subtract(const Duration(days: 30)),
        ),
        DMDto(
          id: 'dm_4',
          userId: 'current_user_id',
          otherUserId: 'user_4',
          otherUser: UserDto(
            id: 'user_4',
            username: 'alicewonder',
            email: 'alice@example.com',
            displayName: 'Alice Wonder',
            avatarUrl: null,
            createdAt: now.subtract(const Duration(days: 150)),
            lastSeenAt: now.subtract(const Duration(minutes: 30)),
            status: UserStatus.dnd,
            customStatus: 'In a meeting',
          ),
          lastMessage: DMLastMessage(
            id: 'msg_4',
            content: 'Can we reschedule?',
            createdAt: now.subtract(const Duration(minutes: 45)),
          ),
          unreadCount: 1,
          createdAt: now.subtract(const Duration(days: 5)),
        ),
      ];
      
      return mockDMs;
    } catch (e) {
      throw Exception('Failed to fetch DMs: $e');
    }
  }

  /// Get DM by ID
  Future<DMDto> getDMById(String dmId) async {
    try {
      // TODO: Replace with real API endpoint when backend is ready
      // const response = await _apiClient.get('/dms/$dmId');
      // return DMDto.fromJson(response.data);
      
      // Mock implementation
      final dms = await fetchDMs();
      final dm = dms.firstWhere(
        (dm) => dm.id == dmId,
        orElse: () => throw Exception('DM not found'),
      );
      return dm;
    } catch (e) {
      throw Exception('Failed to get DM: $e');
    }
  }

  /// Create a new DM with a user
  Future<DMDto> createDM(String userId) async {
    try {
      // TODO: Replace with real API endpoint when backend is ready
      // const response = await _apiClient.post('/users/$userId/dm');
      // return DMDto.fromJson(response.data);
      
      // Mock implementation
      await Future.delayed(const Duration(milliseconds: 300));
      
      final now = DateTime.now();
      final mockUser = UserDto(
        id: userId,
        username: 'user_$userId',
        email: 'user$userId@example.com',
        displayName: 'User $userId',
        avatarUrl: null,
        createdAt: now.subtract(const Duration(days: 100)),
        lastSeenAt: now,
        status: UserStatus.online,
        customStatus: null,
      );
      
      final newDM = DMDto(
        id: 'dm_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'current_user_id',
        otherUserId: userId,
        otherUser: mockUser,
        lastMessage: null,
        unreadCount: 0,
        createdAt: now,
      );
      
      return newDM;
    } catch (e) {
      throw Exception('Failed to create DM: $e');
    }
  }
}

