import 'dart:ui';

import 'package:flutter/material.dart';

class GearSelector extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final double width;
  final double height;

  const GearSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 56,
    this.height = 184,
  });

  @override
  State<GearSelector> createState() => _GearSelectorState();
}

class _GearSelectorState extends State<GearSelector> {
  static const _gears = ['D', 'N', 'R'];

  String get _normalizedValue {
    if (_gears.contains(widget.value)) {
      return widget.value;
    }
    return 'N';
  }

  int get _selectedIndex => _gears.indexOf(_normalizedValue).clamp(0, 2);

  void _updateGearByDy(double dy, double trackHeight, double thumbHeight) {
    final normalizedY =
        dy.clamp(0.0, trackHeight - thumbHeight) / (trackHeight - thumbHeight);
    final index = (normalizedY * (_gears.length - 1)).round().clamp(0, 2);
    final selected = _gears[index];
    if (selected != widget.value) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackHeight = constraints.maxHeight;
          final thumbHeight = screenHeight * 0.131;
          final availableHeight = trackHeight - thumbHeight;
          final position = availableHeight * (_selectedIndex / 2);

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (details) => _updateGearByDy(
              details.localPosition.dy,
              trackHeight,
              thumbHeight,
            ),
            onPanUpdate: (details) => _updateGearByDy(
              details.localPosition.dy,
              trackHeight,
              thumbHeight,
            ),
            onTapDown: (details) => _updateGearByDy(
              details.localPosition.dy,
              trackHeight,
              thumbHeight,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.width,
                  height: trackHeight,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12, width: 1.0),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenHeight * 0.019,
                      vertical: screenHeight * 0.039,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: _gears.map((gear) {
                        final isSelected = gear == _normalizedValue;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              gear,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: screenHeight * 0.032,
                                fontWeight: isSelected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),

                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  top: clampDouble(position, 5, trackHeight - thumbHeight - 5),
                  left: 4,
                  right: 4,
                  child: Container(
                    height: thumbHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF161B26),
                      border: Border.all(color: Colors.white12, width: 1.0),
                    ),
                    child: Center(
                      child: Text(
                        _normalizedValue,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenHeight * 0.036,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
