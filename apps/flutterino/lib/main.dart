// ============================================================
//  RC Car – Android Bridge App
//  Bridges USB-Serial (Arduino) ↔ Socket.IO server.
//  Packages needed in pubspec.yaml:
//    usb_serial: ^0.5.1
//    socket_io_client: ^2.0.3+1
// ============================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'debug_config.dart';
import 'services/device_actions_service.dart';
import 'services/foreground_service_controller.dart';
import 'services/serial_service.dart';
import 'services/socket_service.dart';
import 'services/webrtc_service.dart';

// ── Constants ────────────────────────────────────────────────
const String kServerUrl = 'http://192.168.10.159:3000';
const int kBaudRate = 115200;
const int kStartByte = 0xFF;
const int kTelemStartByte = 0xFE;
const int kCmdBufLen = 16;
const int kTelemBufLen = 8;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialise the foreground service options before the app starts.
  ForegroundServiceController().init();
  runApp(const BridgeApp());
}

class BridgeApp extends StatelessWidget {
  const BridgeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RC Bridge',
    theme: ThemeData.dark(),
    home: const BridgePage(),
  );
}

class BridgePage extends StatefulWidget {
  const BridgePage({super.key});
  @override
  State<BridgePage> createState() => _BridgePageState();
}

class _BridgePageState extends State<BridgePage> {
  // ── State ─────────────────────────────────────────────────
  String _status = 'Idle';
  bool _usbOk = false;
  bool _socketOk = false;
  // int _telemTx = 0;
  int _batteryPercent = 0;
  // Calling setState() on every incoming packet causes needless rebuilds.
  Timer? _uiRefreshTimer;
  Timer? _batteryRefreshTimer;

  final Battery _battery = Battery();
  late final TextEditingController _serverUrlController;

  // ── Services ──────────────────────────────────────────────
  late final SocketService _socketService;
  late final SerialService _serialService;
  late final WebRTCService _webrtcService;
  late final DeviceActionsService _deviceActionsService;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService();
    _webrtcService = WebRTCService();
    _deviceActionsService = DeviceActionsService();
    _serverUrlController = TextEditingController(text: kServerUrl);
    _serialService = SerialService(
      baudRate: kBaudRate,
      startByte: kStartByte,
      telemBufferLength: kTelemBufLen,
      telStartByte: kTelemStartByte,
    );
    _initializeServices();
    _requestAndStartForeground();
    // Update the telem counter in the UI once per second
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initializeServices() async {
    debugPrint('[Main] Starting service initialization...');

    // Initialize Socket Service
    debugPrint('[Main] Initializing Socket Service...');
    _socketService.onConnected = () {
      debugPrint('[Main] Socket connected callback triggered');
      setState(() {
        _socketOk = true;
        _status = 'Socket connected';
      });
    };
    _socketService.onDisconnected = () {
      debugPrint('[Main] Socket disconnected callback triggered');
      setState(() {
        _socketOk = false;
        _status = 'Socket disconnected';
      });
    };
    _socketService.onCommandReceived = (buf) {
      // debugPrint('[Main] Command received: ${buf.length} bytes');
      _serialService.sendToArduino(buf);
    };
    _socketService.onSignalReceived = (data) {
      debugPrint('[Main] Signal received, forwarding to WebRTC service');
      // Forward WebRTC signaling messages to WebRTC service
      _webrtcService.handleSignal(data);
    };
    _socketService.onCameraSwitchReceived = (data) {
      debugPrint('[Main] Camera switch request received from remote');
      final mode = data is Map ? data['mode'] as String? : null;
      _webrtcService.switchCamera(desiredFacingMode: mode);
    };
    _socketService.onDirectReceived = (data) {
      debugPrint('[Main] Direct event received: $data (${data.runtimeType})');
      bool hornPressed = false;
      if (data is Map) {
        hornPressed = data['horn'] == true;
      }
      _deviceActionsService.handleHorn(hornPressed);
    };
    _updateBatteryLevel();
    _batteryRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateBatteryLevel(),
    );

    _connectSocket();

    // Initialize WebRTC Service
    debugPrint(
      '[Main] Initializing WebRTC Service (kDisableWebRTC=$kDisableWebRTC)...',
    );
    if (!kDisableWebRTC) {
      await _webrtcService.init();
      debugPrint('[Main] WebRTC Service initialized');
    } else {
      debugPrint('[Main] WebRTC Service disabled');
    }

    // Initialize Device Actions Service
    debugPrint('[Main] Initializing Device Actions Service...');
    await _deviceActionsService.init();
    debugPrint('[Main] Device Actions Service initialized');

    // Initialize Serial Service
    debugPrint('[Main] Initializing Serial Service...');
    _serialService.onConnected = () {
      setState(() {
        _usbOk = true;
        _status = 'USB connected';
      });
    };
    _serialService.onDisconnected = () {
      setState(() {
        _usbOk = false;
      });
    };
    _serialService.onStatusUpdate = (status) {
      setState(() {
        _status = status;
      });
    };
    _serialService.onTelemetryReceived = (packet) {
      final packetWithBattery = Uint8List.fromList(packet);
      if (packetWithBattery.length > 6) {
        packetWithBattery[6] = _batteryPercent.clamp(0, 100);
      }
      _socketService.sendTelemetry(packetWithBattery);
      // _telemTx++; // incremented here; UI is refreshed by _uiRefreshTimer
    };
    _serialService.initialize();
    debugPrint('[Main] All services initialized successfully');
  }

  void _connectSocket() {
    final serverUrl = _serverUrlController.text.trim();
    if (serverUrl.isEmpty) {
      setState(() {
        _status = 'Server URL is empty';
      });
      return;
    }

    debugPrint('[Main] Connecting to server: $serverUrl');
    setState(() {
      _socketOk = false;
      _status = 'Connecting to server...';
    });
    _socketService.connect(serverUrl);
  }

  Future<void> _requestAndStartForeground() async {
    await ForegroundServiceController().requestPermissions();
    await ForegroundServiceController().startService();
  }

  Future<void> _updateBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      _batteryPercent = level.clamp(0, 100);
    } catch (e) {
      debugPrint('[Main] Failed to read battery level: $e');
    }
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _batteryRefreshTimer?.cancel();
    _serverUrlController.dispose();
    _serialService.dispose();
    _socketService.dispose();
    _webrtcService.dispose();
    _deviceActionsService.dispose();
    ForegroundServiceController().stopService();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RC Bridge')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusTile(label: 'Socket.IO', ok: _socketOk),
                    const SizedBox(height: 8),
                    _StatusTile(label: 'USB Serial', ok: _usbOk),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Socket.IO Server URL',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      enableSuggestions: false,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _connectSocket,
                      child: const Text('Update Server URL'),
                    ),
                    const Divider(height: 32),
                    Text('Status : $_status'),
                    // const SizedBox(height: 8),
                    // Text('Telemetry sent    : $_telemTx'),
                    if (!kDisableWebRTC) ...[
                      const Divider(height: 32),

                      // const Text(
                      //   'WebRTC Camera Preview',
                      //   style: TextStyle(
                      //     fontSize: 16,
                      //     fontWeight: FontWeight.bold,
                      //   ),
                      // ),
                      // const SizedBox(height: 8),
                      // Container(
                      //   height: 200,
                      //   decoration: BoxDecoration(
                      //     border: Border.all(color: Colors.grey),
                      //     borderRadius: BorderRadius.circular(8),
                      //   ),
                      //   child: ClipRRect(
                      //     borderRadius: BorderRadius.circular(8),
                      //     child: RTCVideoView(_webrtcService.localRenderer),
                      //   ),
                      // ),
                    ],
                  ],
                ),
              ),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _serialService.openUsb,
                  child: const Text('Reconnect USB'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final bool ok;
  const _StatusTile({required this.label, required this.ok});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        ok ? Icons.check_circle : Icons.cancel,
        color: ok ? Colors.green : Colors.red,
      ),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 16)),
    ],
  );
}
