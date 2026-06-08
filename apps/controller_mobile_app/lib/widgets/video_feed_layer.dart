import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'car_model.dart';

class VideoFeedLayer extends StatefulWidget {
  final RTCVideoRenderer renderer;
  final VoidCallback onConnectPressed;
  final VoidCallback onDisconnectPressed;
  final Stream<RTCPeerConnectionState> connectionStream;
  final bool brakeLightOn;
  final bool isLandscapeMode;
  final VoidCallback onToggleViewMode;

  const VideoFeedLayer({
    super.key,
    required this.renderer,
    required this.onConnectPressed,
    required this.onDisconnectPressed,
    required this.connectionStream,
    required this.isLandscapeMode,
    required this.onToggleViewMode,
    this.brakeLightOn = false,
  });

  @override
  State<VideoFeedLayer> createState() => _VideoFeedLayerState();
}

class _VideoFeedLayerState extends State<VideoFeedLayer> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          heightFactor: 1.0,
          child: Transform.translate(
            offset: Offset(0, 160),
            child: Transform.scale(
              scale: widget.isLandscapeMode ? 0.6 : 1.1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: RTCVideoView(
                  widget.renderer,
                  objectFit: widget.isLandscapeMode
                      ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover
                      : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                ),
              ),
            ),
          ),
        ),
        StreamBuilder<RTCPeerConnectionState>(
          stream: widget.connectionStream,
          initialData: RTCPeerConnectionState.RTCPeerConnectionStateClosed,
          builder: (context, snapshot) {
            final state = snapshot.data;
            final isConnected =
                state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

            if (isConnected) {
              return const SizedBox.shrink();
            }

            return CarModel(brakeLightOn: widget.brakeLightOn);
          },
        ),
      ],
    );
  }
}
