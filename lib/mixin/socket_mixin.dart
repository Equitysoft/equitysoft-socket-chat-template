import 'package:chat_socket/utils/logger.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:connectivity_plus/connectivity_plus.dart';

/// All Error types
enum SocketErrorType {
  connectionError,
  disconnectError,
  internetError,
  maxReconnectAttemptsReached,
  unknownError,
}

mixin SocketMixin {
  IO.Socket? socket;
  bool _isConnecting = false;
  bool _forceDisconnect = false;
  late String _socketUrl = ""; // Replace with your socket server URL

  final Map<String, Function(dynamic)> _eventListeners = {};

  /// Exponential backoff parameters
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  final Duration _baseReconnectDelay = Duration(seconds: 2);

  /// Initializes the socket connection
  void initializeSocket({required String socketUrl}) {
    _socketUrl = socketUrl;
    connectToSocket();
    _monitorInternetConnection();
  }

  /// Connect to the socket server
  void connectToSocket() {
    if (_isConnecting || _forceDisconnect) return;
    _isConnecting = true;

    socket = IO.io(
      _socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()         // Disable auto-connect
          .setRememberUpgrade(false)  // Disable default reconnection
          .setReconnectionAttempts(10)
          .build(),
    );

    if (socket != null) {

      socket!.onError((error) async {
        handleSocketError(SocketErrorType.connectionError, 'Socket connection error: $error');
        reconnectWithBackoff();
      });

      socket!.onConnect((_) {
        _reconnectAttempts = 0; // Reset attempts on successful connection
        _reRegisterEvents();
        logger.i("socket is connected");
      });

      socket!.onDisconnect((reason) {
        handleSocketError(SocketErrorType.disconnectError, 'Socket disconnected: $reason');
        if (!_forceDisconnect) {
          reconnectWithBackoff();
        }
      });

      socket!.connect();
    }

    _isConnecting = false;
  }

  /// Reconnect logic with exponential backoff
  void reconnectWithBackoff() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      handleSocketError(SocketErrorType.maxReconnectAttemptsReached, 'Max reconnect attempts reached');
      return;
    }

    final delay = _baseReconnectDelay * (_reconnectAttempts + 1);
    _reconnectAttempts++;

    Future.delayed(delay, () {
      if (!_forceDisconnect) {
        connectToSocket();
      }
    });
  }

  /// Monitors internet connectivity and reconnects the socket if needed
  void _monitorInternetConnection() {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      if (connectivityResult != ConnectivityResult.none) {
        print('Internet connected');
        if (socket == null || !(socket!.connected)) {
          connectToSocket();
        }
      } else {
        handleSocketError(SocketErrorType.internetError, 'Internet disconnected');
      }
    });
  }

  /// Disconnects the socket forcefully
  void disconnectSocket() {
    _forceDisconnect = true;
    if (socket != null) {
      socket!.disconnect();
      socket!.close();
      print('Socket forcefully disconnected');
    }
  }

  /// Re-register all event listeners
  void _reRegisterEvents() {
    _eventListeners.forEach((event, callback) {
      socket?.on(event, callback); // Re-register event
    });
    print("Re-registered all socket events");
  }

  /// Emits an event through the socket
  void emitEvent(String event, dynamic data) {
    if (socket != null && socket!.connected) {
      socket!.emit(event, data);
    } else {
      handleSocketError(SocketErrorType.unknownError, 'Cannot emit, socket is not connected');
    }
  }

  /// Listens to an event from the socket
  void onEvent(String event, Function(dynamic) callback) {
    _eventListeners[event] = callback; // Store event and callback
    if (socket != null) {
      socket!.on(event, callback); // Register event with the socket
    }
  }

  /// Handles errors and prints/logs them
  void handleSocketError(SocketErrorType errorType, String errorMessage) {
    // You can throw custom exceptions or handle specific errors based on the type
    throw SocketException(errorType, errorMessage);
  }

  /// Disposes of the socket and its resources
  void disposeSocket() {
    disconnectSocket();
    socket = null;
    _eventListeners.clear();
  }
}

class SocketException implements Exception {
  final SocketErrorType type;
  final String message;

  SocketException(this.type, this.message);

  @override
  String toString() {
    return 'SocketException: $message (ErrorType: $type)';
  }
}
