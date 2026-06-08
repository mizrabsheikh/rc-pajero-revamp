import 'dart:math';
import 'package:flutter/material.dart';

class SteeringWheelControl extends StatefulWidget {
  static const double maxWheelRotation = 3 * pi / 4; // 135 degrees per side

  final double wheelSize;
  final double minRadius;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onHornChanged;

  const SteeringWheelControl({
    super.key,
    required this.onChanged,
    required this.onHornChanged,
    this.wheelSize = 160.0,
    double? minRadius,
  }) : minRadius = minRadius ?? wheelSize * 0.15;

  @override
  State<SteeringWheelControl> createState() => _SteeringWheelControlState();
}

class _SteeringWheelControlState extends State<SteeringWheelControl>
    with SingleTickerProviderStateMixin {
  double _rotation = 0.0;
  Offset? _lastVector;
  bool _dragging = false;
  bool _hornPressed = false;

  late final AnimationController _releaseController;
  late Animation<double> _releaseAnimation;

  @override
  void initState() {
    super.initState();
    _releaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(_onReleaseAnimationChanged);
    _releaseAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _releaseController, curve: Curves.easeOutQuad),
    );
  }

  @override
  void dispose() {
    _releaseController.dispose();
    super.dispose();
  }

  void _onReleaseAnimationChanged() {
    setState(() {
      _rotation = _releaseAnimation.value;
    });
    widget.onChanged(
      (_rotation / SteeringWheelControl.maxWheelRotation).clamp(-1.0, 1.0),
    );
  }

  Offset _vectorFromPosition(Offset localPosition) {
    final center = Offset(widget.wheelSize / 2, widget.wheelSize / 2);
    return localPosition - center;
  }

  void _resetToCenter() {
    if (_releaseController.isAnimating) {
      _releaseController.stop();
    }
    setState(() {
      _rotation = 0.0;
    });
    widget.onChanged(0.0);
  }

  void _onPanStart(DragStartDetails details) {
    if (_releaseController.isAnimating) {
      _releaseController.stop();
    }

    final v = _vectorFromPosition(details.localPosition);
    if (v.distance < widget.minRadius) {
      _hornPressed = true;
      widget.onHornChanged(true);
      _dragging = false;
      _lastVector = null;
      return;
    }

    _hornPressed = false;
    _dragging = true;
    _lastVector = v;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_hornPressed) return;
    if (!_dragging) return;
    final current = _vectorFromPosition(details.localPosition);
    if (current.distance < widget.minRadius) {
      _lastVector = null;
      return;
    }
    final previous = _lastVector;
    _lastVector = current;
    if (previous == null) return;

    final cross = previous.dx * current.dy - previous.dy * current.dx;
    final dot = previous.dx * current.dx + previous.dy * current.dy;
    final delta = atan2(cross, dot);

    setState(() {
      _rotation = (_rotation + delta).clamp(
        -SteeringWheelControl.maxWheelRotation,
        SteeringWheelControl.maxWheelRotation,
      );
    });

    widget.onChanged(
      (_rotation / SteeringWheelControl.maxWheelRotation).clamp(-1.0, 1.0),
    );
  }

  void _onPanEnd(DragEndDetails details) {
    if (_hornPressed) {
      _hornPressed = false;
      widget.onHornChanged(false);
      return;
    }

    _dragging = false;
    _lastVector = null;
    _resetToCenter();
  }

  void _onPanCancel() {
    if (_hornPressed) {
      _hornPressed = false;
      widget.onHornChanged(false);
      return;
    }

    _dragging = false;
    _lastVector = null;
    _resetToCenter();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: SizedBox(
        width: widget.wheelSize,
        height: widget.wheelSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: widget.wheelSize,
              height: widget.wheelSize,

              child: ClipOval(
                child: Transform.rotate(
                  angle: _rotation,
                  child: Image.asset(
                    'assets/steering-wheel.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Container(
              width: widget.wheelSize * 0.26,
              height: widget.wheelSize * 0.26,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1.5),
              ),
              child: Center(
                child: Icon(
                  Icons.circle,
                  color: Colors.white.withValues(alpha: 0.65),
                  size: widget.wheelSize * 0.0875,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
