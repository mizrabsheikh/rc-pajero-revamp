import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';
import '../debug_config.dart';

/// Real WebRTC implementation.
///
/// When [kDisableWebRTC] is true, all methods are no-ops and the
/// flutter_webrtc renderer / peer connection are never initialised —
/// camera permission is not requested and the native WebRTC engine
/// stays dormant, which removes the runtime initialisation overhead.
///
/// ⚠️ The flutter_webrtc import is still parsed by the Dart compiler
/// (it's in pubspec.yaml), so the native .so is still linked into the APK.
/// The benefit here is purely runtime: no camera, no peer connection,
/// no ICE negotiation — which keeps the app snappy during development.
/// To skip linking entirely you would need to remove the package from
/// pubspec.yaml; use this flag for day-to-day development speedup only.
class WebRTCService {
  // ── Singleton ─────────────────────────────────────────────
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  // ── WebRTC Components ─────────────────────────────────────
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCRtpSender? _videoSender;
  String _currentFacingMode = 'environment';
  bool _isSwitchingCamera = false;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();

  Future<void> init() async {
    if (kDisableWebRTC) {
      debugPrint(
        '[WebRTCService] DISABLED – skipping init (kDisableWebRTC=true)',
      );
      return;
    }
    await localRenderer.initialize();
  }

  Future<void> handleSignal(dynamic data) async {
    if (kDisableWebRTC) {
      debugPrint(
        '[WebRTCService] DISABLED – signal ignored (kDisableWebRTC=true)',
      );
      return;
    }

    debugPrint('[WebRTCService] SIGNAL RECEIVED: $data');
    if (data is! Map) {
      debugPrint(
        '[WebRTCService] Signal ignored: Data is not a Map (Type: ${data.runtimeType})',
      );
      return;
    }

    // Extract the actual signal data (might be nested under 'data' property)
    final wrappedData = Map<String, dynamic>.from(data);
    final signalData = wrappedData.containsKey('data')
        ? Map<String, dynamic>.from(wrappedData['data'])
        : wrappedData;

    final type = signalData['type'];
    debugPrint('[WebRTCService] Signal type: $type');

    if (type == 'offer') {
      debugPrint('[WebRTCService] Processing SDP Offer...');
      await _handleOffer(signalData);
    } else if (type == 'candidate' || signalData.containsKey('candidate')) {
      debugPrint('[WebRTCService] Processing ICE Candidate...');
      await _handleCandidate(signalData);
    } else {
      debugPrint('[WebRTCService] Unknown signal type: $type');
    }
  }

  Future<void> _handleOffer(Map<dynamic, dynamic> data) async {
    await dispose();

    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'rtcAudioOptions': {'echoCancellation': false, 'noiseSuppression': false},
    });

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      debugPrint('[WebRTCService] Generated ICE candidate');
      if (candidate.candidate != null) {
        SocketService().emitControl('signal', {
          'data': {
            'type': 'candidate',
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    try {
      debugPrint('[WebRTCService] Setting remote description...');
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );

      debugPrint('[WebRTCService] Requesting camera access...');
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 480},
          'height': {'ideal': 854},
          'frameRate': {'ideal': 60, 'min': 30},
          'latency': 0,
          'aspectRatio': 0.56,
          'advanced': [
            {'focusMode': 'manual'},
            {'focusDistance': 0.0},
          ],
        },
      });

      debugPrint('[WebRTCService] Camera stream acquired successfully');
      _localStream = stream;

      // Apply additional constraints to disable autofocus
      final videoTrack = stream.getVideoTracks().first;
      try {
        await videoTrack.applyConstraints({
          'advanced': [
            {'focusMode': 'manual'},
            {'torch': false},
          ],
        });
        debugPrint('[WebRTCService] Manual focus mode applied');
      } catch (e) {
        debugPrint('[WebRTCService] Could not apply manual focus: $e');
      }

      localRenderer.srcObject = _localStream;

      debugPrint('[WebRTCService] Adding tracks to peer connection...');
      for (var track in stream.getTracks()) {
        final sender = await _peerConnection!.addTrack(track, stream);
        if (track.kind == 'video') {
          _videoSender = sender;
        }
      }

      debugPrint('[WebRTCService] Creating answer...');
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      debugPrint('[WebRTCService] Sending answer to server...');
      SocketService().emitControl('signal', {
        'data': {'type': answer.type, 'sdp': answer.sdp},
      });
      debugPrint('[WebRTCService] Answer sent successfully');
    } catch (e) {
      debugPrint('[WebRTCService] Error processing offer: $e');
    }
  }

  Future<void> switchCamera({String? desiredFacingMode}) async {
    debugPrint('[WebRTCService] ========================================');
    debugPrint('[WebRTCService] switchCamera called!');
    debugPrint('[WebRTCService] Desired facing mode: $desiredFacingMode');
    debugPrint('[WebRTCService] kDisableWebRTC: $kDisableWebRTC');
    debugPrint('[WebRTCService] _isSwitchingCamera: $_isSwitchingCamera');
    debugPrint(
      '[WebRTCService] _peerConnection: ${_peerConnection != null ? "NOT NULL" : "NULL"}',
    );
    debugPrint(
      '[WebRTCService] _localStream: ${_localStream != null ? "NOT NULL" : "NULL"}',
    );
    debugPrint('[WebRTCService] _currentFacingMode: $_currentFacingMode');

    if (kDisableWebRTC) {
      debugPrint('[WebRTCService] ABORT: WebRTC is disabled');
      return;
    }

    // Prevent concurrent camera switches
    if (_isSwitchingCamera) {
      debugPrint('[WebRTCService] ABORT: Camera switch already in progress');
      return;
    }

    if (_peerConnection == null || _localStream == null) {
      debugPrint('[WebRTCService] ABORT: No active peer connection or stream');
      debugPrint(
        '[WebRTCService] _peerConnection is null: ${_peerConnection == null}',
      );
      debugPrint(
        '[WebRTCService] _localStream is null: ${_localStream == null}',
      );
      return;
    }

    final newFacingMode =
        desiredFacingMode?.toLowerCase() == 'user' ||
            desiredFacingMode?.toLowerCase() == 'environment'
        ? desiredFacingMode!.toLowerCase()
        : (_currentFacingMode == 'environment' ? 'user' : 'environment');

    if (newFacingMode == _currentFacingMode) {
      debugPrint('[WebRTCService] Camera already using $newFacingMode mode');
      return;
    }

    _isSwitchingCamera = true;
    debugPrint('[WebRTCService] Switching camera to $newFacingMode');

    // Store references to old stream for cleanup
    final oldStream = _localStream;
    final oldFacingMode = _currentFacingMode;

    try {
      // CRITICAL: Stop and dispose old camera BEFORE requesting new one
      // This is essential on Android to properly release camera resources
      debugPrint('[WebRTCService] Stopping old camera tracks...');
      oldStream?.getTracks().forEach((track) {
        try {
          track.stop();
          debugPrint('[WebRTCService] Stopped track: ${track.kind}');
        } catch (e) {
          debugPrint('[WebRTCService] Error stopping track: $e');
        }
      });

      try {
        await oldStream?.dispose();
        debugPrint('[WebRTCService] Old stream disposed');
      } catch (e) {
        debugPrint('[WebRTCService] Error disposing old stream: $e');
      }

      // Give Android time to release camera resources
      debugPrint('[WebRTCService] Waiting for camera resource cleanup...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Now request the new camera
      debugPrint('[WebRTCService] Requesting new camera: $newFacingMode');
      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': newFacingMode,
          'width': {'ideal': 480},
          'height': {'ideal': 854},
          'frameRate': {'ideal': 60, 'min': 30},
          'latency': 0,
          'aspectRatio': 0.56,
          'advanced': [
            {'focusMode': 'manual'},
            {'focusDistance': 0.0},
          ],
        },
      });

      final newVideoTrack = newStream.getVideoTracks().first;
      debugPrint('[WebRTCService] New camera stream acquired');

      // Apply manual focus constraints
      try {
        await newVideoTrack.applyConstraints({
          'advanced': [
            {'focusMode': 'manual'},
            {'torch': false},
          ],
        });
        debugPrint('[WebRTCService] Manual focus mode applied');
      } catch (e) {
        debugPrint('[WebRTCService] Could not apply manual focus: $e');
      }

      // Replace the video track in the peer connection
      if (_videoSender != null) {
        debugPrint('[WebRTCService] Replacing video track in sender...');
        await _videoSender!.replaceTrack(newVideoTrack);
        debugPrint('[WebRTCService] Video track replaced successfully');
      } else {
        debugPrint('[WebRTCService] No video sender found, adding new track');
        final sender = await _peerConnection!.addTrack(
          newVideoTrack,
          newStream,
        );
        _videoSender = sender;
      }

      // Update the renderer with new stream
      localRenderer.srcObject = newStream;

      // Update state
      _localStream = newStream;
      _currentFacingMode = newFacingMode;

      debugPrint(
        '[WebRTCService] Camera switch completed successfully to $newFacingMode',
      );
      debugPrint('[WebRTCService] ========================================');
    } catch (e, stackTrace) {
      debugPrint('[WebRTCService] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
      debugPrint('[WebRTCService] Camera switch FAILED: $e');
      debugPrint('[WebRTCService] Stack trace: $stackTrace');

      // Attempt to recover by getting the old camera back
      debugPrint('[WebRTCService] Attempting to recover previous camera...');
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        final recoveryStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': {
            'facingMode': oldFacingMode,
            'width': {'ideal': 480},
            'height': {'ideal': 854},
            'frameRate': {'ideal': 60, 'min': 30},
            'latency': 0,
            'aspectRatio': 0.56,
            'advanced': [
              {'focusMode': 'manual'},
              {'focusDistance': 0.0},
            ],
          },
        });

        final recoveryTrack = recoveryStream.getVideoTracks().first;
        if (_videoSender != null) {
          await _videoSender!.replaceTrack(recoveryTrack);
        } else {
          final sender = await _peerConnection!.addTrack(
            recoveryTrack,
            recoveryStream,
          );
          _videoSender = sender;
        }

        localRenderer.srcObject = recoveryStream;
        _localStream = recoveryStream;
        _currentFacingMode = oldFacingMode;

        debugPrint(
          '[WebRTCService] Successfully recovered to $oldFacingMode camera',
        );
      } catch (recoveryError) {
        debugPrint('[WebRTCService] Recovery FAILED: $recoveryError');
        debugPrint('[WebRTCService] Camera may be in unusable state!');
      }

      debugPrint('[WebRTCService] !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
    } finally {
      _isSwitchingCamera = false;
    }
  }

  Future<void> _handleCandidate(Map<dynamic, dynamic> data) async {
    if (_peerConnection == null) {
      debugPrint('[WebRTCService] Cannot add candidate - no peer connection');
      return;
    }
    try {
      debugPrint('[WebRTCService] Adding ICE candidate...');
      await _peerConnection!.addCandidate(
        RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ),
      );
      debugPrint('[WebRTCService] ICE candidate added successfully');
    } catch (e) {
      debugPrint('[WebRTCService] Error adding candidate: $e');
    }
  }

  Future<void> dispose() async {
    if (kDisableWebRTC) return;

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        try {
          track.stop();
        } catch (e) {
          debugPrint('Error stopping track: $e');
        }
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    localRenderer.srcObject = null;

    if (_peerConnection != null) {
      await _peerConnection!.close();
      await _peerConnection!.dispose();
      _peerConnection = null;
    }
  }
}
