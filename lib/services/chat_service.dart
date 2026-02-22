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
            sender:profiles!messages_sender_id_fkey(id, full_name, avatar_url)
          ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      // Convertim răspunsul în lista de obiecte Message
      final messages = (response as List).map((json) {
        final message = Message.fromJson(json);
        final sender = json['sender'];
        
        return message.copyWith(
          senderName: sender['full_name'] as String?,
          senderAvatar: sender['avatar_url'] as String?,
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
  Future<Message> sendMessage(String conversationId, String content) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // 1. Inserăm mesajul nou în tabela messages
      final messageResponse = await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': currentUserId,
            'content': content,
          })
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