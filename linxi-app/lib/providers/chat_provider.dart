import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/models/chat_model.dart';
import '../core/models/user_model.dart';

class ChatProvider extends ChangeNotifier {
  IO.Socket? _socket;
  final ApiService _api = ApiService();

  List<Conversation> _conversations = [];
  bool _isLoadingConversations = false;

  // Current active chat
  String? _currentConversationId;
  List<Message> _messages = [];
  bool _isLoadingMessages = false;

  List<Conversation> get conversations => _conversations;
  bool get isLoadingConversations => _isLoadingConversations;
  List<Message> get messages => _messages;
  bool get isLoadingMessages => _isLoadingMessages;

  // Initialize Socket
  Future<void> initSocket() async {
    if (_socket != null && _socket!.connected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);

    if (token == null) return;

    // Adjust URL to match your server (e.g. remove /v1 if socket is on root)
    // Assuming socket.io is at root level, not /v1
    final baseUrl = AppConstants.baseUrl.replaceAll('/v1', '');

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({'Authorization': 'Bearer $token'})
        .enableAutoConnect()
        .build());

    _socket!.onConnect((_) {
      debugPrint('Socket Connected');
    });

    _socket!.onDisconnect((_) => debugPrint('Socket Disconnected'));

    _socket!.on('receive_message', (data) {
      _handleReceiveMessage(data);
    });
    
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void _handleReceiveMessage(dynamic data) {
    debugPrint('Received Message: $data');
    // If we are in the chat screen for this conversation, append message
    // Data structure depends on backend event payload
    // Assuming data is the Message object
    final message = Message.fromJson(data);
    
    // Update conversation list (move to top, update last message)
    // We need to know conversationId from message or payload
    // If backend sends conversationId in message payload:
    final conversationId = data['conversationId']?.toString();
    
    if (conversationId == _currentConversationId) {
      _messages.insert(0, message); // Add to bottom (reversed list)
      notifyListeners();
    }
    
    // Refresh conversation list to show new message/unread count
    fetchConversations();
  }

  Future<void> fetchConversations() async {
    _isLoadingConversations = true;
    notifyListeners();

    try {
      final response = await _api.get('/chat/conversations');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Need current user ID to parse conversation correctly
        final prefs = await SharedPreferences.getInstance();
        // We might need to store user ID in prefs or decode token
        // For now, let's assume we can get it from a user profile call or stored
        // Or backend returns a structure where we don't need ID logic in fromJson
        // Let's assume we fetch profile or store ID. 
        // Quick fix: fetch profile if not stored, or rely on provider.
        // For simplicity, let's fetch profile lightly or check if we stored it.
        // Actually, let's just fetch it from UserProvider if possible, but we are inside ChatProvider.
        // Let's assume user_info is stored as JSON string in prefs as per login logic (if we implemented it).
        // If not, we might need to fetch /users/me first.
        
        // Simpler approach: ApiService response for conversation list should ideally pre-calculate "otherUser".
        // If not, we need ID. Let's try to get ID from /users/me if needed, or assume data[0]['user1']['id'] logic works if we know who we are.
        
        // Let's fetch /users/me quickly to get ID for robust parsing
        final meRes = await _api.get('/users/me');
        final myId = meRes.data['id'].toString();

        _conversations = data.map((e) => Conversation.fromJson(e, myId)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> enterChat(String conversationId, User otherUser) async {
    _currentConversationId = conversationId;
    _messages = [];
    _isLoadingMessages = true;
    notifyListeners();

    // Fetch history
    try {
      // Assuming backend has an endpoint for messages
      // GET /chat/conversations/:id/messages
      final response = await _api.get('/chat/conversations/$conversationId/messages');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _messages = data.map((e) => Message.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }
  
  void leaveChat() {
    _currentConversationId = null;
    _messages = [];
  }

  Future<bool> sendMessage(String conversationId, String content, String receiverId) async {
    if (_socket == null) return false;

    // Optimistic update?
    // Better wait for ack or server echo to ensure consistency, 
    // but for UX we can show "sending".
    
    // Emit event
    _socket!.emit('send_message', {
      'receiverId': int.parse(receiverId),
      'content': content,
      'type': 'TEXT',
    });
    
    // We rely on 'receive_message' or specific 'message_sent' ack to update UI
    // If backend echoes the message back to sender via 'receive_message', we are good.
    // If not, we should manually add it here.
    // Let's assume backend echoes for now or we add it optimistically.
    
    // Optimistic add
    final tempMsg = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me', // placeholder, will be replaced or ignored if we re-fetch
      content: content,
      createdAt: DateTime.now(),
      isRead: false,
    );
    // _messages.insert(0, tempMsg); // Let's wait for socket event for cleaner logic to avoid duplicates
    
    return true;
  }
}
