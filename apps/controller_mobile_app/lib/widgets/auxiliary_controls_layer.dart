import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../services/socket_service.dart';
import '../services/voice_command_service.dart';

class AuxiliaryControlsLayer extends StatelessWidget {
  final Stream<RTCPeerConnectionState> connectionStream;
  final VoidCallback onConnectPressed;
  final VoidCallback onDisconnectPressed;
  final VoidCallback onToggleViewMode;
  final bool isLandscapeMode;

  final VoidCallback onReverseLightPressed;
  final VoidCallback onLeftIndicatorPressed;
  final VoidCallback onHazardPressed;
  final VoidCallback onRightIndicatorPressed;
  final bool hazardsOn;
  final bool leftIndicatorOn;
  final bool rightIndicatorOn;

  final VoiceState voiceState;
  final VoidCallback onVoicePressed;

  const AuxiliaryControlsLayer({
    super.key,
    required this.connectionStream,
    required this.onConnectPressed,
    required this.onDisconnectPressed,
    required this.onToggleViewMode,
    required this.isLandscapeMode,
    required this.onReverseLightPressed,
    required this.onLeftIndicatorPressed,
    required this.onHazardPressed,
    required this.onRightIndicatorPressed,
    required this.hazardsOn,
    required this.leftIndicatorOn,
    required this.rightIndicatorOn,
    required this.voiceState,
    required this.onVoicePressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            bottom: screenHeight * 0.049,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
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
                        _buildVoiceButton(),
                        SizedBox(width: screenWidth * 0.009),
                        _buildStreamControl(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamControl() {
    return StreamBuilder<RTCPeerConnectionState>(
      stream: connectionStream,
      initialData: RTCPeerConnectionState.RTCPeerConnectionStateClosed,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final isConnected =
            state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

        if (!isConnected) {
          return _buildInitiateButton(context);
        }

        final screenWidth = MediaQuery.of(context).size.width;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildVideoControlButton(
              context: context,
              icon: Icons.cameraswitch,
              onPressed: () {
                SocketService().requestCameraSwitch();
              },
              tooltip: 'Switch camera',
            ),
            // SizedBox(width: screenWidth * 0.009),
            // _buildVideoControlButton(
            //   context: context,
            //   icon: isLandscapeMode ? Icons.zoom_in : Icons.zoom_out,
            //   onPressed: onToggleViewMode,
            //   tooltip: 'Zoom video',
            // ),
            SizedBox(width: screenWidth * 0.009),
            _buildVideoControlButton(
              context: context,
              icon: Icons.videocam_off,
              onPressed: onDisconnectPressed,
              tooltip: 'End stream',
              activeColor: Colors.redAccent,
            ),
          ],
        );
      },
    );
  }

  Widget _buildInitiateButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: onConnectPressed,
      child: Tooltip(
        message: 'Initialize video stream',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.017),
          height: screenHeight * 0.107,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white12, width: 1.0),
          ),
          child: Center(
            child: Text(
              'Initiate Video Stream',
              style: TextStyle(
                color: Colors.white,
                fontSize: screenHeight * 0.032,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoControlButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color activeColor = Colors.grey,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: screenHeight * 0.107,
          height: screenHeight * 0.107,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activeColor.withOpacity(0.18),
            border: Border.all(color: activeColor, width: 1.0),
          ),
          child: Center(
            child: Icon(icon, size: screenHeight * 0.049, color: activeColor),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    Color buttonColor;
    IconData icon;
    bool isAnimating = false;

    switch (voiceState) {
      case VoiceState.idle:
        buttonColor = Colors.white30;
        icon = Icons.mic;
        break;
      case VoiceState.listening:
        buttonColor = const Color(0xFF00E5FF);
        icon = Icons.mic;
        isAnimating = true;
        break;
      case VoiceState.processing:
        buttonColor = const Color(0xFFB2FF05);
        icon = Icons.mic;
        isAnimating = true;
        break;
      case VoiceState.error:
        buttonColor = Colors.red;
        icon = Icons.mic_off;
        break;
    }

    return Builder(
      builder: (context) {
        final screenHeight = MediaQuery.of(context).size.height;

        return GestureDetector(
          onTap:
              voiceState == VoiceState.listening ||
                  voiceState == VoiceState.processing
              ? null
              : onVoicePressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: screenHeight * 0.107,
            height: screenHeight * 0.107,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: voiceState != VoiceState.idle
                  ? buttonColor.withValues(alpha: 0.15)
                  : Colors.black26,
              border: Border.all(
                color: voiceState != VoiceState.idle
                    ? buttonColor
                    : Colors.white10,
                width: 1.0,
              ),
              boxShadow: [
                if (voiceState != VoiceState.idle)
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: isAnimating ? 2 : 1,
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isAnimating
                    ? _buildAnimatedIcon(icon, buttonColor, screenHeight)
                    : Icon(
                        icon,
                        size: screenHeight * 0.049,
                        color: voiceState != VoiceState.idle
                            ? buttonColor
                            : Colors.white24,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedIcon(IconData icon, Color color, double screenHeight) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 1.0 + (value * 0.2),
          child: Opacity(
            opacity: 1.0 - (value * 0.3),
            child: Icon(icon, size: screenHeight * 0.049, color: color),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

class AuxiliaryToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;
  final Color activeColor;
  final Widget? child;

  const AuxiliaryToggleButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor = const Color.fromRGBO(0, 229, 255, 1),
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: screenWidth * 0.044,
        height: screenHeight * 0.087,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // color: isActive ? activeColor.withOpacity(0.18) : Colors.black26,
          border: Border.all(color: Colors.white10, width: 1.0),
        ),
        child:
            child ??
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon(
                //   icon,
                //   size: 20,
                //   color: isActive ? activeColor : Colors.white24,
                // ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8,
                    color: isActive ? activeColor : Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
