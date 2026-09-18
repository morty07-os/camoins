import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();

  late IO.Socket socket;
  bool _isConnected = false;

  factory ChatService() {
    return _instance;
  }

  ChatService._internal();

  Future<void> initialize(String token) async {
    // Get backend URL from preferences or use default
    final prefs = await SharedPreferences.getInstance();
    final backendUrl = prefs.getString('backend_url') ?? 'http://localhost:5000';

    socket = IO.io(
      backendUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    socket.onConnect((_) {
      _isConnected = true;
    });

    socket.onDisconnect((_) {
      _isConnected = false;
    });

    socket.onError((error) {
      // Error handling
    });

    socket.connect();
  }

  bool get isConnected => _isConnected;

  void joinConversation(int conversationId) {
    if (_isConnected) {
      socket.emit('join-conversation', conversationId);
    }
  }

  void leaveConversation(int conversationId) {
    if (_isConnected) {
      socket.emit('leave-conversation', conversationId);
    }
  }

  void sendMessage(int conversationId, String message) {
    if (_isConnected) {
      socket.emit('send-message', {
        'conversationId': conversationId,
        'message': message,
      });
    }
  }

  void onMessageReceived(Function(dynamic) callback) {
    socket.on('message-received', callback);
  }

  void onError(Function(dynamic) callback) {
    socket.on('error', callback);
  }

  void dispose() {
    if (_isConnected) {
      socket.disconnect();
    }
  }
}
