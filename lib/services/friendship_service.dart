import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friendship_model.dart';

/// Service pentru gestionarea prieteniilor și blocărilor
class FriendshipService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Caută useri disponibili (nu sunt prieteni, nu au cerere pending, nu sunt blocați)
  Future<List<Map<String, dynamic>>> searchAvailableUsers(String query) async {
    if (currentUserId == null) return [];

    try {
      // 1. Găsește userii care match-uiesc query-ul
      final searchResults = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .neq('id', currentUserId!) // Exclude pe sine
          .or('full_name.ilike.%$query%,username.ilike.%$query%')
          .limit(20);

      if (searchResults.isEmpty) return [];

      // 2. Găsește toate relațiile existente (friendships)
      final friendships = await _supabase
          .from('friendships')
          .select('sender_id, receiver_id, status')
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId');

      // 3. Găsește userii blocați
      final blocks = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', currentUserId!);

      final blockedIds = blocks.map((b) => b['blocked_id'] as String).toSet();

      // 4. Filtrează userii care:
      // - NU sunt deja prieteni (accepted)
      // - NU au cerere pending
      // - NU sunt blocați
      final existingRelations = <String>{};
      for (final friendship in friendships) {
        final senderId = friendship['sender_id'] as String;
        final receiverId = friendship['receiver_id'] as String;
        final status = friendship['status'] as String;

        // Exclude dacă e accepted sau pending
        if (status == 'accepted' || status == 'pending') {
          final otherId = senderId == currentUserId ? receiverId : senderId;
          existingRelations.add(otherId);
        }
      }

      // Filtrează rezultatele
      final availableUsers = (searchResults as List)
          .where((user) {
            final userId = user['id'] as String;
            return !existingRelations.contains(userId) && !blockedIds.contains(userId);
          })
          .toList();

      return availableUsers.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      return [];
    }
  }

  /// Trimite cerere de prietenie
  Future<bool> sendFriendRequest(String receiverId) async {
    if (currentUserId == null) return false;

    try {
      await _supabase.from('friendships').insert({
        'sender_id': currentUserId,
        'receiver_id': receiverId,
        'status': 'pending',
      });

      debugPrint('✅ Friend request sent to $receiverId');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending friend request: $e');
      return false;
    }
  }

  /// Anulează cerere de prietenie trimisă (pending sent)
  Future<bool> cancelFriendRequest(String friendshipId) async {
    try {
      await _supabase
          .from('friendships')
          .delete()
          .eq('id', friendshipId);

      debugPrint('✅ Friend request cancelled');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling request: $e');
      return false;
    }
  }

  /// Acceptă cerere de prietenie primită
  Future<bool> acceptFriendRequest(String friendshipId) async {
    try {
      await _supabase
          .from('friendships')
          .update({'status': 'accepted', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', friendshipId);

      debugPrint('✅ Friend request accepted');
      return true;
    } catch (e) {
      debugPrint('❌ Error accepting request: $e');
      return false;
    }
  }

  /// Refuză cerere de prietenie primită
  Future<bool> declineFriendRequest(String friendshipId) async {
    try {
      await _supabase
          .from('friendships')
          .update({'status': 'declined', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', friendshipId);

      debugPrint('✅ Friend request declined');
      return true;
    } catch (e) {
      debugPrint('❌ Error declining request: $e');
      return false;
    }
  }

  /// Obține cererile de prietenie TRIMISE (pending sent)
  Future<List<FriendshipModel>> getSentFriendRequests() async {
    if (currentUserId == null) return [];

    try {
      final response = await _supabase
          .from('friendships')
          .select('*, profiles!friendships_receiver_id_fkey(full_name, avatar_url)')
          .eq('sender_id', currentUserId!)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final friendships = (response as List).map((json) {
        final friendship = FriendshipModel.fromJson(json);
        
        // Populate info despre receiver
        final profile = json['profiles'] as Map<String, dynamic>?;
        if (profile != null) {
          friendship.otherUserName = profile['full_name'] as String?;
          friendship.otherUserAvatar = profile['avatar_url'] as String?;
          friendship.otherUserId = friendship.receiverId;
        }
        
        return friendship;
      }).toList();

      return friendships;
    } catch (e) {
      debugPrint('❌ Error getting sent requests: $e');
      return [];
    }
  }

  /// Obține cererile de prietenie PRIMITE (pending received)
  Future<List<FriendshipModel>> getReceivedFriendRequests() async {
    if (currentUserId == null) return [];

    try {
      final response = await _supabase
          .from('friendships')
          .select('*, profiles!friendships_sender_id_fkey(full_name, avatar_url)')
          .eq('receiver_id', currentUserId!)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final friendships = (response as List).map((json) {
        final friendship = FriendshipModel.fromJson(json);
        
        // Populate info despre sender
        final profile = json['profiles'] as Map<String, dynamic>?;
        if (profile != null) {
          friendship.otherUserName = profile['full_name'] as String?;
          friendship.otherUserAvatar = profile['avatar_url'] as String?;
          friendship.otherUserId = friendship.senderId;
        }
        
        return friendship;
      }).toList();

      return friendships;
    } catch (e) {
      debugPrint('❌ Error getting received requests: $e');
      return [];
    }
  }

  /// Obține lista de prieteni acceptați cu status online/offline
  Future<List<FriendshipModel>> getFriends() async {
    if (currentUserId == null) return [];

    try {
      // Obține toate prieteniile acceptate CU STATUS ONLINE ✅
      final response = await _supabase
          .from('friendships')
          .select('''
            *,
            sender:profiles!friendships_sender_id_fkey(id, full_name, avatar_url, is_online),
            receiver:profiles!friendships_receiver_id_fkey(id, full_name, avatar_url, is_online)
          ''')
          .eq('status', 'accepted')
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
          .order('updated_at', ascending: false);

      final friendships = <FriendshipModel>[];

      for (final json in response as List) {
        final friendship = FriendshipModel.fromJson(json);
        
        // Determină care profil e "celălalt user"
        final isSender = friendship.senderId == currentUserId;
        final otherProfile = isSender 
            ? json['receiver'] as Map<String, dynamic>?
            : json['sender'] as Map<String, dynamic>?;
        
        if (otherProfile != null) {
          friendship.otherUserId = otherProfile['id'] as String;
          friendship.otherUserName = otherProfile['full_name'] as String?;
          friendship.otherUserAvatar = otherProfile['avatar_url'] as String?;
          friendship.otherUserIsOnline = otherProfile['is_online'] as bool?; // ✅ ADĂUGAT
        }
        
        friendships.add(friendship);
      }

      return friendships;
    } catch (e) {
      debugPrint('❌ Error getting friends: $e');
      return [];
    }
  }

  /// Verifică dacă 2 useri sunt prieteni
  Future<bool> areFriends(String userId1, String userId2) async {
    try {
      final response = await _supabase
          .from('friendships')
          .select('id')
          .eq('status', 'accepted')
          .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking friendship: $e');
      return false;
    }
  }

  /// Șterge prietenie (unfriend)
  Future<bool> removeFriend(String otherUserId) async {
    if (currentUserId == null) return false;

    try {
      await _supabase
          .from('friendships')
          .delete()
          .eq('status', 'accepted')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)');

      debugPrint('✅ Friend removed');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing friend: $e');
      return false;
    }
  }

  /// Blochează un user
  Future<bool> blockUser(String userId) async {
    if (currentUserId == null) return false;

    try {
      // 1. Blochează user-ul
      await _supabase.from('blocked_users').insert({
        'blocker_id': currentUserId,
        'blocked_id': userId,
      });

      // 2. Șterge orice relație de prietenie existentă
      await _supabase
          .from('friendships')
          .delete()
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$userId),and(sender_id.eq.$userId,receiver_id.eq.$currentUserId)');

      debugPrint('✅ User blocked');
      return true;
    } catch (e) {
      debugPrint('❌ Error blocking user: $e');
      return false;
    }
  }

  /// Deblochează un user
  Future<bool> unblockUser(String userId) async {
    if (currentUserId == null) return false;

    try {
      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', currentUserId!)
          .eq('blocked_id', userId);

      debugPrint('✅ User unblocked');
      return true;
    } catch (e) {
      debugPrint('❌ Error unblocking user: $e');
      return false;
    }
  }

  /// Verifică dacă un user e blocat
  Future<bool> isBlocked(String userId) async {
    if (currentUserId == null) return false;

    try {
      final response = await _supabase
          .from('blocked_users')
          .select('id')
          .eq('blocker_id', currentUserId!)
          .eq('blocked_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking block: $e');
      return false;
    }
  }

  /// Obține lista de useri blocați
  Future<List<BlockModel>> getBlockedUsers() async {
    if (currentUserId == null) return [];

    try {
      final response = await _supabase
          .from('blocked_users')
          .select('*, profiles!blocked_users_blocked_id_fkey(full_name, avatar_url)')
          .eq('blocker_id', currentUserId!)
          .order('created_at', ascending: false);

      final blocks = (response as List).map((json) {
        final block = BlockModel.fromJson(json);
        
        // Populate info despre blocked user
        final profile = json['profiles'] as Map<String, dynamic>?;
        if (profile != null) {
          block.blockedUserName = profile['full_name'] as String?;
          block.blockedUserAvatar = profile['avatar_url'] as String?;
        }
        
        return block;
      }).toList();

      return blocks;
    } catch (e) {
      debugPrint('❌ Error getting blocked users: $e');
      return [];
    }
  }
}