// ============================================================
//  Socket Service
//  Handles Socket.IO connection and communication with the server.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  // ── Singleton ─────────────────────────────────────────────
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  // ── Socket.IO ─────────────────────────────────────────────
  IO.Socket? _socket;
  bool _isConnected = false;

  // ── Callbacks ─────────────────────────────────────────────
  Function()? onConnected;
  Function()? onDisconnected;
  Function(Uint8List)? onCommandReceived;
  Function(dynamic)? onSignalReceived;
  Function(dynamic)? onCameraSwitchReceived;
  Function(dynamic)? onDirectReceived;

  bool get isConnected => _isConnected;

  // ── Connect to Socket.IO server ───────────────────────────
  void connect(String serverUrl) {
    debugPrint('[SocketService] Attempting to connect to: $serverUrl');

    // Dispose old socket if exists
    if (_socket != null) {
      debugPrint('[SocketService] Disposing existing socket connection');
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket']) // skip long-polling, go straight to WS
          .enableAutoConnect()
          .setExtraHeaders({'Connection': 'Upgrade'})
          .build(),
    );

    _socket!.on('connect', (_) {
      debugPrint('[SocketService] Connected to server');
      // Identify ourselves as the bridge
      _socket!.emit('register', 'bridge');
      debugPrint('[SocketService] Registered as bridge');
      _isConnected = true;
      onConnected?.call();
    });

    _socket!.on('disconnect', (_) {
      debugPrint('[SocketService] Disconnected from server');
      _isConnected = false;
      onDisconnected?.call();
    });

    _socket!.on('connect_error', (error) {
      debugPrint('[SocketService] Connection error: $error');
    });

    _socket!.on('error', (error) {
      debugPrint('[SocketService] Socket error: $error');
    });

    // Receive a command buffer from the controller and forward to callback
    _socket!.on('cmd', (data) {
      // debugPrint('[SocketService] Received cmd: $data');
      if (data is List) {
        final buf = Uint8List.fromList(List<int>.from(data));
        onCommandReceived?.call(buf);
      }
    });

    // Receive WebRTC signaling messages
    _socket!.on('signal', (data) {
      debugPrint('[SocketService] Received signal: $data');
      onSignalReceived?.call(data);
    });

    // Receive camera switch requests from remote controller
    _socket!.on('camera-switch', (data) {
      debugPrint('[SocketService] Received camera-switch: $data');
      onCameraSwitchReceived?.call(data);
    });

    // Receive direct actions from the server (e.g. horn control)
    _socket!.on('direct', (data) {
      debugPrint(
        '[SocketService] Received direct event: $data (${data.runtimeType})',
      );
      dynamic normalizedData = data;
      if (data is String) {
        try {
          normalizedData = jsonDecode(data);
          debugPrint(
            '[SocketService] Parsed direct event JSON: $normalizedData (${normalizedData.runtimeType})',
          );
        } catch (e) {
          debugPrint(
            '[SocketService] Failed to parse direct event as JSON: $e',
          );
        }
      }
      onDirectReceived?.call(normalizedData);
    });
  }

  // ── Send telemetry to server ──────────────────────────────
  void sendTelemetry(Uint8List data) {
    if (_isConnected && _socket != null) {
      _socket!.emit('telem', data.toList());
    }
  }

  // ── Send control/signaling messages ───────────────────────
  void emitControl(String event, dynamic data) {
    if (_isConnected && _socket != null) {
      debugPrint('[SocketService] Emitting $event: $data');
      _socket!.emit(event, data);
    } else {
      debugPrint('[SocketService] Cannot emit $event - not connected');
    }
  }

  // ── Disconnect and cleanup ────────────────────────────────
  void dispose() {
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
