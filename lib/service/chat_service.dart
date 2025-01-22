import 'package:chat_socket/mixin/socket_mixin.dart';
import 'package:get/get.dart'; // Import GetX package

class SocketService with SocketMixin {
  RxBool isLoading = false.obs; // RxBool to track loading state
  RxBool isConnect = false.obs; // RxBool to track loading state

  SocketService();

  /// Initializes the socket connection with a given URL
  void initialize(String socketUrl) {
    _updateConnectState(false);
    _updateLoadingState(true); // Set loading to true before initiating connection
    initializeSocket(socketUrl: socketUrl); // Call the method to start the connection
  }

  /// Emits a message through the socket
  void emitMessage(String event, dynamic data) {
    emitEvent(event, data);
  }

  /// Listens to a socket event and processes the callback
  void listenToEvent(String event, Function(dynamic) callback) {
    onEvent(event, callback);
  }

  /// Handle any socket errors based on error type
  @override
  void _handleSocketError(SocketErrorType errorType, String errorMessage) {
    // Handle the error and set loading to false
    _updateLoadingState(false);
    _updateConnectState(false);
    super.handleSocketError(errorType, errorMessage);
  }

  /// Updates the loading state
  void _updateLoadingState(bool loading) {
    isLoading.value = loading; // Set the value of the RxBool
  }

  /// Updates the Connection state
  void _updateConnectState(bool loading) {
    isLoading.value = loading; // Set the value of the RxBool
  }

  /// Updates connection state when connected
  @override
  void _connectToSocket() {
    super.connectToSocket();
    if (socket?.connected ?? false) {
      _updateLoadingState(false); // Set loading to false when connected
      _updateConnectState(true);
    }
  }

  /// Updates reconnection state when reconnecting
  @override
  void _reconnectWithBackoff() {
    super.reconnectWithBackoff();
    _updateLoadingState(true); // Set loading to true during reconnection attempts
    _updateConnectState(false);
  }

  /// Dispose of the socket connection
  void dispose() {
    disconnectSocket();
  }
}
