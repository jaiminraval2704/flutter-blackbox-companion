import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService extends ChangeNotifier {
  static final WebSocketService _instance = WebSocketService._();
  static WebSocketService get instance => _instance;

  WebSocketService._();

  WebSocketChannel? _channel;
  bool _isConnected = false;

  final List<Map<String, dynamic>> logs = [];
  final List<Map<String, dynamic>> networkRequests = [];

  bool get isConnected => _isConnected;

  void connect(String ipAddress) {
    try {
      final uri = Uri.parse('ws://$ipAddress:8080/ws');
      _channel = WebSocketChannel.connect(uri);

      _isConnected = true;
      notifyListeners();

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            final type = data['type'];
            final payload = data['data'];

            if (type == 'log') {
              logs.insert(0, payload);
            } else if (type == 'network') {
              networkRequests.insert(0, payload);
            }
            notifyListeners();
          } catch (e) {
            debugPrint('Error parsing message: $e');
          }
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
        },
        onError: (error) {
          _isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _isConnected = false;
      notifyListeners();
      debugPrint('Connection failed: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }
}
