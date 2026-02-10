import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Connects to the event WebSocket and streams decoded JSON payloads.
/// Call [connect] with the event WS URL; listen to [messages]. Call [disconnect] when done.
class EventWebSocketService {
  WebSocketChannel? _channel;
  Timer? _keepaliveTimer;
  static const Duration _keepaliveInterval = Duration(seconds: 25);
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  bool get isConnected => _channel != null;

  static String _rawDataToString(dynamic data) {
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data);
    if (data is Uint8List) return utf8.decode(data);
    return data.toString();
  }

  void connect(String wsUrl) {
    if (_channel != null) return;
    print('=== WS Connect === $wsUrl');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channel!.stream.listen(
        (data) {
          final raw = _rawDataToString(data);
          print('=== WS raw received === length=${raw.length} preview=${raw.length > 150 ? "${raw.substring(0, 150)}..." : raw}');
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>?;
            if (map != null && !_controller.isClosed) {
              print('=== WS Received === type=${map['type']} event_id=${map['event_id']} class_key=${map['class_key']}');
              _controller.add(map);
            }
          } catch (e, st) {
            print('=== WS Parse Error === $e');
            print(st);
          }
        },
        onError: (Object e, StackTrace st) {
          print('=== WS stream error === $e');
          if (!_controller.isClosed) _controller.addError(e, st);
        },
        onDone: () {
          print('=== WS stream done (connection closed) ===');
          _stopKeepalive();
          _channel = null;
        },
        cancelOnError: false,
      );
      _startKeepalive();
    } catch (e) {
      print('=== WS connect error === $e');
      if (!_controller.isClosed) _controller.addError(e, StackTrace.current);
    }
  }

  void _startKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = Timer.periodic(_keepaliveInterval, (_) {
      try {
        _channel?.sink.add('{"type":"ping"}');
      } catch (_) {}
    });
  }

  void _stopKeepalive() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
  }

  void disconnect() {
    if (_channel != null) {
      print('=== WS Disconnect ===');
      _stopKeepalive();
      _channel?.sink.close();
      _channel = null;
    }
  }

  void close() {
    disconnect();
    _controller.close();
  }
}
