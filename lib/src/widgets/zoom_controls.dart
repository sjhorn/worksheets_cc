import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

class ZoomControls extends StatelessWidget {
  const ZoomControls({
    super.key,
    required this.controller,
    required this.onZoomChanged,
  });

  final WorksheetController controller;
  final VoidCallback onZoomChanged;

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
          onPressed: () {
            controller.zoomOut();
            onZoomChanged();
          },
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
              value: controller.zoom,
              min: 0.1,
              max: 4.0,
              onChanged: (value) {
                controller.setZoom(value);
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
          onPressed: () {
            controller.zoomIn();
            onZoomChanged();
          },
          tooltip: 'Zoom in',
        ),
      ],
    );
  }
}
