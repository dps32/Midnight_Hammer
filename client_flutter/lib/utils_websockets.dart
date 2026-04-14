import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, disconnecting, connecting, connected }

class WebSocketsHandler {
  late Function _callback;
  String host = "localhost";
  String port = "8888";
  String? socketId;

  WebSocketChannel? _socketClient;
  StreamSubscription<dynamic>? _streamSubscription;
  ConnectionStatus connectionStatus = ConnectionStatus.disconnected;

  void connectToServer(
    String serverHost,
    int serverPort,
    void Function(String message) callback, {
    bool useSecureSocket = false,
    void Function(dynamic error)? onError,
    void Function()? onDone,
  }) async {
    _callback = callback;
    host = serverHost;
    port = serverPort.toString();

    connectionStatus = ConnectionStatus.connecting;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _socketClient = null;

    try {
      final Uri uri = Uri(
        scheme: useSecureSocket ? 'wss' : 'ws',
        host: host,
        port: serverPort,
      );
      final WebSocketChannel channel = WebSocketChannel.connect(uri);
      _socketClient = channel;

      channel.ready.then((_) {
        if (!identical(_socketClient, channel)) {
          return;
        }
        connectionStatus = ConnectionStatus.connected;
      }).catchError((dynamic error) {
        if (!identical(_socketClient, channel)) {
          return;
        }
        connectionStatus = ConnectionStatus.disconnected;
        onError?.call(error);
      });

      _streamSubscription = channel.stream.listen(
        (message) {
          if (message is String) {
            _handleMessage(message);
            _callback(message);
          }
        },
        onError: (error) {
          if (!identical(_socketClient, channel)) {
            return;
          }
          connectionStatus = ConnectionStatus.disconnected;
          onError?.call(error);
        },
        onDone: () {
          if (!identical(_socketClient, channel)) {
            return;
          }
          connectionStatus = ConnectionStatus.disconnected;
          onDone?.call();
        },
        cancelOnError: false,
      );
    } catch (e) {
      connectionStatus = ConnectionStatus.disconnected;
      onError?.call(e);
    }
  }

  void _handleMessage(String message) {
    try {
      final data = jsonDecode(message);
      if (data is Map<String, dynamic> &&
          data.containsKey("type") &&
          data["type"] == "welcome" &&
          data.containsKey("id")) {
        socketId = data["id"];
        if (kDebugMode) {
          print("Client ID assignat pel servidor: $socketId");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error processant missatge WebSocket: $e");
      }
    }
  }

  void sendMessage(String message) {
    final WebSocketChannel? client = _socketClient;
    if (connectionStatus == ConnectionStatus.connected && client != null) {
      try {
        client.sink.add(message);
      } catch (e) {
        connectionStatus = ConnectionStatus.disconnected;
      }
    }
  }

  void disconnectFromServer() {
    connectionStatus = ConnectionStatus.disconnecting;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _socketClient?.sink.close();
    _socketClient = null;
    connectionStatus = ConnectionStatus.disconnected;
  }
}
