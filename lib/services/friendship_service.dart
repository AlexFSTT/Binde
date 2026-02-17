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
      final searchResults = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .neq('id', currentUserId!)
          .or('full_name.ilike.%$query%,username.ilike.%$query%')
          .limit(20);

      if (searchResults.isEmpty) return [];

      final friendships = await _supabase
          .from('friendships')
          .select('sender_id, receiver_id, status')
          .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId');

      final blocks = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', currentUserId!);

      final blockedIds = blocks.map((b) => b['blocked_id'] as String).toSet();

      final existingRelations = <String>{};
      for (final friendship in friendships) {
        final senderId = friendship['sender_id'] as String;
        final receiverId = friendship['receiver_id'] as String;
        final status = friendship['status'] as String;

        if (status == 'accepted' || status == 'pending') {
          final otherId = senderId == currentUserId ? receiverId : senderId;
          existingRelations.add(otherId);
        }
      }

      final availableUsers = (searchResults as List)
          .where((user) {
            final userId = user['id'] as String;
            return !existingRelations.contains(userId) &&
                !blockedIds.contains(userId);
          })
          .toList();

      return availableUsers.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      return [];
    }
  }

/// Trimite cerere de prietenie + declanșează push prin Edge Function
Future<bool> sendFriendRequest(String receiverId) async {
  final senderId = currentUserId;
  if (senderId == null) return false;

  try {
    // 1) Insert și ia friendshipId
    final inserted = await _supabase
        .from('friendships')
        // ✅ MODIFICAT: insert -> upsert ca să permită re-send după decline
        // ✅ MODIFICAT: onConflict pe sender_id,receiver_id (necesită UNIQUE în DB)
        .upsert({
          'sender_id': senderId,
          'receiver_id': receiverId,
          'status': 'pending',
          // ✅ MODIFICAT: updated_at ca să forțeze realtime update (pending list instant)
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'sender_id,receiver_id')
        // ✅ MODIFICAT: select tot id-ul după upsert (id rămâne la fel dacă exista deja)
        .select('id')
        .single();

    final friendshipId = inserted['id'] as String;

    debugPrint(
        '✅ Friend request sent to $receiverId (friendshipId=$friendshipId)');

    // 2) Push = OPTIONAL (nu trebuie să strice request-ul)
    try {
      // Refresh token (evită Invalid JWT când session e veche)
      await _supabase.auth.refreshSession();

      final session = _supabase.auth.currentSession;
      final accessToken = session?.accessToken;

      if (accessToken == null) {
        debugPrint('⚠️ No Supabase accessToken, push skipped');
      } else {
        final res = await _supabase.functions.invoke(
          'smart-action',
          body: {'friendshipId': friendshipId},
          headers: {
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (res.status != 200) {
          debugPrint('⚠️ Push failed: ${res.status} ${res.data}');
        } else {
          debugPrint('✅ Push sent for friendshipId=$friendshipId');
        }
      }
    } catch (e) {
      // IMPORTANT: nu return false aici
      debugPrint('⚠️ Push skipped (JWT/Function error): $e');
    }

    return true;
  } catch (e) {
    debugPrint('❌ Error sending friend request: $e');
    return false;
  }
}

  /// Anulează cerere de prietenie trimisă (pending sent)
  Future<bool> cancelFriendRequest(String friendshipId) async {
    try {
      await _supabase.from('friendships').delete().eq('id', friendshipId);
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
          .update({
            'status': 'accepted',
            'updated_at': DateTime.now().toIso8601String()
          })
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
          .update({
            'status': 'declined',
            'updated_at': DateTime.now().toIso8601String()
          })
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
          .select(
              '*, profiles!friendships_receiver_id_fkey(full_name, avatar_url)')
          .eq('sender_id', currentUserId!)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final friendships = (response as List).map((json) {
        final friendship = FriendshipModel.fromJson(json);

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
          .select(
              '*, profiles!friendships_sender_id_fkey(full_name, avatar_url)')
          .eq('receiver_id', currentUserId!)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final friendships = (response as List).map((json) {
        final friendship = FriendshipModel.fromJson(json);

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

        final isSender = friendship.senderId == currentUserId;
        final otherProfile = isSender
            ? json['receiver'] as Map<String, dynamic>?
            : json['sender'] as Map<String, dynamic>?;

        if (otherProfile != null) {
          friendship.otherUserId = otherProfile['id'] as String;
          friendship.otherUserName = otherProfile['full_name'] as String?;
          friendship.otherUserAvatar = otherProfile['avatar_url'] as String?;
          friendship.otherUserIsOnline = otherProfile['is_online'] as bool?;
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
          .or(
              'and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
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
          .or(
              'and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)');

      debugPrint('✅ Friend removed');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing friend: $e');
      return false;
    }
  }

  /// Blochează un user
  /// ✅ Șterge prietenia + adaugă în blocked_users
  Future<bool> blockUser(String userId) async {
    if (currentUserId == null) return false;

    try {
      await _supabase.from('blocked_users').insert({
        'blocker_id': currentUserId,
        'blocked_id': userId,
      });

      await _supabase.from('friendships').delete().or(
          'and(sender_id.eq.$currentUserId,receiver_id.eq.$userId),and(sender_id.eq.$userId,receiver_id.eq.$currentUserId)');

      debugPrint('✅ User blocked');
      return true;
    } catch (e) {
      debugPrint('❌ Error blocking user: $e');
      return false;
    }
  }

  /// Deblochează un user
  /// ✅ MODIFICAT: Restaurează automat prietenia (status: accepted)
  Future<bool> unblockUser(String userId) async {
    if (currentUserId == null) return false;

    try {
      // 1) Scoate din blocked_users
      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', currentUserId!)
          .eq('blocked_id', userId);

      // 2) Restaurează prietenia
      await _supabase.from('friendships').insert({
        'sender_id': currentUserId,
        'receiver_id': userId,
        'status': 'accepted',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ User unblocked + friendship restored');
      return true;
    } catch (e) {
      debugPrint('❌ Error unblocking user: $e');
      return false;
    }
  }

  /// ✅ NOU: Verifică relația cu un alt user
  /// Returnează: 'friend', 'blocked', 'blocked_by' (blocat de celălalt), sau 'none'
  Future<String> getRelationshipStatus(String otherUserId) async {
    if (currentUserId == null) return 'none';

    try {
      // Verifică dacă EU am blocat pe celălalt
      final blockedByMe = await _supabase
          .from('blocked_users')
          .select('id')
          .eq('blocker_id', currentUserId!)
          .eq('blocked_id', otherUserId)
          .maybeSingle();

      if (blockedByMe != null) return 'blocked';

      // Verifică dacă CELĂLALT m-a blocat pe mine
      final blockedByOther = await _supabase
          .from('blocked_users')
          .select('id')
          .eq('blocker_id', otherUserId)
          .eq('blocked_id', currentUserId!)
          .maybeSingle();

      if (blockedByOther != null) return 'blocked_by';

      // Verifică prietenia
      final friendship = await _supabase
          .from('friendships')
          .select('id, status')
          .eq('status', 'accepted')
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$currentUserId)')
          .maybeSingle();

      if (friendship != null) return 'friend';

      return 'none';
    } catch (e) {
      debugPrint('❌ Error checking relationship: $e');
      return 'none';
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