import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  io.Socket? _socket;

  final _connectionStateController =
      StreamController<RTCPeerConnectionState>.broadcast();
  Stream<RTCPeerConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  Function(String)? onLog;

  void _log(String message) {
    debugPrint("[WebRTC] $message");
    onLog?.call("[WebRTC] $message");
  }

  void _logPayload(String event, dynamic payload) {
    try {
      final jsonStr = jsonEncode(payload);
      _log("Emitting '$event' with payload: $jsonStr");
    } catch (e) {
      _log("Emitting '$event' (failed to JSON encode): $payload");
    }
  }

  Future<void> init(io.Socket socket) async {
    _socket = socket;
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _log("Renderers initialized.");

    _socket?.on('signal', (data) async {
      _log("Received SIGNAL raw: $data");
      try {
        // Backend now emits signal data directly (not wrapped)
        final signalData = data;

        if (signalData != null && signalData['type'] == 'answer') {
          _log("Processing ANSWER signal.");
          var answer = RTCSessionDescription(
            signalData['sdp'],
            signalData['type'],
          );
          await _peerConnection?.setRemoteDescription(answer);
          _log("Remote description set successfully.");
        } else if (signalData != null && signalData['candidate'] != null) {
          _log("Processing ICE Candidate signal.");
          var candidate = RTCIceCandidate(
            signalData['candidate'],
            signalData['sdpMid'],
            signalData['sdpMLineIndex'],
          );
          await _peerConnection?.addCandidate(candidate);
        } else {
          _log("Received unknown or invalid signal format: $signalData");
        }
      } catch (e) {
        _log("Error processing incoming signal: $e");
      }
    });
  }

  Future<void> startOffer() async {
    _log("Starting WebRTC Offer process");

    // Ensure previous connection is fully stopped before starting a new one
    await stopVideo();

    Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };

    try {
      _peerConnection = await createPeerConnection(configuration);
      _log("PeerConnection created.");

      _peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
        _log("Connection State Changed: ${state.name}");
        _connectionStateController.add(state);
      };

      _peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
        _log("ICE Connection State Changed: ${state.name}");
      };

      _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate != null) {
          final signalData = {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          };

          // Backend expects: { data }
          final payload = {'data': signalData};

          _logPayload('signal (candidate)', payload);
          _socket?.emit('signal', payload);
        }
      };

      _peerConnection?.onTrack = (RTCTrackEvent event) {
        _log("Received remote track: ${event.track.kind}");
        if (event.track.kind == 'video') {
          remoteRenderer.srcObject = event.streams[0];
          _log("Video stream attached to remote renderer.");
        }
      };

      _peerConnection?.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      _log("Creating Local Offer...");
      RTCSessionDescription offer = await _peerConnection!.createOffer({});

      _log("Optimizing SDP...");
      String? sdp = offer.sdp;
      if (sdp != null) {
        sdp = _optimizeSdp(sdp);
      }

      final optimizedOffer = RTCSessionDescription(sdp, offer.type);

      _log("Setting Local Description...");
      await _peerConnection!.setLocalDescription(optimizedOffer);

      final signalData = {
        'type': optimizedOffer.type,
        'sdp': optimizedOffer.sdp,
      };

      // Backend expects: { data }
      final payload = {'data': signalData};

      _logPayload('signal (offer)', payload);
      _socket?.emit('signal', payload);
    } catch (e) {
      _log("Fatal error creating PeerConnection: $e");
    }
  }

  String _optimizeSdp(String sdp) {
    _log("Optimizing SDP strings...");

    // Normalize line endings to \r\n (standard for SDP)
    sdp = sdp.replaceAll('\r\n', '\n').replaceAll('\n', '\r\n');

    // 1. Set High Bitrate (4000kbps)
    // Inject b=AS:4000 immediately after the m=video line
    final videoMediaRegExp = RegExp(r'(m=video.*\r\n)');
    if (sdp.contains(videoMediaRegExp)) {
      sdp = sdp.replaceFirstMapped(videoMediaRegExp, (match) {
        return '${match.group(1)}b=AS:4000\r\n';
      });
    } else {
      _log("WARNING: m=video line not found, cannot set bitrate.");
    }

    // 2. Remove "goog-playout-delay" extension
    sdp = sdp.replaceAll(
      RegExp(
        r'a=extmap:5 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay\r?\n',
      ),
      '',
    );

    return sdp;
  }

  Future<void> stopVideo() async {
    _log("Stopping video stream...");
    try {
      await _peerConnection?.close();
      _peerConnection = null;
      remoteRenderer.srcObject = null;
      _connectionStateController.add(
        RTCPeerConnectionState.RTCPeerConnectionStateClosed,
      );
      _log("Video stream stopped and connection closed.");
    } catch (e) {
      _log("Error during stopVideo: $e");
    }
  }

  void dispose() {
    _log("Disposing WebRTC Service...");
    stopVideo();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _connectionStateController.close();
  }
}
