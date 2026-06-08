import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rc_car_protocol/rc_car_protocol.dart';
// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'webrtc_service.dart';
import 'telemetry_data.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;
  static const String carId = 'rc-car-room';
  static const String defaultApiUrl = 'http://192.168.10.159:3000';

  String apiUrl = defaultApiUrl;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final WebRTCService webRTC = WebRTCService();

  final _telemetryController = StreamController<TelemetryData>.broadcast();
  Stream<TelemetryData> get telemetryStream => _telemetryController.stream;

  Timer? _emitTimer;

  // Control State
  int steering = 50; // 0-180, center is 50
  int throttle = 0; // 0-255
  bool motorIn1 = false;
  bool motorIn2 = false;
  bool horn = false;

  bool headLight = false;
  bool highBeam = false;
  bool highBeamMomentary = false;
  bool fogLight = false;
  bool reverseLight = false;

  bool brakeLight = false;
  bool indicatorLeft = false;
  bool indicatorRight = false;

  void init() {
    final loadedApiUrl = dotenv.env['API_URL']?.trim();
    if (loadedApiUrl != null && loadedApiUrl.isNotEmpty) {
      apiUrl = loadedApiUrl;
    }
    _connect();
  }

  void updateApiUrl(String newUrl) {
    final trimmedUrl = newUrl.trim();
    if (trimmedUrl.isEmpty) return;

    apiUrl = trimmedUrl;
    debugPrint('SocketService: updating API URL to $apiUrl');
    _connect();
  }

  void _connect() {
    _stopEmitLoop();
    socket?.disconnect();
    socket?.dispose();

    _isConnected = false;
    _connectionController.add(false);

    socket = IO.io(apiUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket!.onConnect((_) async {
      debugPrint('Connected to socket server');
      _isConnected = true;
      _connectionController.add(true);

      socket!.emit('register', 'controller');
      socket!.emit('join', carId);

      await webRTC.init(socket!);

      _startEmitLoop();
    });

    socket!.onDisconnect((_) {
      debugPrint('Disconnected from socket server');
      _isConnected = false;
      _connectionController.add(false);
      _stopEmitLoop();
    });

    // Handle telemetry - Arduino format
    socket!.on('telem', (data) {
      final telemetry = ArduinoTelemetry.parse(data);
      if (telemetry != null) {
        _telemetryController.add(
          TelemetryData(
            telemetry.speed,
            telemetry.batteryVoltage,
            telemetry.batteryPercent,
            telemetry.rpm,
            0,
          ),
        );
      }
    });

    socket!.onConnectError((err) => debugPrint('Connect Error: $err'));
    socket!.onError((err) => debugPrint('Error: $err'));
  }

  void _startEmitLoop() {
    _emitTimer?.cancel();
    _emitTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      _sendArduinoCmd();
    });
  }

  void _stopEmitLoop() {
    _emitTimer?.cancel();
  }

  void _sendArduinoCmd() {
    if (!_isConnected) return;

    final commandBuffer = ArduinoCommandBuilder.buildCommand(
      steering: steering,
      throttle: throttle,
      motorIn1: motorIn1,
      motorIn2: motorIn2,
      headLight: headLight,
      highBeam: highBeam || highBeamMomentary,
      fogLight: fogLight,
      indicatorLeft: indicatorLeft,
      indicatorRight: indicatorRight,
      reverseLight: reverseLight,
      brakeLight: brakeLight,
      lowIntensityBrakeLight: headLight,
    );

    socket?.emit('cmd', commandBuffer.toList());
  }

  void stopWebRTC() {
    webRTC.stopVideo();
  }

  /// Request camera switch on the remote device
  /// If [mode] is null, bridge will toggle between front/back
  /// If [mode] is 'user' or 'environment', bridge will switch to that camera
  void requestCameraSwitch({String? mode}) {
    if (!_isConnected) {
      debugPrint('Cannot switch camera: not connected');
      return;
    }

    final payload = mode != null ? {'mode': mode} : {};
    socket?.emit('camera-switch', payload);
    debugPrint('Requested camera switch: ${mode ?? 'toggle'}');
  }

  void sendDirect({required bool horn}) {
    if (!_isConnected) {
      debugPrint('Cannot send direct event: not connected');
      return;
    }

    final payload = {'horn': horn};
    socket?.emit('direct', payload);
    debugPrint('Sent direct event: $payload');
  }

  void dispose() {
    _stopEmitLoop();
    webRTC.dispose();
    socket?.disconnect();
    socket?.dispose();
    _connectionController.close();
    _telemetryController.close();
  }
}
