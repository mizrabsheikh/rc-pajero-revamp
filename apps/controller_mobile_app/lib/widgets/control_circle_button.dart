import 'package:flutter/material.dart';

class ControlCircleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapUpCallback? onTapUp;
  final GestureTapCancelCallback? onTapCancel;
  final bool isActive;
  final Color activeColor;

  const ControlCircleButton({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.isActive = false,
    this.activeColor = const Color.fromRGBO(0, 229, 255, 1),
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: onTap,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: screenWidth * 0.044,
        height: screenHeight * 0.087,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? activeColor.withValues(alpha: 0.18)
              : Colors.black26,
          border: Border.all(color: Colors.white10, width: 1.0),
        ),
        child: Center(child: child),
      ),
    );
  }
}
