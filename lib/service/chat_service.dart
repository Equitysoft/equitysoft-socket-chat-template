import 'package:chat_socket/mixin/socket_mixin.dart';
import 'package:get/get.dart'; // Import GetX package

class SocketService with SocketMixin {
  RxBool isLoading = false.obs; // RxBool to track loading state
  RxBool isConnect = false.obs; // RxBool to track loading state
  Rxn<SocketErrorType> socketError = Rxn<SocketErrorType>(); // Rx Socket Error

  SocketService();

  /// Initialize the socket connection with a specific URL
  void initialize(String url) {
    initializeSocket(socketUrl: url);
  }

  /// Register a custom event listener
  void listenToEvent(String event, Function(dynamic) callback) {
    onEvent(event, callback);
  }

  /// Emit a custom event
  void emitMessage(String event, dynamic data) {
    emitEvent(event, data);
  }

  /// Clean up resources
  void closeConnection() {
    disposeSocket();
  }
}
