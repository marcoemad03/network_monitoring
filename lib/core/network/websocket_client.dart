import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import '../config/build_config.dart';
import '../utils/logger.dart';
import '../security/jwt_manager.dart';

enum WebSocketState { disconnected, connecting, connected, reconnecting }

class WebSocketClient {
  final JwtManager _jwtManager;
  WebSocketChannel? _channel;
  WebSocketState _state = WebSocketState.disconnected;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  String? _currentPath;
  int _reconnectAttempts = 0;
  int _maxReconnectAttempts = 10;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _stateController = StreamController<WebSocketState>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<WebSocketState> get stateStream => _stateController.stream;
  WebSocketState get state => _state;

  WebSocketClient(this._jwtManager);

  Future<void> connect(String path) async {
    if (_state == WebSocketState.connecting ||
        _state == WebSocketState.connected) {
      return;
    }

    _currentPath = path;
    _setState(WebSocketState.connecting);

    try {
      final token = await _jwtManager.getAccessToken();
      final uri = Uri.parse('${BuildConfig.wsBaseUrl}$path');
      final wsHeaders = <String, dynamic>{
        'Authorization': 'Bearer $token',
      };

      _channel = IOWebSocketChannel.connect(uri, headers: wsHeaders);
      await _channel!.ready;

      _setState(WebSocketState.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();

      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _messageController.add(message);
          } catch (e) {
            AppLogger.error('WebSocket message parse error', error: e);
          }
        },
        onError: (error) {
          AppLogger.error('WebSocket error', error: error);
          _handleDisconnect();
        },
        onDone: () {
          AppLogger.debug('WebSocket connection closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      AppLogger.error('WebSocket connection failed', error: e);
      _handleDisconnect();
    }
  }

  void send(Map<String, dynamic> data) {
    if (_state == WebSocketState.connected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void _handleDisconnect() {
    _stopHeartbeat();
    _setState(WebSocketState.disconnected);
    _attemptReconnect();
  }

  void _attemptReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _setState(WebSocketState.reconnecting);
    _reconnectAttempts++;
    _reconnectTimer = Timer.periodic(
      Duration(seconds: _getBackoffSeconds()),
      (_) {
        if (_currentPath != null) {
          connect(_currentPath!);
        }
      },
    );
  }

  int _getBackoffSeconds() {
    const base = 2;
    final exp = _reconnectAttempts.clamp(1, 6);
    return base * exp;
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => send({'type': 'ping'}),
    );
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _setState(WebSocketState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();
    _currentPath = null;
    _reconnectAttempts = 0;
    await _channel?.sink.close();
    _channel = null;
    _setState(WebSocketState.disconnected);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _stateController.close();
  }
}
