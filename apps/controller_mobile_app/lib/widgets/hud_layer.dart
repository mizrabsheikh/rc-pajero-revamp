import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HudLayer extends StatefulWidget {
  final double speed;
  final int rpm;
  final double battery;
  final int batteryPercent;
  final String transmission;
  final bool headlightsOn;
  final bool highBeamOn;
  final bool fogLightOn;
  final bool reverseLightOn;
  final bool hazardsOn;
  final bool leftIndicatorOn;
  final bool rightIndicatorOn;
  final bool isConnected;

  const HudLayer({
    super.key,
    required this.speed,
    required this.rpm,
    required this.battery,
    required this.batteryPercent,
    required this.transmission,
    required this.headlightsOn,
    required this.highBeamOn,
    required this.fogLightOn,
    required this.reverseLightOn,
    required this.hazardsOn,
    required this.leftIndicatorOn,
    required this.rightIndicatorOn,
    required this.isConnected,
  });

  @override
  State<HudLayer> createState() => _HudLayerState();
}

class _HudLayerState extends State<HudLayer> {
  bool _blinkVisible = true;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _startBlinking();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _startBlinking() {
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 370), (timer) {
      if (mounted) {
        setState(() {
          _blinkVisible = !_blinkVisible;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine if left/right indicators should be showing based on state and blink cycle
    final showLeft =
        (widget.hazardsOn || widget.leftIndicatorOn) && _blinkVisible;
    final showRight =
        (widget.hazardsOn || widget.rightIndicatorOn) && _blinkVisible;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.only(top: screenHeight * 0.024),
      height: screenHeight * 0.10,
      width: MediaQuery.of(context).size.width * 0.55,
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.014),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left cluster (Battery, Transmission, Engine)
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/engine.svg',
                  width: screenHeight * 0.036,
                  height: screenHeight * 0.036,
                  color: widget.battery >= 11.1
                      ? const Color(0xFFB2FF05)
                      : widget.battery >= 9.9
                      ? Colors.orangeAccent
                      : widget.battery >= 9.0
                      ? Colors.orange
                      : Colors.redAccent,
                ),

                SizedBox(width: screenWidth * 0.008),
                Text(
                  "${widget.battery.toStringAsFixed(1)}v",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenHeight * 0.026,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: screenWidth * 0.007),
                Icon(Icons.phone_android_rounded, size: screenHeight * 0.032),
                SizedBox(width: screenWidth * 0.003),
                Text(
                  "${widget.batteryPercent}%",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: screenHeight * 0.026,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: screenWidth * 0.014),
                Text(
                  widget.transmission,
                  style: TextStyle(
                    fontSize: screenHeight * 0.036,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                // SizedBox(width: screenWidth * 0.014),
                // Text(
                //   "${widget.rpm}  RPM",
                //   style: TextStyle(
                //     color: Colors.white54,
                //     fontSize: screenHeight * 0.020,
                //     fontWeight: FontWeight.w600,
                //   ),
                // ),
              ],
            ),
          ),

          // Center cluster (Speedometer and RPM)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                (widget.speed * 3.6).toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenHeight * 0.044,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              SizedBox(width: screenWidth * 0.007),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "km/h",
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: screenHeight * 0.020,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right cluster (Turn signals, Hazard, Lights, Horn, Connectivity)
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RotatedBox(
                  quarterTurns: 2,
                  child: SvgPicture.asset(
                    'assets/right-blinker.svg',
                    width: screenHeight * 0.036,
                    height: screenHeight * 0.036,

                    colorFilter: ColorFilter.mode(
                      showLeft ? Colors.green : Colors.white10,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.010),

                SvgPicture.asset(
                  'assets/right-blinker.svg',
                  width: screenHeight * 0.036,
                  height: screenHeight * 0.036,

                  colorFilter: ColorFilter.mode(
                    showRight ? Colors.green : Colors.white10,
                    BlendMode.srcIn,
                  ),
                ),
                SizedBox(width: screenWidth * 0.010),

                SvgPicture.asset(
                  'assets/fog-light.svg',
                  width: screenHeight * 0.036,
                  height: screenHeight * 0.036,
                  colorFilter: ColorFilter.mode(
                    widget.fogLightOn ? Colors.orange : Colors.white10,
                    BlendMode.srcIn,
                  ),
                ),
                SizedBox(width: screenWidth * 0.007),
                SvgPicture.asset(
                  'assets/low-beam.svg',
                  width: screenHeight * 0.036,
                  height: screenHeight * 0.036,
                  colorFilter: ColorFilter.mode(
                    widget.headlightsOn && !widget.highBeamOn
                        ? Colors.blue
                        : Colors.white10,
                    BlendMode.srcIn,
                  ),
                ),
                SizedBox(width: screenWidth * 0.007),
                SvgPicture.asset(
                  'assets/high-beam.svg',
                  width: screenHeight * 0.036,
                  height: screenHeight * 0.036,
                  colorFilter: ColorFilter.mode(
                    widget.highBeamOn ? Colors.blue : Colors.white10,
                    BlendMode.srcIn,
                  ),
                ),
                SizedBox(width: screenWidth * 0.007),
                Icon(
                  Icons.wifi,
                  color: widget.isConnected
                      ? const Color(0xFF00E5FF)
                      : Colors.white.withValues(alpha: 0.2),
                  size: screenHeight * 0.032,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
