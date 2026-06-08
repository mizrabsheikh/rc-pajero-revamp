import 'dart:ui';
import 'package:flutter/material.dart';
import 'gear_selector.dart';
import 'spring_control.dart';

class RightControlsLayer extends StatelessWidget {
  final String transmission;
  final ValueChanged<String> onTransmissionChanged;
  final double accelerator;
  final ValueChanged<double> onAcceleratorChanged;
  final bool isBraking;
  final ValueChanged<bool> onBrakeChanged;

  const RightControlsLayer({
    super.key,
    required this.transmission,
    required this.onTransmissionChanged,
    required this.accelerator,
    required this.onAcceleratorChanged,
    required this.isBraking,
    required this.onBrakeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Positioned(
      bottom: screenHeight * 0.024,
      right: screenWidth * 0.011,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Transmission selector (Vertical Gear Slider)
            GearSelector(
              value: transmission,
              onChanged: onTransmissionChanged,
              width: screenWidth * 0.061,
              height: screenHeight * 0.446,
            ),
            SizedBox(width: screenWidth * 0.013),
            // Brake Pedal (Minimalist Redesign)
            GestureDetector(
              onTapDown: (_) => onBrakeChanged(true),
              onTapUp: (_) => onBrakeChanged(false),
              onTapCancel: () => onBrakeChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: screenWidth * 0.087,
                height: screenHeight * 0.437,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isBraking
                      ? Colors.red[900]!.withValues(alpha: 0.4)
                      : Colors.black26,
                  border: Border.all(
                    color: isBraking ? Colors.redAccent : Colors.white12,
                    width: 1.0,
                  ),
                  boxShadow: [
                    if (isBraking)
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.2),
                        blurRadius: 10,
                      ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Subtle horizontal bars
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        2,
                        (_) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          width: 50,
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Text(
                      "BRAKE",
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isBraking ? Colors.white : Colors.white24,
                        fontSize: screenHeight * 0.034,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.013),

            // Accelerator Pedal (Premium SpringControl)
            SpringControl(
              value: accelerator,
              onChanged: onAcceleratorChanged,
              min: 0.0,
              max: 1.0,
              direction: Axis.vertical,
              width: screenWidth * 0.076,
              height: screenHeight * 0.437,
              thumbColor: const Color(0xFFB2FF05),
            ),
          ],
        ),
      ),
    );
  }
}
