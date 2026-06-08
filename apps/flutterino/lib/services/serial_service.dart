// ============================================================
//  Serial Service
//  Handles USB serial communication with the Arduino.
// ============================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutterino/debug_config.dart';
import 'package:usb_serial/usb_serial.dart';

class SerialService {
  // ── Constants ─────────────────────────────────────────────
  final int baudRate;
  final int startByte;
  final int telStartByte;
  final int telemBufferLength;

  // ── USB serial ────────────────────────────────────────────
  UsbPort? _port;
  StreamSubscription? _usbDataSub;
  StreamSubscription? _usbEventSub;
  final List<int> _telemAccum = []; // accumulate incoming telem bytes
  bool _telemSynced = false;
  bool _isConnected = false;

  // ── USB keepalive ─────────────────────────────────────────
  Timer? _keepaliveTimer;
  // Pre-allocated zero byte — reused every 200 ms to avoid GC churn
  static final Uint8List _keepaliveBuf = Uint8List(1);

  // ── Debug throttle ────────────────────────────────────────
  // Limits kSerialDebug prints to at most one per interval so logcat
  // backpressure doesn't reintroduce lag during debug sessions.
  static const Duration _debugThrottle = Duration(milliseconds: 1000);
  DateTime _lastTxLog = DateTime(0);
  DateTime _lastRxLog = DateTime(0);

  // ── Callbacks ─────────────────────────────────────────────
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String)? onStatusUpdate;
  Function(Uint8List)? onTelemetryReceived;

  bool get isConnected => _isConnected;

  SerialService({
    required this.baudRate,
    required this.startByte,
    required this.telemBufferLength,
    required this.telStartByte,
  });

  // ── Initialize: watch for device attach / detach ──────────
  void initialize() {
    _usbEventSub = UsbSerial.usbEventStream?.listen((UsbEvent event) {
      if (event.event == UsbEvent.ACTION_USB_ATTACHED) {
        openUsb();
      } else if (event.event == UsbEvent.ACTION_USB_DETACHED) {
        closeUsb();
      }
    });
    // Try to open immediately in case already connected
    openUsb();
  }

  // ── Open USB connection ───────────────────────────────────
  Future<void> openUsb() async {
    final devices = await UsbSerial.listDevices();
    if (devices.isEmpty) {
      _isConnected = false;
      onStatusUpdate?.call('No USB device found');
      onDisconnected?.call();
      return;
    }

    final device = devices.first;
    _port = await device.create();
    if (_port == null) return;

    final opened = await _port!.open();
    if (!opened) {
      _isConnected = false;
      onStatusUpdate?.call('Could not open USB port');
      onDisconnected?.call();
      return;
    }

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(
      baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    // Listen for telemetry coming back from the Arduino
    _usbDataSub = _port!.inputStream?.listen(_onArduinoData);

    // Send a zero packet every 200ms to keep the USB host controller
    // awake. Without this, Android suspends the USB device after ~500ms
    // of inactivity and the first real write after that takes 500-1000ms
    // to wake it back up — causing intermittent lag.
    _keepaliveTimer?.cancel();
    _keepaliveTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_port != null && _isConnected) {
        _port!.write(_keepaliveBuf);
      }
    });

    _isConnected = true;
    onStatusUpdate?.call('USB connected');
    onConnected?.call();
  }

  // ── Close USB connection ──────────────────────────────────
  void closeUsb() {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    _usbDataSub?.cancel();
    _port?.close();
    _port = null;
    _isConnected = false;
    onStatusUpdate?.call('USB disconnected');
    onDisconnected?.call();
  }

  // ── Forward raw bytes to Arduino ──────────────────────────
  // Intentionally NOT awaited — fire and forget into the USB driver's
  // internal buffer. Awaiting the write Future on Android can block for
  // 50-100ms waiting for USB transfer acknowledgement.
  void sendToArduino(Uint8List buf) {
    if (_port == null || !_isConnected) return;
    if (kSerialDebug) {
      final now = DateTime.now();
      if (now.difference(_lastTxLog) >= _debugThrottle) {
        _lastTxLog = now;
        // debugPrint('[Serial TX] ${buf.length}b: $buf');
      }
    }
    _port!.write(buf);
  }

  // ── Accumulate framed telemetry from Arduino ──────────────
  // Mirrors the Arduino's receiveCmdBuffer() state machine in reverse.
  void _onArduinoData(Uint8List incoming) {
    for (final b in incoming) {
      if (!_telemSynced) {
        if (b == telStartByte) {
          _telemSynced = true;
          _telemAccum.clear();
        }
        continue;
      }
      if (b == telStartByte) {
        // Unexpected start byte — re-sync
        _telemAccum.clear();
        continue;
      }
      _telemAccum.add(b);
      if (_telemAccum.length == telemBufferLength) {
        final packet = Uint8List.fromList(_telemAccum);
        if (kSerialDebug) {
          final now = DateTime.now();
          if (now.difference(_lastRxLog) >= _debugThrottle) {
            _lastRxLog = now;
            final adcCount = (packet[0] << 8) | packet[1];
            final rpm = ((packet[2] << 8) | packet[3]) / 100.0;

            final speedMs = ((packet[4] << 8) | packet[5]) / 100.0;
            final voltage = (adcCount / 1023.0) * 12.0;
            debugPrint(
              '[Serial RX] telem ${packet.length}b  battery=${voltage.toStringAsFixed(2)}V Rpm=$rpm speed=${speedMs}m/s raw=$packet',
            );
          }
        }
        _telemAccum.clear();
        _telemSynced = false; // require fresh start byte for next packet
        onTelemetryReceived?.call(packet);
      }
    }
  }

  // ── Cleanup ───────────────────────────────────────────────
  void dispose() {
    _keepaliveTimer?.cancel();
    _usbDataSub?.cancel();
    _usbEventSub?.cancel();
    _port?.close();
  }
}
