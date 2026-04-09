import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, disconnecting, connecting, connected }

class WebSocketsHandler {
    void Function(String message)? _callback;
    String host = "localhost";
    String port = "8888";
    String? socketId;

    WebSocketChannel? _socketClient;
    ConnectionStatus connectionStatus = ConnectionStatus.disconnected;

    void connectToServer(
        String serverHost,
        int serverPort,
        void Function(String message) callback, {
        bool useSecureSocket = false,
        void Function(dynamic error)? onError,
        void Function()? onDone,
    }) {
        _callback = callback;
        host = serverHost;
        port = serverPort.toString();

        connectionStatus = ConnectionStatus.connecting;

        try {
            final Uri uri = Uri(
                scheme: useSecureSocket ? 'wss' : 'ws',
                host: host,
                port: serverPort,
            );

            _socketClient?.sink.close();
            _socketClient = WebSocketChannel.connect(uri);

            // Absorb async handshake failures so they do not bubble as unhandled.
            _socketClient!.ready
                    .then((_) {
                        connectionStatus = ConnectionStatus.connected;
                    })
                    .catchError((Object error) {
                        connectionStatus = ConnectionStatus.disconnected;
                        onError?.call(error);
                    });

            _socketClient!.stream.listen(
                (message) {
                    try {
                        final String text = message.toString();
                        _handleMessage(text);
                        _callback?.call(text);
                    } catch (error) {
                        if (kDebugMode) {
                            print('Error processant event WebSocket: $error');
                        }
                    }
                },
                onError: (error) {
                    connectionStatus = ConnectionStatus.disconnected;
                    onError?.call(error);
                },
                onDone: () {
                    connectionStatus = ConnectionStatus.disconnected;
                    onDone?.call();
                },
                cancelOnError: true,
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
        if (connectionStatus == ConnectionStatus.connected) {
            _socketClient!.sink.add(message);
        }
    }

    void disconnectFromServer() {
        connectionStatus = ConnectionStatus.disconnecting;
        _socketClient?.sink.close();
        _socketClient = null;
        connectionStatus = ConnectionStatus.disconnected;
    }
}
