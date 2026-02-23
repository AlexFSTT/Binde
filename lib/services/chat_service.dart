import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversation_model.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import 'package:mime/mime.dart';

/// Service pentru gestionarea conversațiilor și mesajelor
/// Acest service se ocupă de:
/// - Găsirea sau crearea conversațiilor între utilizatori
/// - Trimiterea și primirea mesajelor
/// - Actualizări în timp real folosind Supabase Realtime
class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obține toate conversațiile utilizatorului curent
  /// Returnează o listă de conversații sortate după ultimul mesaj
  Future<List<Conversation>> getConversations() async {
    try {
      // Obținem ID-ul utilizatorului curent
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Interogăm Supabase pentru toate conversațiile în care participă utilizatorul
      // Folosim OR pentru a căuta fie în participant_1, fie în participant_2
      final response = await _supabase
          .from('conversations')
          .select('''
            *,
            participant1:profiles!conversations_participant_1_fkey(id, full_name, avatar_url),
            participant2:profiles!conversations_participant_2_fkey(id, full_name, avatar_url)
          ''')
          .or('participant_1.eq.$currentUserId,participant_2.eq.$currentUserId')
          .order('last_message_at', ascending: false);

      // Convertim răspunsul în lista de obiecte Conversation
      final conversations = (response as List).map((json) {
        final conversation = Conversation.fromJson(json);
        
        // Determinăm cine este celălalt participant
        final isParticipant1 = conversation.participant1 == currentUserId;
        final otherParticipant = isParticipant1 ? json['participant2'] : json['participant1'];
        
        // Adăugăm informațiile despre celălalt participant
        return conversation.copyWith(
          otherUserName: otherParticipant['full_name'] as String?,
          otherUserAvatar: otherParticipant['avatar_url'] as String?,
        );
      }).toList();

      return conversations;
    } catch (e) {
      debugPrint('Error getting conversations: $e');
      rethrow;
    }
  }

  /// Găsește sau creează o conversație între utilizatorul curent și un alt utilizator
  /// Dacă există deja o conversație, o returnează
  /// Dacă nu există, creează una nouă
  Future<Conversation> getOrCreateConversation(String otherUserId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Căutăm dacă există deja o conversație între cei doi utilizatori
      // Trebuie să verificăm ambele combinații: (user1, user2) și (user2, user1)
      final existingConversation = await _supabase
          .from('conversations')
          .select('''
            *,
            participant1:profiles!conversations_participant_1_fkey(id, full_name, avatar_url),
            participant2:profiles!conversations_participant_2_fkey(id, full_name, avatar_url)
          ''')
          .or('and(participant_1.eq.$currentUserId,participant_2.eq.$otherUserId),and(participant_1.eq.$otherUserId,participant_2.eq.$currentUserId)')
          .maybeSingle();

      // Dacă există conversația, o returnăm
      if (existingConversation != null) {
        final conversation = Conversation.fromJson(existingConversation);
        final isParticipant1 = conversation.participant1 == currentUserId;
        final otherParticipant = isParticipant1 
            ? existingConversation['participant2'] 
            : existingConversation['participant1'];
        
        return conversation.copyWith(
          otherUserName: otherParticipant['full_name'] as String?,
          otherUserAvatar: otherParticipant['avatar_url'] as String?,
        );
      }

      // Dacă nu există, creăm o conversație nouă
      final newConversation = await _supabase
          .from('conversations')
          .insert({
            'participant_1': currentUserId,
            'participant_2': otherUserId,
          })
          .select('''
            *,
            participant1:profiles!conversations_participant_1_fkey(id, full_name, avatar_url),
            participant2:profiles!conversations_participant_2_fkey(id, full_name, avatar_url)
          ''')
          .single();

      final conversation = Conversation.fromJson(newConversation);
      final otherParticipant = newConversation['participant2'];
      
      return conversation.copyWith(
        otherUserName: otherParticipant['full_name'] as String?,
        otherUserAvatar: otherParticipant['avatar_url'] as String?,
      );
    } catch (e) {
      debugPrint('Error getting or creating conversation: $e');
      rethrow;
    }
  }

  /// Obține toate mesajele dintr-o conversație
  /// Returnează mesajele sortate cronologic (cele mai vechi primele)
  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('''
            *,
            sender:profiles!messages_sender_id_fkey(id, full_name, avatar_url),
            reply_story:stories!messages_reply_to_story_id_fkey(id, media_url, media_type)
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final messages = (response as List).map((json) {
        final message = Message.fromJson(json);
        final sender = json['sender'];
        final replyStory = json['reply_story'] as Map<String, dynamic>?;

        return message.copyWith(
          senderName: sender['full_name'] as String?,
          senderAvatar: sender['avatar_url'] as String?,
          replyStoryMediaUrl: replyStory?['media_url'] as String?,
          replyStoryMediaType: replyStory?['media_type'] as String?,
        );
      }).toList();

      return messages;
    } catch (e) {
      debugPrint('Error getting messages: $e');
      rethrow;
    }
  }

  /// Trimite un mesaj nou într-o conversație
  /// Actualizează și conversația cu ultimul mesaj și timestamp
  Future<Message> sendMessage(String conversationId, String content, {String? replyToStoryId}) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final insertData = {
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'content': content,
        'reply_to_story_id': ?replyToStoryId,
      };

      // 1. Inserăm mesajul nou în tabela messages
      final messageResponse = await _supabase
          .from('messages')
          .insert(insertData)
          .select('''
            *,
            sender:profiles!messages_sender_id_fkey(id, full_name, avatar_url)
          ''')
          .single();

      // 2. Actualizăm conversația cu ultimul mesaj
      await _supabase
          .from('conversations')
          .update({
            'last_message': content,
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);

      // 3. Returnăm mesajul creat
      final message = Message.fromJson(messageResponse);
      final sender = messageResponse['sender'];
      
      return message.copyWith(
        senderName: sender['full_name'] as String?,
        senderAvatar: sender['avatar_url'] as String?,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Trimite un mesaj cu atașament (imagine, video, fișier)
  Future<Message> sendMediaMessage({
    required String conversationId,
    required File file,
    required MessageType messageType,
    String? caption,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // 1. Upload file to storage
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storagePath = '$currentUserId/$conversationId/$fileName';
      final fileSize = await file.length();
      final originalName = file.path.split('/').last;

      // Detect MIME type for proper Content-Type header
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      await _supabase.storage
          .from('chat-attachments')
          .upload(
            storagePath,
            file,
            fileOptions: FileOptions(contentType: mimeType),
          );

      final attachmentUrl = _supabase.storage
          .from('chat-attachments')
          .getPublicUrl(storagePath);

      // 2. Build content preview
      String content;
      if (caption != null && caption.trim().isNotEmpty) {
        content = caption.trim();
      } else {
        switch (messageType) {
          case MessageType.image: content = '📷 Photo'; break;
          case MessageType.video: content = '🎥 Video'; break;
          case MessageType.file: content = '📎 $originalName'; break;
          default: content = '📎 Attachment';
        }
      }

      // 3. Insert message
      final messageResponse = await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': currentUserId,
            'content': content,
            'message_type': messageType.value,
            'attachment_url': attachmentUrl,
            'file_name': originalName,
            'file_size': fileSize,
          })
          .select('''
            *,
            sender:profiles!messages_sender_id_fkey(id, full_name, avatar_url)
          ''')
          .single();

      // 4. Update conversation
      await _supabase
          .from('conversations')
          .update({
            'last_message': content,
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .eq('id', conversationId);

      final message = Message.fromJson(messageResponse);
      final sender = messageResponse['sender'];

      return message.copyWith(
        senderName: sender['full_name'] as String?,
        senderAvatar: sender['avatar_url'] as String?,
      );
    } catch (e) {
      debugPrint('❌ Error sending media message: $e');
      rethrow;
    }
  }

  /// Marchează toate mesajele necitite dintr-o conversație ca fiind citite
  /// Acest lucru se întâmplă când utilizatorul deschide conversația
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Actualizăm toate mesajele din conversație care nu sunt citite
      // și care nu au fost trimise de utilizatorul curent
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .eq('is_read', false)
          .neq('sender_id', currentUserId);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Subscribe la mesajele noi dintr-o conversație folosind Realtime
  /// Returnează un Stream care emite mesaje noi când sunt primite
  /// 
  /// IMPORTANT: Supabase Realtime trebuie activat pentru tabela 'messages' în Dashboard
  Stream<List<Message>> subscribeToMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((data) {
          // Convertim fiecare mesaj din stream
          return data.map((json) => Message.fromJson(json)).toList();
        });
  }

  /// Obține numărul de mesaje necitite pentru utilizatorul curent
  // =============================================================
  // DELETE MESSAGES
  // =============================================================

  /// Delete message for me only (soft delete via message_deletions)
  Future<void> deleteMessageForMe(String messageId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    // Get conversation_id before deleting
    final msg = await _supabase
        .from('messages')
        .select('conversation_id')
        .eq('id', messageId)
        .single();

    await _supabase.from('message_deletions').upsert({
      'message_id': messageId,
      'user_id': currentUserId,
    });

    await _refreshConversationLastMessage(msg['conversation_id'] as String);
  }

  /// Delete message for everyone (sender only)
  Future<bool> deleteMessageForEveryone(String messageId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;

      // Verify sender owns the message + get conversation_id
      final msg = await _supabase
          .from('messages')
          .select('sender_id, conversation_id')
          .eq('id', messageId)
          .single();

      if (msg['sender_id'] != currentUserId) return false;

      await _supabase
          .from('messages')
          .update({'deleted_for_everyone': true})
          .eq('id', messageId);

      await _refreshConversationLastMessage(msg['conversation_id'] as String);

      return true;
    } catch (e) {
      debugPrint('Error deleting for everyone: $e');
      return false;
    }
  }

  /// Update conversation last_message to the latest non-deleted message
  Future<void> _refreshConversationLastMessage(String conversationId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      // Find the latest message that isn't deleted for everyone
      final latest = await _supabase
          .from('messages')
          .select('content, created_at, id, message_type')
          .eq('conversation_id', conversationId)
          .eq('deleted_for_everyone', false)
          .order('created_at', ascending: false)
          .limit(10);

      if ((latest as List).isEmpty) {
        // No messages left
        await _supabase
            .from('conversations')
            .update({'last_message': '', 'last_message_at': DateTime.now().toIso8601String()})
            .eq('id', conversationId);
        return;
      }

      // Filter out messages deleted for current user
      String? lastContent;
      String? lastAt;
      if (currentUserId != null) {
        final deletedIds = await getDeletedMessageIds(conversationId);
        for (final msg in latest) {
          if (!deletedIds.contains(msg['id'] as String)) {
            lastContent = msg['content'] as String?;
            lastAt = msg['created_at'] as String?;
            break;
          }
        }
      }

      lastContent ??= '';
      lastAt ??= (latest as List).first['created_at'] as String;

      await _supabase
          .from('conversations')
          .update({
            'last_message': lastContent,
            'last_message_at': lastAt,
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Error refreshing conversation last message: $e');
    }
  }

  /// Delete entire conversation and all its messages
  Future<bool> deleteConversation(String conversationId) async {
    try {
      // Delete all messages first (cascading will clean reactions + deletions)
      await _supabase
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId);

      // Delete the conversation
      await _supabase
          .from('conversations')
          .delete()
          .eq('id', conversationId);

      return true;
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      return false;
    }
  }

  // =============================================================
  // REACTIONS
  // =============================================================

  /// Toggle reaction on a message (same type = remove, different = update)
  Future<String?> toggleMessageReaction(String messageId, String reactionType) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return null;

      // Check existing reaction
      final existing = await _supabase
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', currentUserId)
          .maybeSingle();

      if (existing != null) {
        if (existing['reaction_type'] == reactionType) {
          // Same reaction → remove
          await _supabase
              .from('message_reactions')
              .delete()
              .eq('message_id', messageId)
              .eq('user_id', currentUserId);
          return null;
        } else {
          // Different → update
          await _supabase
              .from('message_reactions')
              .update({'reaction_type': reactionType})
              .eq('message_id', messageId)
              .eq('user_id', currentUserId);
          return reactionType;
        }
      } else {
        // No reaction → insert
        await _supabase.from('message_reactions').insert({
          'message_id': messageId,
          'user_id': currentUserId,
          'reaction_type': reactionType,
        });
        return reactionType;
      }
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
      return null;
    }
  }

  /// Load reactions for a list of messages and enrich them
  Future<List<Message>> enrichMessagesWithReactions(List<Message> messages) async {
    if (messages.isEmpty) return messages;
    final currentUserId = _supabase.auth.currentUser?.id;

    final messageIds = messages.map((m) => m.id).toList();

    try {
      final reactions = await _supabase
          .from('message_reactions')
          .select()
          .inFilter('message_id', messageIds);

      // Build reaction maps per message
      final Map<String, Map<String, int>> countsMap = {};
      final Map<String, String?> myReactionMap = {};

      for (final r in reactions) {
        final msgId = r['message_id'] as String;
        final type = r['reaction_type'] as String;
        final userId = r['user_id'] as String;

        countsMap.putIfAbsent(msgId, () => {});
        countsMap[msgId]![type] = (countsMap[msgId]![type] ?? 0) + 1;

        if (userId == currentUserId) {
          myReactionMap[msgId] = type;
        }
      }

      return messages.map((m) {
        final counts = countsMap[m.id] ?? {};
        final total = counts.values.fold(0, (a, b) => a + b);
        return m.copyWith(
          reactionCounts: counts,
          totalReactions: total,
          myReaction: myReactionMap[m.id],
          clearMyReaction: !myReactionMap.containsKey(m.id),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading reactions: $e');
      return messages;
    }
  }

  /// Get IDs of messages deleted for current user
  Future<Set<String>> getDeletedMessageIds(String conversationId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return {};

    try {
      // Get messages in this conversation that user has soft-deleted
      final response = await _supabase
          .from('message_deletions')
          .select('message_id, messages!inner(conversation_id)')
          .eq('user_id', currentUserId)
          .eq('messages.conversation_id', conversationId);

      return (response as List)
          .map((r) => r['message_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('Error getting deleted IDs: $e');
      return {};
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return 0;

      // Folosim count() pentru a număra mesajele necitite
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('is_read', false)
          .neq('sender_id', currentUserId)
          .count();

      return response.count;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }
}