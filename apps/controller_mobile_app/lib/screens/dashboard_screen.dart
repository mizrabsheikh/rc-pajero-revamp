import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/socket_service.dart';
import '../services/voice_command_service.dart';
import '../widgets/video_feed_layer.dart';
import '../widgets/hud_layer.dart';
import '../widgets/left_controls_layer.dart';
import '../widgets/right_controls_layer.dart';
import '../widgets/auxiliary_controls_layer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  final VoiceCommandService _voiceService = VoiceCommandService();
  final AudioPlayer _indicatorAudioPlayer = AudioPlayer();
  bool _isIndicatorSoundPlaying = false;
  bool _hazardsOn = false;
  bool _headlightWasOnBeforeDipper = false;
  VoiceState _voiceState = VoiceState.idle;

  double _speed = 0.0;
  double _battery = 0.0;
  int _batteryPercent = 0;
  int _rpm = 0;
  String _transmission = 'N'; // R, N, D
  String _previousTransmission =
      'N'; // Track previous gear for auto camera switch
  bool _isWebRTCConnected = false; // Track WebRTC connection state
  bool _isLandscapeMode = false;
  static const int inGearStartValue = 50;
  double _steering = 0.0; // actual steering value used for physics
  double _targetSteering = 0.0; // raw wheel input from UI
  late final Ticker _steeringTicker;
  double _accelerator = 0.0; // 0.0 to 1.0
  bool _isBraking = false;

  final List<String> _logs = [
    "[SYSTEM] Ready.",
    "[WEBRTC] Connection established.",
  ];

  @override
  void initState() {
    super.initState();
    _socketService.init();
    _steeringTicker = createTicker(_handleSteeringTick);
    _indicatorAudioPlayer.setReleaseMode(ReleaseMode.loop);

    _socketService.telemetryStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _speed = data.speed;
        _battery = data.batteryVoltage;
        _batteryPercent = data.batteryPercent;
        _rpm = data.rpm;
      });
    });

    // Listen to WebRTC connection state for auto camera switching
    _socketService.webRTC.connectionStateStream.listen((state) {
      if (!mounted) return;
      final isConnected =
          state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      setState(() {
        _isWebRTCConnected = isConnected;
      });
    });

    _socketService.webRTC.onLog = (logMsg) {
      _addLog(logMsg);
    };

    // Initialize voice service
    _voiceService.initialize().then((success) {
      if (success) {
        _addLog('[VOICE] Voice service initialized');
      } else {
        _addLog('[VOICE] Failed to initialize voice service');
      }
    });

    // Listen to voice state changes
    _voiceService.stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _voiceState = state;
      });
    });

    // Listen to voice messages
    _voiceService.messageStream.listen((message) {
      _addLog('[VOICE] $message');
    });

    // Listen to voice command results
    _voiceService.commandResultStream.listen((commands) {
      if (!mounted) return;
      _applyVoiceCommand(commands);
    });
  }

  @override
  void dispose() {
    _steeringTicker.dispose();
    _indicatorAudioPlayer.dispose();
    _socketService.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _playIndicatorSound() async {
    if (_isIndicatorSoundPlaying) return;
    _isIndicatorSoundPlaying = true;
    await _indicatorAudioPlayer.play(AssetSource('blinker.mp3'), volume: 1.0);
  }

  Future<void> _stopIndicatorSound() async {
    if (!_isIndicatorSoundPlaying) return;
    _isIndicatorSoundPlaying = false;
    await _indicatorAudioPlayer.stop();
  }

  void _updateIndicatorSound() {
    if (_hazardsOn ||
        _socketService.indicatorLeft ||
        _socketService.indicatorRight) {
      _playIndicatorSound();
    } else {
      _stopIndicatorSound();
    }
  }

  void _setIndicatorStates({bool? hazards, bool? left, bool? right}) {
    setState(() {
      if (hazards != null) {
        _hazardsOn = hazards;
      }

      if (_hazardsOn) {
        _socketService.indicatorLeft = true;
        _socketService.indicatorRight = true;
      } else {
        if (left != null) {
          _socketService.indicatorLeft = left;
        }
        if (right != null) {
          _socketService.indicatorRight = right;
        }
        if (hazards == false && left == null && right == null) {
          _socketService.indicatorLeft = false;
          _socketService.indicatorRight = false;
        }
      }
    });
    _updateIndicatorSound();
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      if (_logs.length > 50) _logs.removeAt(0);
      final now = DateTime.now();
      final time =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      _logs.add("[$time] $msg");
    });
  }

  void _handleSteeringTick(Duration elapsed) {
    final nextSteering = _steering + (_targetSteering - _steering) * 0.35;
    if ((nextSteering - _steering).abs() > 0.001) {
      setState(() {
        _steering = nextSteering;
        _updateDriveData();
      });
    } else if (_steering != _targetSteering) {
      setState(() {
        _steering = _targetSteering;
        _updateDriveData();
      });
      _steeringTicker.stop();
    } else {
      _steeringTicker.stop();
    }
  }

  Future<void> _handleVoiceCommand() async {
    try {
      await _voiceService.startListening();
    } catch (e) {
      _addLog('[VOICE] Error: $e');
    }
  }

  Future<void> _showApiUrlDialog() async {
    final controller = TextEditingController(text: _socketService.apiUrl);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Socket API URL'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'API URL',
                hintText: 'http://192.168.10.159:3000',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the socket API URL';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                final updatedUrl = controller.text.trim();
                setState(() {
                  _socketService.updateApiUrl(updatedUrl);
                });
                _addLog('[SYSTEM] Updated API URL to $updatedUrl');
                Navigator.of(context).pop();
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLogsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Logs'),
          content: SizedBox(
            width: double.maxFinite,
            child: Scrollbar(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _logs.length,
                reverse: true,
                itemBuilder: (context, index) {
                  final logMsg = _logs[_logs.length - 1 - index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      logMsg,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  void _applyVoiceCommand(Map<String, bool> commands) {
    setState(() {
      if (commands.containsKey('headlights')) {
        _socketService.headLight = commands['headlights']!;
        _addLog('CMD: HEADLIGHTS_${commands['headlights']! ? 'ON' : 'OFF'}');
      }

      if (commands.containsKey('foglights')) {
        _socketService.fogLight = commands['foglights']!;
        _addLog('CMD: FOGLIGHTS_${commands['foglights']! ? 'ON' : 'OFF'}');
      }

      if (commands.containsKey('left_indicator')) {
        _socketService.indicatorLeft = commands['left_indicator']!;
        _addLog('CMD: LEFT_IND_${commands['left_indicator']! ? 'ON' : 'OFF'}');
        _updateIndicatorSound();
      }

      if (commands.containsKey('right_indicator')) {
        _socketService.indicatorRight = commands['right_indicator']!;
        _addLog(
          'CMD: RIGHT_IND_${commands['right_indicator']! ? 'ON' : 'OFF'}',
        );
        _updateIndicatorSound();
      }

      // Check if both indicators are on (hazards)
      if (_socketService.indicatorLeft && _socketService.indicatorRight) {
        _hazardsOn = true;
      } else if (commands.containsKey('left_indicator') &&
          commands.containsKey('right_indicator') &&
          !commands['left_indicator']! &&
          !commands['right_indicator']!) {
        _hazardsOn = false;
      }
    });
  }

  void _updateDriveData({double? steeringValue}) {
    final steeringInput = steeringValue ?? _steering;
    // Smooth the actual physics steering input and limit sharp turns at speed.
    final speedLimitFactor = 1.0 - (_speed / 120).clamp(0.0, 0.4);
    final effectiveSteering = steeringInput * speedLimitFactor;

    // Map steering from -1.0...1.0 to 20...75 (center at 50)
    // Left: -30 offset (20), Right: +25 offset (75)
    int steerInt;
    if (effectiveSteering < 0) {
      steerInt = (50 + (effectiveSteering * 30)).round().clamp(20, 50);
    } else {
      steerInt = (50 + (effectiveSteering * 25)).round().clamp(50, 75);
    }

    int throttleInt;
    if (_transmission == 'D' || _transmission == 'R') {
      throttleInt =
          inGearStartValue + (_accelerator * (255 - inGearStartValue)).round();
    } else {
      throttleInt = (_accelerator * 255).round();
    }
    throttleInt = throttleInt.clamp(0, 255);

    bool in1 = false;
    bool in2 = false;

    if (_transmission == 'D') {
      in1 = true;
      in2 = false;
    } else if (_transmission == 'R') {
      in1 = false;
      in2 = true;
    }

    setState(() {
      _socketService.steering = steerInt;
      _socketService.throttle = throttleInt;
      _socketService.motorIn1 = in1;
      _socketService.motorIn2 = in2;
    });
  }

  /// Automatically switch camera based on gear selection
  /// R gear -> Front camera (user)
  /// D gear (from R) -> Rear camera (environment)
  /// Only triggers if WebRTC video feed is already initialized
  void _handleAutoCameraSwitch(String newGear) {
    if (!_isWebRTCConnected) {
      // Camera not initialized, don't auto-switch
      return;
    }

    // Switch to front camera when shifting to Reverse
    if (newGear == 'R' && _previousTransmission != 'R') {
      _socketService.requestCameraSwitch(mode: 'user');
      _addLog('[AUTO] Camera switched to FRONT (Reverse gear)');
    }
    // Switch back to rear camera when shifting to Drive from Reverse
    else if (newGear == 'D' && _previousTransmission == 'R') {
      _socketService.requestCameraSwitch(mode: 'environment');
      _addLog('[AUTO] Camera switched to REAR (Drive gear)');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient Fill
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center, // Light starts behind the car
                  radius: 1.2, // How far the light reaches
                  colors: [
                    Color(0xFF323539), // Bright center
                    Colors.black, // Dark edges
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Layer 1: WEBRTC Video Stream
          VideoFeedLayer(
            renderer: _socketService.webRTC.remoteRenderer,
            onConnectPressed: () {
              _socketService.webRTC.startOffer();
            },
            onDisconnectPressed: () {
              _socketService.stopWebRTC();
            },
            connectionStream: _socketService.webRTC.connectionStateStream,
            isLandscapeMode: _isLandscapeMode,
            onToggleViewMode: () {
              setState(() {
                _isLandscapeMode = !_isLandscapeMode;
              });
            },
            brakeLightOn: _isBraking,
          ),

          // Layer 2: Top HUD
          Align(
            alignment: Alignment.topCenter,
            child: StreamBuilder<bool>(
              stream: _socketService.connectionStream,
              initialData: _socketService.isConnected,
              builder: (context, snapshot) {
                return HudLayer(
                  speed: _speed,
                  rpm: _rpm,
                  battery: _battery,
                  batteryPercent: _batteryPercent,
                  transmission: _transmission,
                  headlightsOn: _socketService.headLight,
                  highBeamOn: _socketService.highBeam,
                  fogLightOn: _socketService.fogLight,
                  reverseLightOn: _socketService.reverseLight,
                  hazardsOn: _hazardsOn,
                  leftIndicatorOn: _socketService.indicatorLeft,
                  rightIndicatorOn: _socketService.indicatorRight,
                  isConnected: snapshot.data ?? false,
                );
              },
            ),
          ),

          // Settings
          Positioned(
            top: screenHeight * 0.024,
            left: screenWidth * 0.011,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: screenHeight * 0.12,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.004,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        color: Colors.white54,
                        onPressed: _showApiUrlDialog,
                        icon: const Icon(Icons.settings),
                      ),
                      SizedBox(width: screenWidth * 0.002),
                      IconButton(
                        color: Colors.white54,
                        onPressed: _showLogsDialog,
                        icon: const Icon(Icons.list),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: screenHeight * 0.024,
            right: screenWidth * 0.011,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(screenHeight * 0.024),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.011,
                    vertical: screenHeight * 0.019,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AuxiliaryToggleButton(
                        label: 'LOW',
                        icon: Icons.light_mode,
                        onPressed: () {
                          setState(() {
                            _socketService.headLight =
                                !_socketService.headLight;
                            _socketService.highBeam = false;
                          });
                          _addLog(
                            "CMD: HEAD_${_socketService.headLight ? 'ON' : 'OFF'}",
                          );
                        },
                        isActive: _socketService.headLight,
                      ),
                      const SizedBox(width: 8),
                      AuxiliaryToggleButton(
                        label: 'HIGH',
                        icon: Icons.high_quality,
                        onPressed: () {
                          setState(() {
                            final newHighBeam = !_socketService.highBeam;
                            _socketService.highBeam = newHighBeam;
                            if (newHighBeam) _socketService.headLight = true;
                          });
                          _addLog(
                            "CMD: HIGH_BEAM_${_socketService.highBeam ? 'ON' : 'OFF'}",
                          );
                        },
                        isActive: _socketService.highBeam,
                      ),
                      const SizedBox(width: 8),
                      AuxiliaryToggleButton(
                        label: 'FOG',
                        icon: Icons.wb_twilight,
                        onPressed: () {
                          setState(() {
                            _socketService.fogLight = !_socketService.fogLight;
                          });
                          _addLog(
                            "CMD: FOG_${_socketService.fogLight ? 'ON' : 'OFF'}",
                          );
                        },
                        isActive: _socketService.fogLight,
                        activeColor: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Layer 6: Auxiliary Controls (Toggle Grid on top right)
          AuxiliaryControlsLayer(
            connectionStream: _socketService.webRTC.connectionStateStream,
            onConnectPressed: () {
              _socketService.webRTC.startOffer();
            },
            onDisconnectPressed: () {
              _socketService.stopWebRTC();
            },
            onToggleViewMode: () {
              setState(() {
                _isLandscapeMode = !_isLandscapeMode;
              });
            },
            isLandscapeMode: _isLandscapeMode,
            onReverseLightPressed: () {
              setState(() {
                _socketService.reverseLight = !_socketService.reverseLight;
              });
              _addLog("CMD: REV_${_socketService.reverseLight ? 'ON' : 'OFF'}");
            },
            onLeftIndicatorPressed: () {
              if (_hazardsOn) return;
              final newLeft = !_socketService.indicatorLeft;
              _setIndicatorStates(left: newLeft, right: false);
              _addLog("CMD: INDICATOR_LEFT_${newLeft ? 'ON' : 'OFF'}");
            },
            onHazardPressed: () {
              final hazardsOn = !_hazardsOn;
              _setIndicatorStates(hazards: hazardsOn);
              _addLog("CMD: HAZARD_${hazardsOn ? 'ON' : 'OFF'}");
            },
            onRightIndicatorPressed: () {
              if (_hazardsOn) return;
              final newRight = !_socketService.indicatorRight;
              _setIndicatorStates(left: false, right: newRight);
              _addLog("CMD: INDICATOR_RIGHT_${newRight ? 'ON' : 'OFF'}");
            },
            hazardsOn: _hazardsOn,
            leftIndicatorOn: _socketService.indicatorLeft && !_hazardsOn,
            rightIndicatorOn: _socketService.indicatorRight && !_hazardsOn,

            voiceState: _voiceState,
            onVoicePressed: _handleVoiceCommand,
          ),

          // Layer 3: Left Controls
          LeftControlsLayer(
            onSteeringChanged: (val) {
              setState(() {
                _targetSteering = val;
                if (!_steeringTicker.isActive) {
                  _steeringTicker.start();
                }
              });
              _updateDriveData(steeringValue: val);
              if (val.abs() > 0.05) {
                if (_logs.length % 5 == 0) {
                  _addLog("CMD: STEER_${val.toStringAsFixed(2)}");
                }
              }
            },
            onHornChanged: (val) {
              setState(() => _socketService.horn = val);
              _socketService.sendDirect(horn: val);
              _addLog("CMD: HORN_${val ? 'ON' : 'OFF'}");
            },
            onLeftIndicatorPressed: () {
              if (_hazardsOn) return;
              final newLeft = !_socketService.indicatorLeft;
              _setIndicatorStates(left: newLeft, right: false);
              _addLog("CMD: INDICATOR_LEFT_${newLeft ? 'ON' : 'OFF'}");
            },
            onHazardPressed: () {
              final hazardsOn = !_hazardsOn;
              _setIndicatorStates(hazards: hazardsOn);
              _addLog("CMD: HAZARD_${hazardsOn ? 'ON' : 'OFF'}");
            },
            onRightIndicatorPressed: () {
              if (_hazardsOn) return;
              final newRight = !_socketService.indicatorRight;
              _setIndicatorStates(left: false, right: newRight);
              _addLog("CMD: INDICATOR_RIGHT_${newRight ? 'ON' : 'OFF'}");
            },
            onHighBeamChanged: (isPressed) {
              setState(() {
                if (isPressed) {
                  _headlightWasOnBeforeDipper = _socketService.highBeam;
                  if (!_socketService.highBeam) {
                    _socketService.highBeam = true;
                  }
                  _socketService.highBeamMomentary = true;
                } else {
                  _socketService.highBeamMomentary = false;
                  if (!_headlightWasOnBeforeDipper) {
                    _socketService.highBeam = false;
                  }
                }
              });
              _addLog("CMD: HIGH_BEAM_${isPressed ? 'FLASH_ON' : 'FLASH_OFF'}");
            },
            hazardsOn: _hazardsOn,
            leftIndicatorOn: _socketService.indicatorLeft && !_hazardsOn,
            rightIndicatorOn: _socketService.indicatorRight && !_hazardsOn,
            highBeamOn:
                _socketService.highBeam || _socketService.highBeamMomentary,
          ),

          // Logs
          Positioned(
            top: screenHeight * 0.194,
            right: screenWidth * 0.011,
            child: Container(
              width: screenWidth * 0.25,
              height: screenHeight * 0.29,
              padding: EdgeInsets.all(screenWidth * 0.015),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: const ScrollBehavior().copyWith(
                        scrollbars: false,
                      ),
                      child: ListView.builder(
                        itemCount: _logs.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final logMsg = _logs[_logs.length - 1 - index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: screenHeight * 0.015,
                            ),
                            child: Text(
                              logMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white.withOpacity(0.75),
                                fontSize: screenHeight * 0.019,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Layer 4: Right Controls
          RightControlsLayer(
            transmission: _transmission,
            onTransmissionChanged: (val) {
              setState(() {
                _previousTransmission = _transmission;
                _transmission = val;
                _updateDriveData();
              });
              _addLog("CMD: SHIFT_$val");
              _handleAutoCameraSwitch(val);
            },
            accelerator: _accelerator,
            onAcceleratorChanged: (val) {
              setState(() {
                _accelerator = val;
                _updateDriveData();
              });
              if (val > 0.05) {
                if (_logs.length % 5 == 0) {
                  _addLog("CMD: ACCEL_${val.toStringAsFixed(2)}");
                }
              }
            },
            isBraking: _isBraking,
            onBrakeChanged: (isDown) {
              setState(() {
                _isBraking = isDown;
                _socketService.brakeLight =
                    isDown; // Brake triggers brake light
                _updateDriveData();
              });
              if (isDown) _addLog("CMD: BRAKE_PRESSED");
            },
          ),
        ],
      ),
    );
  }
}
