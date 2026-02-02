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
          width: 60,
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
