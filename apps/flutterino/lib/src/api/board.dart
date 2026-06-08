import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../protocol/commands.dart';
import '../protocol/packet.dart';
import 'connection_status.dart';

class PrioritizedCommand implements Comparable<PrioritizedCommand> {
  final Packet packet;
  final int priority; // Lower is higher priority

  PrioritizedCommand(this.packet, this.priority);

  @override
  int compareTo(PrioritizedCommand other) => priority.compareTo(other.priority);
}

class FlutterinoBoard {
  late final void Function(dynamic) _sendToWorker;
  final Completer<void> _initCompleter = Completer<void>();
  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  final Map<int, StreamController<bool>> _digitalStreams = {};
  final Map<int, StreamController<int>> _analogStreams = {};
  final Map<int, StreamController<Uint8List>> _rawStreams = {};

  // State tracking for Auto-Sync Resilience
  final Map<int, PinMode> _pinModes = {};
  final Map<int, bool> _activeDigitalOutputs = {};
  final Map<int, int> _activeAnalogOutputs = {};
  final Set<int> _activeDigitalInputs = {};
  final Map<int, int> _activeAnalogInputs = {}; // pin -> interval ms

  ConnectionStatus _currentStatus = ConnectionStatus.searching;

  final PriorityQueue<PrioritizedCommand> _commandQueue =
      PriorityQueue<PrioritizedCommand>();
  bool _isProcessingQueue = false;

  FlutterinoBoard();

  void attachWorker(void Function(dynamic) sendToWorker) {
    _sendToWorker = sendToWorker;
  }

  Future<void> waitForInitialization() => _initCompleter.future;

  Stream<ConnectionStatus> get connectionStatus => _statusController.stream;
  ConnectionStatus get status => _currentStatus;

  void _updateStatus(ConnectionStatus newStatus) {
    if (_currentStatus != newStatus) {
      // Transition mapping
      if (_currentStatus == ConnectionStatus.connected &&
          newStatus == ConnectionStatus.searching) {
        newStatus = ConnectionStatus.reconnecting;
      }

      debugPrint(
        '[FlutterinoBoard] Status changed from $_currentStatus to $newStatus',
      );
      _currentStatus = newStatus;
      _statusController.add(newStatus);

      if (newStatus == ConnectionStatus.connected) {
        _syncState();
      }
    }
  }

  void handleWorkerMessage(dynamic message) {
    if (message == 'init' && !_initCompleter.isCompleted) {
      debugPrint(
        '[FlutterinoBoard] Initialization complete. Sending connect signal.',
      );
      _initCompleter.complete();
      _sendToWorker('connect');
    } else if (message is Packet) {
      _routeIncomingPacket(message);
    } else if (message is Map) {
      if (message.containsKey('status')) {
        switch (message['status']) {
          case 'connected':
            _updateStatus(ConnectionStatus.connected);
            break;
          case 'searching':
            _updateStatus(ConnectionStatus.searching);
            break;
          case 'disconnected':
            _updateStatus(ConnectionStatus.disconnected);
            break;
          case 'permission_denied':
            _updateStatus(ConnectionStatus.permissionDenied);
            break;
        }
      } else if (message.containsKey('error')) {
        debugPrint(
          '[FlutterinoBoard] Worker reported error: ${message['error']}',
        );
        _updateStatus(ConnectionStatus.error);
      }
    }
  }

  void _routeIncomingPacket(Packet packet) {
    if (packet.cmdId == CommandIds.reportDigital &&
        packet.payload.length >= 2) {
      int pin = packet.payload[0];
      bool value = packet.payload[1] == 1;
      _digitalStreams[pin]?.add(value);
    } else if (packet.cmdId == CommandIds.reportAnalog &&
        packet.payload.length >= 3) {
      int pin = packet.payload[0];
      int highByte = packet.payload[1];
      int lowByte = packet.payload[2];
      int val = (highByte << 8) | lowByte;
      _analogStreams[pin]?.add(val);
    } else {
      if (_rawStreams.containsKey(packet.cmdId)) {
        _rawStreams[packet.cmdId]!.add(Uint8List.fromList(packet.payload));
      }
    }
  }

  void _enqueue(Packet packet, {required int priority}) {
    _commandQueue.add(PrioritizedCommand(packet, priority));
    _processQueue();
  }

  void _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_commandQueue.isNotEmpty) {
      if (_currentStatus != ConnectionStatus.connected) {
        break;
      }
      final cmd = _commandQueue.removeFirst();
      _sendToWorker(cmd.packet);
      await Future.delayed(const Duration(milliseconds: 2));
    }

    _isProcessingQueue = false;
  }

  void _syncState() {
    debugPrint('[FlutterinoBoard] Syncing state after connection recovery.');
    for (var entry in _pinModes.entries) {
      _enqueue(
        Packet(
          msgType: ProtocolConstants.typeCommand,
          cmdId: CommandIds.pinMode,
          payload: [entry.key, entry.value.value],
        ),
        priority: 0,
      );
    }

    for (var entry in _activeDigitalOutputs.entries) {
      _enqueue(
        Packet(
          msgType: ProtocolConstants.typeCommand,
          cmdId: CommandIds.digitalWrite,
          payload: [entry.key, entry.value ? 1 : 0],
        ),
        priority: 1,
      );
    }

    for (var entry in _activeAnalogOutputs.entries) {
      _enqueue(
        Packet(
          msgType: ProtocolConstants.typeCommand,
          cmdId: CommandIds.analogWrite,
          payload: [entry.key, entry.value],
        ),
        priority: 1,
      );
    }

    for (var pin in _activeDigitalInputs) {
      _enqueue(
        Packet(
          msgType: ProtocolConstants.typeCommand,
          cmdId: CommandIds.reportDigital,
          payload: [pin, 1],
        ),
        priority: 2,
      );
    }

    for (var entry in _activeAnalogInputs.entries) {
      _enqueue(
        Packet(
          msgType: ProtocolConstants.typeCommand,
          cmdId: CommandIds.reportAnalog,
          payload: [entry.key, entry.value],
        ),
        priority: 2,
      );
    }
  }

  // --- Public API ---

  void sendRaw(int cmdId, Uint8List data) {
    _enqueue(
      Packet(
        msgType: ProtocolConstants.typeCommand,
        cmdId: cmdId,
        payload: data.toList(),
      ),
      priority: 0,
    );
  }

  Stream<Uint8List> subscribe(int cmdId) {
    if (!_rawStreams.containsKey(cmdId)) {
      _rawStreams[cmdId] = StreamController<Uint8List>.broadcast(
        onCancel: () {
          _rawStreams.remove(cmdId);
        },
      );
    }
    return _rawStreams[cmdId]!.stream;
  }

  void pinMode(int pin, PinMode mode) {
    debugPrint('[FlutterinoBoard] Setting pinMode: pin=$pin, mode=$mode');
    _pinModes[pin] = mode;
    _enqueue(
      Packet(
        msgType: ProtocolConstants.typeCommand,
        cmdId: CommandIds.pinMode,
        payload: [pin, mode.value],
      ),
      priority: 0, // Highest priority
    );
  }

  void digitalWrite(int pin, bool value) {
    _activeDigitalOutputs[pin] = value;
    _enqueue(
      Packet(
        msgType: ProtocolConstants.typeCommand,
        cmdId: CommandIds.digitalWrite,
        payload: [pin, value ? 1 : 0],
      ),
      priority: 1, // Actuators take priority
    );
  }

  void analogWrite(int pin, int value) {
    if (value < 0) value = 0;
    if (value > 255) value = 255;
    _activeAnalogOutputs[pin] = value;
    _enqueue(
      Packet(
        msgType: ProtocolConstants.typeCommand,
        cmdId: CommandIds.analogWrite,
        payload: [pin, value],
      ),
      priority: 1,
    );
  }

  void servoWrite(int pin, int angle) {
    if (angle < 0) angle = 0;
    if (angle > 180) angle = 180;
    _enqueue(
      Packet(
        msgType: ProtocolConstants.typeCommand,
        cmdId: CommandIds.servoWrite,
        payload: [pin, angle],
      ),
      priority: 1,
    );
  }

  Stream<bool> subscribeDigital(int pin) {
    debugPrint('[FlutterinoBoard] Subscribing digital: pin=$pin');
    if (!_digitalStreams.containsKey(pin)) {
      _digitalStreams[pin] = StreamController<bool>.broadcast(
        onListen: () {
          _activeDigitalInputs.add(pin);
          _enqueue(
            Packet(
              msgType: ProtocolConstants.typeCommand,
              cmdId: CommandIds.reportDigital,
              payload: [pin, 1],
            ),
            priority: 2, // Telemetry priority
          );
        },
        onCancel: () {
          _activeDigitalInputs.remove(pin);
          _enqueue(
            Packet(
              msgType: ProtocolConstants.typeCommand,
              cmdId: CommandIds.reportDigital,
              payload: [pin, 0],
            ),
            priority: 2,
          );
          _digitalStreams.remove(pin);
        },
      );
    }
    return _digitalStreams[pin]!.stream;
  }

  Stream<int> subscribeAnalog(int pin, {int intervalMs = 50}) {
    debugPrint(
      '[FlutterinoBoard] Subscribing analog: pin=$pin, intervalMs=$intervalMs',
    );
    if (!_analogStreams.containsKey(pin)) {
      _analogStreams[pin] = StreamController<int>.broadcast(
        onListen: () {
          _activeAnalogInputs[pin] = intervalMs;
          _enqueue(
            Packet(
              msgType: ProtocolConstants.typeCommand,
              cmdId: CommandIds.reportAnalog,
              payload: [pin, intervalMs],
            ),
            priority: 2,
          );
        },
        onCancel: () {
          _activeAnalogInputs.remove(pin);
          _enqueue(
            Packet(
              msgType: ProtocolConstants.typeCommand,
              cmdId: CommandIds.reportAnalog,
              payload: [pin, 0],
            ),
            priority: 2,
          );
          _analogStreams.remove(pin);
        },
      );
    }
    return _analogStreams[pin]!.stream;
  }

  void disconnect() {
    debugPrint('[FlutterinoBoard] Disconnect requested.');
    _sendToWorker('disconnect');
  }

  void dispose() {
    debugPrint('[FlutterinoBoard] Disposing board.');
    _sendToWorker('kill');
    _statusController.close();
    for (var controller in _digitalStreams.values) {
      controller.close();
    }
    for (var controller in _analogStreams.values) {
      controller.close();
    }
    for (var controller in _rawStreams.values) {
      controller.close();
    }
  }
}
