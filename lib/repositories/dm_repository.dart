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
        DMDto(
          id: 'dm_5',
          userId: 'current_user_id',
          otherUserId: 'user_5',
          otherUser: UserDto(
            id: 'user_5',
            username: 'charliebrown',
            email: 'charlie@example.com',
            displayName: 'Charlie Brown',
            avatarUrl: null,
            createdAt: now.subtract(const Duration(days: 60)),
            lastSeenAt: now.subtract(const Duration(minutes: 10)),
            status: UserStatus.online,
            customStatus: 'Playing football',
          ),
          lastMessage: DMLastMessage(
            id: 'msg_5',
            content: 'Good grief!',
            createdAt: now.subtract(const Duration(hours: 3)),
          ),
          unreadCount: 0,
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        DMDto(
          id: 'dm_6',
          userId: 'current_user_id',
          otherUserId: 'user_6',
          otherUser: UserDto(
            id: 'user_6',
            username: 'dianaprince',
            email: 'diana@example.com',
            displayName: 'Diana Prince',
            avatarUrl: null,
            createdAt: now.subtract(const Duration(days: 400)),
            lastSeenAt: now.subtract(const Duration(hours: 5)),
            status: UserStatus.idle,
            customStatus: 'Saving the world',
          ),
          lastMessage: DMLastMessage(
            id: 'msg_6',
            content: 'Be there in 5.',
            createdAt: now.subtract(const Duration(hours: 4)),
          ),
          unreadCount: 0,
          createdAt: now.subtract(const Duration(days: 20)),
        ),
        DMDto(
          id: 'dm_7',
          userId: 'current_user_id',
          otherUserId: 'user_7',
          otherUser: UserDto(
            id: 'user_7',
            username: 'edwardelric',
            email: 'edward@example.com',
            displayName: 'Edward Elric',
            avatarUrl: null,
            createdAt: now.subtract(const Duration(days: 100)),
            lastSeenAt: now.subtract(const Duration(days: 2)),
            status: UserStatus.offline,
            customStatus: 'Alchemy practice',
          ),
          lastMessage: DMLastMessage(
            id: 'msg_7',
            content: 'Don\'t call me short!',
            createdAt: now.subtract(const Duration(days: 1)),
          ),
          unreadCount: 3,
          createdAt: now.subtract(const Duration(days: 8)),
        ),
        DMDto(
          id: 'dm_8',
          userId: 'current_user_id',
          otherUserId: 'user_8',
          otherUser: UserDto(
            id: 'user_8',
            username: 'frankcastle',
            email: 'frank@example.com',
            displayName: 'Frank Castle',
            avatarUrl: null,
            createdAt: now.subtract(const Duration(days: 50)),
            lastSeenAt: now.subtract(const Duration(minutes: 1)),
            status: UserStatus.dnd,
            customStatus: 'Busy',
          ),
          lastMessage: DMLastMessage(
            id: 'msg_8',
            content: '...',
            createdAt: now.subtract(const Duration(minutes: 20)),
          ),
          unreadCount: 0,
          createdAt: now.subtract(const Duration(days: 2)),
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

