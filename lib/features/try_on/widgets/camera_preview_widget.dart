import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// A full-bleed camera preview that fills its parent using `BoxFit.cover`.
///
/// This mirrors the layout maths used by [GarmentOverlayService]'s cover-fit
/// mapping, so landmarks projected onto the overlay line up exactly with what
/// is visible in the preview.
class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;

  const CameraPreviewWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // `aspectRatio` from the controller is width/height in the preview's
    // natural (landscape) orientation; multiplying by the box width gives the
    // matching height for a portrait cover fit.
    final aspectRatio = controller.value.aspectRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth * aspectRatio,
                child: CameraPreview(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}
