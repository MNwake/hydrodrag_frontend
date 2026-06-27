import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/app_log.dart';

/// Connects to the event WebSocket and streams decoded JSON payloads.
/// Call [connect] with the event WS URL; listen to [messages]. Call [disconnect] when done.
class EventWebSocketService {
  WebSocketChannel? _channel;
  Timer? _keepaliveTimer;
  Timer? _reconnectTimer;
  static const Duration _keepaliveInterval = Duration(seconds: 25);
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  String? _lastWsUrl;
  bool _shouldReconnect = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
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
    _lastWsUrl = wsUrl;
    _shouldReconnect = true;
    _cancelReconnect();
    _connectInternal(wsUrl);
  }

  void _connectInternal(String wsUrl) {
    if (_isDisposed || _channel != null) return;
    AppLog.debug('WebSocket', 'Connecting to event stream');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _reconnectAttempts = 0;
      _channel!.stream.listen(
        (data) {
          final raw = _rawDataToString(data);
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>?;
            if (map != null && !_controller.isClosed) {
              AppLog.debug('WebSocket', 'Message received: type=${map['type']}');
              _controller.add(map);
            }
          } catch (e, st) {
            AppLog.error(
              'WebSocket',
              'Failed to parse WebSocket message',
              error: e,
              stackTrace: st,
              recoverable: true,
            );
          }
        },
        onError: (Object e, StackTrace st) {
          AppLog.error(
            'WebSocket',
            'WebSocket stream error',
            error: e,
            stackTrace: st,
            recoverable: true,
          );
          if (!_controller.isClosed) _controller.addError(e, st);
          _handleUnexpectedDisconnect();
        },
        onDone: () {
          AppLog.debug('WebSocket', 'Connection closed');
          _handleUnexpectedDisconnect();
        },
        cancelOnError: false,
      );
      _startKeepalive();
    } catch (e, stack) {
      AppLog.error(
        'WebSocket',
        'WebSocket connect failed',
        error: e,
        stackTrace: stack,
        recoverable: true,
      );
      if (!_controller.isClosed) _controller.addError(e, stack);
      _handleUnexpectedDisconnect();
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

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Duration _nextReconnectDelay() {
    final backoffSeconds = 1 << _reconnectAttempts;
    final delay = Duration(seconds: backoffSeconds);
    return delay > _maxReconnectDelay ? _maxReconnectDelay : delay;
  }

  void _handleUnexpectedDisconnect() {
    _stopKeepalive();
    _channel = null;
    if (!_shouldReconnect || _isDisposed) return;
    final wsUrl = _lastWsUrl;
    if (wsUrl == null || wsUrl.isEmpty) return;
    _cancelReconnect();
    final delay = _reconnectAttempts == 0
        ? _initialReconnectDelay
        : _nextReconnectDelay();
    _reconnectAttempts += 1;
    AppLog.warning(
      'WebSocket',
      'Reconnecting (attempt $_reconnectAttempts, ${delay.inSeconds}s delay)',
    );
    _reconnectTimer = Timer(delay, () {
      if (_isDisposed || !_shouldReconnect) return;
      _connectInternal(wsUrl);
    });
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectAttempts = 0;
    _cancelReconnect();
    if (_channel != null) {
      AppLog.debug('WebSocket', 'Disconnecting');
      _stopKeepalive();
      _channel?.sink.close();
      _channel = null;
    }
  }

  void close() {
    _isDisposed = true;
    disconnect();
    if (!_controller.isClosed) _controller.close();
  }
}
