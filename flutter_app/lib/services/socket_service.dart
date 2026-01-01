import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';

class SocketService {
  static const String baseUrl = ApiConfig.socketUrl;
  IO.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String token) async {
    if (_socket?.connected == true) {
      return;
    }

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('✅ Socket.io connecté');
    });

    _socket!.onDisconnect((_) {
      print('❌ Socket.io déconnecté');
    });

    _socket!.onError((error) {
      print('❌ Erreur Socket.io: $error');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // Rejoindre une room de balade
  void joinRideRoom(String rideId) {
    _socket?.emit('join-ride-room', rideId);
  }

  // Quitter une room de balade
  void leaveRideRoom(String rideId) {
    _socket?.emit('leave-ride-room', rideId);
  }

  // Rejoindre une room de groupe
  void joinGroupRoom(String groupId) {
    _socket?.emit('join-group-room', groupId);
  }

  // Quitter une room de groupe
  void leaveGroupRoom(String groupId) {
    _socket?.emit('leave-group-room', groupId);
  }

  // Envoyer un message dans une balade
  void sendRideMessage(String rideId, String contenu) {
    _socket?.emit('send-ride-message', {
      'rideId': rideId,
      'contenu': contenu,
    });
  }

  // Envoyer un message dans un groupe
  void sendGroupMessage(String groupId, String contenu) {
    _socket?.emit('send-group-message', {
      'groupId': groupId,
      'contenu': contenu,
    });
  }

  // Écouter les nouveaux messages
  void onNewMessage(Function(Map<String, dynamic>) callback) {
    _socket?.on('new-message', (data) {
      callback(data);
    });
  }

  // Écouter les messages précédents
  void onPreviousMessages(Function(Map<String, dynamic>) callback) {
    _socket?.on('previous-messages', (data) {
      callback(data);
    });
  }

  // Écouter les erreurs
  void onError(Function(Map<String, dynamic>) callback) {
    _socket?.on('error', (data) {
      callback(data);
    });
  }

  // Écouter la confirmation d'envoi
  void onMessageSent(Function(Map<String, dynamic>) callback) {
    _socket?.on('message-sent', (data) {
      callback(data);
    });
  }

  // Retirer les listeners
  void off(String event) {
    _socket?.off(event);
  }

  // Modifier un message
  void editMessage(String messageId, String content) {
    _socket?.emit('edit-message', {
      'messageId': messageId,
      'content': content,
    });
  }

  // Supprimer un message
  void deleteMessage(String messageId, {String scope = 'me'}) {
    _socket?.emit('delete-message', {
      'messageId': messageId,
      'scope': scope,
    });
  }

  // Restaurer un message supprimé "pour moi"
  void restoreMessage(String messageId) {
    _socket?.emit('restore-message', {
      'messageId': messageId,
    });
  }

  // Toggle réaction
  void toggleReaction(String messageId, String emoji) {
    print('🔵 SocketService.toggleReaction - messageId: $messageId, emoji: $emoji');
    print('🔵 Socket null: ${_socket == null}');
    print('🔵 Socket connected: ${_socket?.connected}');
    
    if (_socket == null) {
      print('❌ Socket est null');
      throw Exception('Socket non initialisé');
    }
    
    if (!_socket!.connected) {
      print('❌ Socket non connecté');
      throw Exception('Socket non connecté');
    }
    
    try {
      print('🔵 Émission de l\'événement toggle-reaction...');
      _socket!.emit('toggle-reaction', {
        'messageId': messageId,
        'emoji': emoji,
      });
      print('✅ Événement toggle-reaction émis avec succès');
    } catch (e) {
      print('❌ Erreur lors de l\'émission: $e');
      throw Exception('Erreur lors de l\'envoi de la réaction: $e');
    }
  }

  // Typing indicator
  void startTyping(String conversationId, String type) {
    _socket?.emit('typing-start', {
      'conversationId': conversationId,
      'type': type,
    });
  }

  void stopTyping(String conversationId, String type) {
    _socket?.emit('typing-stop', {
      'conversationId': conversationId,
      'type': type,
    });
  }

  // Écouter les mises à jour de messages
  void onMessageUpdated(Function(Map<String, dynamic>) callback) {
    _socket?.on('message-updated', (data) {
      callback(data);
    });
  }

  // Écouter les suppressions de messages
  void onMessageDeleted(Function(Map<String, dynamic>) callback) {
    _socket?.on('message-deleted', (data) {
      callback(data);
    });
  }

  // Écouter les restaurations de messages
  void onMessageRestored(Function(Map<String, dynamic>) callback) {
    _socket?.on('message-restored', (data) {
      callback(data);
    });
  }

  void onMessagePinned(Function(Map<String, dynamic>) callback) {
    _socket?.on('message-pinned', (data) {
      callback(data);
    });
  }

  // Écouter les mises à jour de sondages
  void onPollUpdated(Function(Map<String, dynamic>) callback) {
    _socket?.on('poll-updated', (data) {
      callback(data);
    });
  }

  // Écouter les mises à jour de réactions
  void onReactionUpdated(Function(Map<String, dynamic>) callback) {
    _socket?.on('reaction-updated', (data) {
      callback(data);
    });
  }

  // Écouter le typing indicator
  void onTyping(Function(Map<String, dynamic>) callback) {
    _socket?.on('typing', (data) {
      callback(data);
    });
  }

  // Envoyer un message avec reply
  void sendGroupMessageWithReply(String groupId, String contenu, {String? replyToMessageId}) {
    _socket?.emit('send-group-message', {
      'groupId': groupId,
      'contenu': contenu,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    });
  }

  void sendRideMessageWithReply(String rideId, String contenu, {String? replyToMessageId}) {
    _socket?.emit('send-ride-message', {
      'rideId': rideId,
      'contenu': contenu,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    });
  }
}

