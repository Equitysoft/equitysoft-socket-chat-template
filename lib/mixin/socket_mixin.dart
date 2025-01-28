import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:connectivity_plus/connectivity_plus.dart';

/// Error types for socket handling
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
  late String _socketUrl;

  final Map<String, Function(dynamic)> _eventListeners = {};

  /// Reconnection logic parameters
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  final Duration _baseReconnectDelay = Duration(seconds: 2);

  /// Initialize the socket connection
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
          .setTransports(['websocket']) // Use WebSocket
          .disableAutoConnect() // Disable automatic connection
          .setReconnectionAttempts(0) // Disable built-in reconnection
          .build(),
    );

    if (socket != null) {
      socket!.onConnect((_) {
        _isConnecting = false; // Reset connecting flag
        _reconnectAttempts = 0; // Reset reconnect attempts
        _reRegisterEvents();
        print("Socket connected.");
      });

      socket!.onError((error) {
        _isConnecting = false;
        print("Socket error: $error");
        handleSocketError(SocketErrorType.connectionError, "Socket connection error: $error");
        reconnectWithBackoff();
      });

      socket!.onDisconnect((reason) {
        _isConnecting = false;
        print("Socket disconnected: $reason");
        handleSocketError(SocketErrorType.disconnectError, "Socket disconnected: $reason");
        if (!_forceDisconnect) {
          reconnectWithBackoff();
        }
      });

      socket!.connect();
    } else {
      _isConnecting = false;
      handleSocketError(SocketErrorType.unknownError, "Failed to initialize socket.");
    }
  }

  /// Reconnect using exponential backoff
  void reconnectWithBackoff() {
    if (_reconnectAttempts >= _maxReconnectAttempts || _forceDisconnect) {
      handleSocketError(SocketErrorType.maxReconnectAttemptsReached, "Max reconnect attempts reached.");
      return;
    }

    _reconnectAttempts++;
    final delay = _baseReconnectDelay * _reconnectAttempts;

    Future.delayed(delay, () {
      if (!_forceDisconnect) {
        print("Attempting to reconnect... (Attempt: $_reconnectAttempts)");
        connectToSocket();
      }
    });
  }

  /// Monitor internet connection status
  void _monitorInternetConnection() {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      if (_forceDisconnect) return;
      if (connectivityResult != ConnectivityResult.none) {
        print("Internet connected.");
        if (socket == null || !(socket!.connected)) {
          connectToSocket();
        }
      } else {
        handleSocketError(SocketErrorType.internetError, "Internet disconnected.");
      }
    });
  }

  /// Disconnect the socket
  void disconnectSocket() {
    _forceDisconnect = true;
    _isConnecting = false;
    if (socket != null) {
      socket!.disconnect();
      socket!.close();
      socket = null;
    }
    print("Socket forcefully disconnected.");
  }

  /// Re-register all event listeners
  void _reRegisterEvents() {
    _eventListeners.forEach((event, callback) {
      socket?.off(event); // Remove duplicate listeners
      socket?.on(event, callback);
      print("Re-registered event: $event");
    });
  }

  /// Emit an event
  void emitEvent(String event, dynamic data) {
    if (socket != null && socket!.connected) {
      socket!.emit(event, data);
    } else {
      handleSocketError(SocketErrorType.unknownError, "Cannot emit event, socket is not connected.");
    }
  }

  /// Listen for an event
  void onEvent(String event, Function(dynamic) callback) {
    _eventListeners[event] = callback;
    socket?.on(event, callback);
  }

  /// Handle socket errors
  void handleSocketError(SocketErrorType errorType, String errorMessage) {
    print("Error [$errorType]: $errorMessage");
    // Optionally, propagate the error to a listener or throw a custom exception
  }

  /// Dispose the socket resources
  void disposeSocket() {
    disconnectSocket();
    _eventListeners.clear();
  }
}
