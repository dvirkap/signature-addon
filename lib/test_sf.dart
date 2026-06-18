import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:typed_data';

Widget buildPdf(Uint8List bytes, double x, double y, double z) {
  return SfPdfViewer.memory(
    bytes,
    initialScrollOffset: Offset(x, y),
    initialZoomLevel: z,
  );
}
