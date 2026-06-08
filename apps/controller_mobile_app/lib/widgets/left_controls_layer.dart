import 'package:controller_mobile_app/widgets/control_circle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'steering_wheel_control.dart';
import 'mini_map_widget.dart';

class LeftControlsLayer extends StatelessWidget {
  const LeftControlsLayer({
    super.key,
    required this.onSteeringChanged,
    required this.onHighBeamChanged,
    required this.onHornChanged,
    required this.onLeftIndicatorPressed,
    required this.onHazardPressed,
    required this.onRightIndicatorPressed,
    required this.hazardsOn,
    required this.leftIndicatorOn,
    required this.rightIndicatorOn,
    required this.highBeamOn,
  });

  final ValueChanged<double> onSteeringChanged;
  final ValueChanged<bool> onHornChanged;
  final ValueChanged<bool> onHighBeamChanged;
  final VoidCallback onLeftIndicatorPressed;
  final VoidCallback onHazardPressed;
  final VoidCallback onRightIndicatorPressed;
  final bool hazardsOn;
  final bool leftIndicatorOn;
  final bool rightIndicatorOn;
  final bool highBeamOn;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Positioned(
      bottom: screenHeight * 0.024,
      left: screenWidth * 0.011,
      child: ClipRRect(
        // borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: screenWidth * 0.3,

          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini Map
              MiniMapWidget(
                width: screenWidth * 0.26,
                height: screenHeight * 0.36,
              ),
              // _buildDipperButton(),
              SizedBox(height: screenHeight * 0.029),
              ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.4),
                  BlendMode.srcATop,
                ),
                child: Row(
                  children: [
                    SteeringWheelControl(
                      onChanged: onSteeringChanged,
                      onHornChanged: onHornChanged,
                      wheelSize: screenHeight * 0.33,
                    ),
                    SizedBox(width: screenWidth * 0.011),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.002,
                        vertical: screenHeight * 0.01,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white10, width: 0.5),
                      ),
                      child: Column(
                        spacing: screenHeight * 0.009,
                        children: [
                          ControlCircleButton(
                            onTap: onLeftIndicatorPressed,
                            isActive: leftIndicatorOn,
                            activeColor: Colors.amber,
                            child: Padding(
                              padding: EdgeInsets.all(screenWidth * 0.01),
                              child: RotatedBox(
                                quarterTurns: 2,
                                child: SvgPicture.asset(
                                  'assets/right-blinker.svg',
                                  colorFilter: ColorFilter.mode(
                                    leftIndicatorOn
                                        ? Colors.green
                                        : Colors.white10,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ControlCircleButton(
                            onTap: onRightIndicatorPressed,
                            isActive: rightIndicatorOn,
                            activeColor: Colors.amber,
                            child: Padding(
                              padding: EdgeInsets.all(screenWidth * 0.01),
                              child: SvgPicture.asset(
                                'assets/right-blinker.svg',
                                colorFilter: ColorFilter.mode(
                                  rightIndicatorOn
                                      ? Colors.green
                                      : Colors.white10,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          ControlCircleButton(
                            onTap: onHazardPressed,
                            isActive: hazardsOn,
                            activeColor: Colors.redAccent,
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 20,
                              color: hazardsOn
                                  ? Colors.redAccent
                                  : Colors.white24,
                            ),
                          ),
                          ControlCircleButton(
                            onTapDown: (_) => onHighBeamChanged(true),
                            onTapUp: (_) => onHighBeamChanged(false),
                            onTapCancel: () => onHighBeamChanged(false),
                            isActive: highBeamOn,
                            activeColor: Colors.blue,
                            child: Padding(
                              padding: EdgeInsets.all(screenWidth * 0.01),
                              child: SvgPicture.asset(
                                'assets/high-beam.svg',
                                colorFilter: ColorFilter.mode(
                                  highBeamOn ? Colors.blue : Colors.white10,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
