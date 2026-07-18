import 'dart:async';
import 'websocket_client.dart';
import '../utils/logger.dart';

final class WebSocketManager {
  final WebSocketClient _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _started = false;

  final _messagesController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<WebSocketState>.broadcast();

  WebSocketState _connectionState = WebSocketState.disconnected;
  WebSocketState get connectionStateValue => _connectionState;
  Stream<Map<String, dynamic>> get messages => _messagesController.stream;
  Stream<WebSocketState> get connectionState => _connectionStateController.stream;

  WebSocketManager(this._client);

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _setConnectionState(WebSocketState.connecting);
    try {
      await _client.connect('/ws/dashboard');
      _subscription = _client.messages.listen(
        _messagesController.add,
        onError: (e) {
          AppLogger.error('WS manager error', error: e);
          _setConnectionState(WebSocketState.disconnected);
        },
        onDone: () {
          _setConnectionState(WebSocketState.disconnected);
          if (_started) _attemptReconnect();
        },
        cancelOnError: false,
      );
      _setConnectionState(WebSocketState.connected);
    } catch (e) {
      AppLogger.error('WS manager connect failed', error: e);
      _setConnectionState(WebSocketState.disconnected);
    }
  }

  void _setConnectionState(WebSocketState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _attemptReconnect() {
    Future.delayed(const Duration(seconds: 5), () {
      if (_started) start();
    });
  }

  void stop() {
    _started = false;
    _subscription?.cancel();
    _subscription = null;
    _client.disconnect();
  }

  void dispose() {
    stop();
    _messagesController.close();
    _connectionStateController.close();
  }
}
