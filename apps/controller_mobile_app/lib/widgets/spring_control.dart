import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class SpringControl extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final Axis direction;
  final ValueChanged<double> onChanged;
  final double height;
  final double width;
  final Color trackColor;
  final Color thumbColor;

  const SpringControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = -1.0,
    this.max = 1.0,
    this.direction = Axis.horizontal,
    this.height = 40,
    this.width = 200,
    this.trackColor = Colors.white10,
    this.thumbColor = Colors.white,
  });

  @override
  State<SpringControl> createState() => _SpringControlState();
}

class _SpringControlState extends State<SpringControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _controller = AnimationController.unbounded(vsync: this);
    _controller.addListener(() {
      final clamped = _controller.value.clamp(widget.min, widget.max);
      if (clamped != _currentValue) {
        setState(() => _currentValue = clamped);
        widget.onChanged(_currentValue);
      }
    });
  }

  @override
  void didUpdateWidget(SpringControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_controller.isAnimating) {
      setState(() => _currentValue = widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _runSpring(double velocity) {
    final restPoint = (widget.min < 0 && widget.max > 0) ? 0.0 : widget.min;
    final simulation = SpringSimulation(
      const SpringDescription(mass: 1.0, stiffness: 300.0, damping: 20.0),
      _currentValue,
      restPoint,
      velocity,
    );
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => _controller.stop(),
      onPanUpdate: (details) {
        final range = widget.max - widget.min;
        final totalDimension = widget.direction == Axis.horizontal
            ? widget.width
            : widget.height;
        final thumbSize = widget.direction == Axis.horizontal
            ? widget.height * 0.9
            : widget.width * 0.9;
        final activeTrack = totalDimension - thumbSize;

        if (activeTrack <= 0) return;

        final delta = widget.direction == Axis.horizontal
            ? (details.delta.dx / activeTrack) * range
            : -(details.delta.dy / activeTrack) * range;

        setState(() {
          _currentValue = (_currentValue + delta).clamp(widget.min, widget.max);
        });
        widget.onChanged(_currentValue);
      },
      onPanEnd: (details) {
        final totalDimension = widget.direction == Axis.horizontal
            ? widget.width
            : widget.height;
        final velocity = widget.direction == Axis.horizontal
            ? details.velocity.pixelsPerSecond.dx / totalDimension
            : -details.velocity.pixelsPerSecond.dy / totalDimension;
        _runSpring(velocity);
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Minimal Track Marker
            if (widget.direction == Axis.vertical) _buildMinimalTrackTexture(),

            // Neutral marker (Subtle)
            if (widget.min < 0 && widget.max > 0)
              Container(
                width: widget.direction == Axis.horizontal
                    ? 1.5
                    : widget.width * 0.4,
                height: widget.direction == Axis.vertical
                    ? 1.5
                    : widget.height * 0.4,
                color: Colors.white.withValues(alpha: 0.1),
              ),

            // Thumb
            Positioned(
              left: widget.direction == Axis.horizontal
                  ? _getThumbPosition()
                  : null,
              bottom: widget.direction == Axis.vertical
                  ? _getThumbPosition()
                  : null,
              child: _buildMinimalThumb(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalTrackTexture() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        3,
        (index) => Container(
          width: widget.width * 0.2,
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
    );
  }

  Widget _buildMinimalThumb() {
    final size = widget.direction == Axis.horizontal
        ? widget.height * 0.9
        : widget.width * 0.9;

    if (widget.direction == Axis.horizontal) {
      // Clean Satin Dial
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey[800]!, Colors.grey[900]!],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(1, 1),
            ),
            BoxShadow(
              color: widget.thumbColor.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Center(
          child: Container(
            width: 2,
            height: size * 0.4,
            decoration: BoxDecoration(
              color: widget.thumbColor.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    } else {
      // Clean Minimal Pedal Plate
      return Container(
        width: widget.width * 1.0,
        height: widget.width * 1.2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[850]!, Colors.grey[900]!],
          ),
          border: Border.all(color: Colors.white12, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: widget.width * 0.5,
              height: 2,
              decoration: BoxDecoration(
                color: widget.thumbColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: widget.width * 0.5,
              height: 1,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ],
        ),
      );
    }
  }

  double _getThumbPosition() {
    final range = widget.max - widget.min;
    if (range == 0) return 0;
    final normalized = ((_currentValue - widget.min) / range).clamp(0.0, 1.0);
    final totalDimension = widget.direction == Axis.horizontal
        ? widget.width
        : widget.height;
    final thumbSize = widget.direction == Axis.horizontal
        ? widget.height * 0.9
        : widget.width * 1.2;
    return normalized * (totalDimension - thumbSize);
  }
}
