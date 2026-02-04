import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

/// Converts a slider value (0.0 to 1.0) to a zoom level (0.1 to 4.0).
///
/// Uses a non-linear scale where:
/// - 0.0 → 10% zoom (0.1)
/// - 0.5 → 100% zoom (1.0)
/// - 1.0 → 400% zoom (4.0)
double sliderToZoom(double sliderValue) {
  if (sliderValue <= 0.5) {
    // Left half: exponential from 0.1 to 1.0
    return 0.1 * math.pow(10, sliderValue * 2);
  } else {
    // Right half: exponential from 1.0 to 4.0
    return math.pow(4, 2 * sliderValue - 1).toDouble();
  }
}

/// Converts a zoom level (0.1 to 4.0) to a slider value (0.0 to 1.0).
///
/// Inverse of [sliderToZoom].
double zoomToSlider(double zoom) {
  if (zoom <= 1.0) {
    // Left half: slider = log10(zoom * 10) / 2
    return (math.log(zoom * 10) / math.ln10) / 2;
  } else {
    // Right half: slider = (log4(zoom) + 1) / 2
    return ((math.log(zoom) / math.log(4)) + 1) / 2;
  }
}

class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.controller,
    required this.onZoomChanged,
  });

  final WorksheetController controller;
  final VoidCallback onZoomChanged;

  /// Snap tolerance around the 0.5 midpoint (100% zoom).
  static const _snapTolerance = 0.02;

  void _zoomOut() {
    final zoom = controller.zoom;
    double newZoom;
    if (zoom <= 0.1) return;
    if (zoom <= 1.0) {
      newZoom = (zoom - 0.1).clamp(0.1, 4.0);
    } else {
      newZoom = (zoom - 0.25).clamp(0.1, 4.0);
    }
    controller.setZoom(newZoom);
    onZoomChanged();
  }

  void _zoomIn() {
    final zoom = controller.zoom;
    double newZoom;
    if (zoom >= 4.0) return;
    if (zoom < 1.0) {
      newZoom = (zoom + 0.1).clamp(0.1, 4.0);
    } else {
      newZoom = (zoom + 0.25).clamp(0.1, 4.0);
    }
    controller.setZoom(newZoom);
    onZoomChanged();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (controller.zoom * 100).round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove, size: 14),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: _zoomOut,
          tooltip: 'Zoom out',
        ),
        SizedBox(
          width: 90,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 2,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              thumbColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              overlayColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: zoomToSlider(controller.zoom),
              min: 0.0,
              max: 1.0,
              divisions: 100,
              onChanged: (sliderValue) {
                // Snap to 100% when near the midpoint
                final snapped = (sliderValue - 0.5).abs() < _snapTolerance
                    ? 0.5
                    : sliderValue;
                controller.setZoom(sliderToZoom(snapped));
                onZoomChanged();
              },
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$percentage%',
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 14),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: _zoomIn,
          tooltip: 'Zoom in',
        ),
      ],
    );
  }
}
