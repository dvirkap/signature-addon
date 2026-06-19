import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'main.dart';

class ScanEditorResult {
  final Uint8List processedBytes;
  final Uint8List originalBytes;
  final List<Offset> corners;
  final String filter;
  final int rotation;

  ScanEditorResult({
    required this.processedBytes,
    required this.originalBytes,
    required this.corners,
    required this.filter,
    required this.rotation,
  });
}

class DocumentScanEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final List<Offset>? initialCorners;
  final String? initialFilter;
  final int? initialRotation;

  const DocumentScanEditorScreen({
    super.key,
    required this.imageBytes,
    this.initialCorners,
    this.initialFilter,
    this.initialRotation,
  });

  @override
  State<DocumentScanEditorScreen> createState() => _DocumentScanEditorScreenState();
}

class _DocumentScanEditorScreenState extends State<DocumentScanEditorScreen> {
  bool _isLoading = false;
  int _rotation = 0; // 0, 90, 180, 270
  String _filter = 'original'; // 'original', 'bw', 'enhanced'
  Size _imageSize = const Size(595, 842); // Default fallback

  // 4 corners, normalized (0.0 to 1.0)
  List<Offset> _corners = [
    const Offset(0.05, 0.05), // TL
    const Offset(0.95, 0.05), // TR
    const Offset(0.05, 0.95), // BL
    const Offset(0.95, 0.95), // BR
  ];

  int _activeCorner = -1; // 0: TL, 1: TR, 2: BL, 3: BR

  @override
  void initState() {
    super.initState();
    _rotation = widget.initialRotation ?? 0;
    _filter = widget.initialFilter ?? 'original';
    _loadImageSize();
    if (widget.initialCorners != null && widget.initialCorners!.length == 4) {
      _corners = List.from(widget.initialCorners!);
    } else {
      _runAutoDetection();
    }
  }

  Future<void> _loadImageSize() async {
    try {
      final size = await compute(_decodeSizeIsolate, widget.imageBytes);
      if (mounted) {
        setState(() {
          _imageSize = size;
        });
      }
    } catch (_) {}
  }

  static Size _decodeSizeIsolate(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const Size(595, 842);
    return Size(decoded.width.toDouble(), decoded.height.toDouble());
  }

  Future<void> _runAutoDetection() async {
    setState(() => _isLoading = true);
    try {
      final size = await compute(_decodeSizeIsolate, widget.imageBytes);
      _imageSize = size;
      final detected = await compute(_detectCornersIsolate, widget.imageBytes);
      setState(() {
        _corners = detected;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error running corner detection: $e');
      setState(() => _isLoading = false);
    }
  }

  static List<Offset> _detectCornersIsolate(Uint8List bytes) {
    try {
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return const [
          Offset(0.05, 0.05),
          Offset(0.95, 0.05),
          Offset(0.05, 0.95),
          Offset(0.95, 0.95),
        ];
      }
      final img.Image small = img.copyResize(decoded, width: 320);
      final img.Image gray = img.grayscale(small);
      final int w = gray.width;
      final int h = gray.height;
      final Uint8List grayBytes = Uint8List(w * h);
      for (final pixel in gray) {
        grayBytes[pixel.y * w + pixel.x] = pixel.r.round();
      }
      return detectDocumentCorners(grayBytes, w, h, w);
    } catch (_) {
      return const [
        Offset(0.05, 0.05),
        Offset(0.95, 0.05),
        Offset(0.05, 0.95),
        Offset(0.95, 0.95),
      ];
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
  }

  // Pure Dart image processing in background isolate
  static Uint8List _processImageIsolate(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final int rotation = params['rotation'];
    final String filter = params['filter'];
    final List<Offset> corners = List<Offset>.from(params['corners']);

    img.Image? image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // 1. Rotation
    if (rotation == 90) {
      image = img.copyRotate(image, angle: 90);
    } else if (rotation == 180) {
      image = img.copyRotate(image, angle: 180);
    } else if (rotation == 270) {
      image = img.copyRotate(image, angle: 270);
    }

    final int w = image.width;
    final int h = image.height;

    img.Image warped;

    // Scale corners to absolute coordinates
    final p0 = Offset(corners[0].dx * w, corners[0].dy * h); // TL
    final p1 = Offset(corners[1].dx * w, corners[1].dy * h); // TR
    final p2 = Offset(corners[2].dx * w, corners[2].dy * h); // BL
    final p3 = Offset(corners[3].dx * w, corners[3].dy * h); // BR

    // Compute target width/height
    final double widthTop = (p1 - p0).distance;
    final double widthBottom = (p3 - p2).distance;
    final double heightLeft = (p2 - p0).distance;
    final double heightRight = (p3 - p1).distance;

    int targetW = max(widthTop, widthBottom).round().clamp(100, 2000);
    int targetH = max(heightLeft, heightRight).round().clamp(100, 2000);

    // Keep resolution within high-quality but performant bounds
    if (targetW > 1400) {
      final scale = 1400.0 / targetW;
      targetW = 1400;
      targetH = (targetH * scale).round();
    }

    warped = img.Image(width: targetW, height: targetH);

    final hCoeffs = getPerspectiveTransform(
      0.0, 0.0,
      targetW.toDouble(), 0.0,
      0.0, targetH.toDouble(),
      targetW.toDouble(), targetH.toDouble(),
      p0.dx, p0.dy,
      p1.dx, p1.dy,
      p2.dx, p2.dy,
      p3.dx, p3.dy,
    );

    if (hCoeffs != null) {
      final double h00 = hCoeffs[0], h01 = hCoeffs[1], h02 = hCoeffs[2];
      final double h10 = hCoeffs[3], h11 = hCoeffs[4], h12 = hCoeffs[5];
      final double h20 = hCoeffs[6], h21 = hCoeffs[7];

      for (int y = 0; y < targetH; y++) {
        for (int x = 0; x < targetW; x++) {
          final double den = h20 * x + h21 * y + 1.0;
          final double sx = (h00 * x + h01 * y + h02) / den;
          final double sy = (h10 * x + h11 * y + h12) / den;

          if (sx >= 0 && sx < w && sy >= 0 && sy < h) {
            // Bilinear interpolation
            final int x0 = sx.floor();
            final int y0 = sy.floor();
            final int x1 = (x0 + 1).clamp(0, w - 1);
            final int y1 = (y0 + 1).clamp(0, h - 1);

            final double dx = sx - x0;
            final double dy = sy - y0;

            final p00 = image.getPixel(x0, y0);
            final p10 = image.getPixel(x1, y0);
            final p01 = image.getPixel(x0, y1);
            final p11 = image.getPixel(x1, y1);

            final double r = (1 - dx) * (1 - dy) * p00.r +
                             dx * (1 - dy) * p10.r +
                             (1 - dx) * dy * p01.r +
                             dx * dy * p11.r;

            final double g = (1 - dx) * (1 - dy) * p00.g +
                             dx * (1 - dy) * p10.g +
                             (1 - dx) * dy * p01.g +
                             dx * dy * p11.g;

            final double b = (1 - dx) * (1 - dy) * p00.b +
                             dx * (1 - dy) * p10.b +
                             (1 - dx) * dy * p01.b +
                             dx * dy * p11.b;

            final double a = (1 - dx) * (1 - dy) * p00.a +
                             dx * (1 - dy) * p10.a +
                             (1 - dx) * dy * p01.a +
                             dx * dy * p11.a;

            final targetPixel = warped.getPixel(x, y);
            targetPixel.r = r.round();
            targetPixel.g = g.round();
            targetPixel.b = b.round();
            targetPixel.a = a.round();
          }
        }
      }
    } else {
      warped = image;
    }

    // 3. Filters
    if (filter == 'bw') {
      warped = img.grayscale(warped);
      warped = img.contrast(warped, contrast: 150);
    } else if (filter == 'enhanced') {
      warped = img.contrast(warped, contrast: 125);
      warped = img.adjustColor(warped, brightness: 1.15);
    }

    return Uint8List.fromList(img.encodeJpg(warped, quality: 80));
  }

  Future<void> _processAndConfirm() async {
    setState(() => _isLoading = true);
    try {
      final processedBytes = await compute(_processImageIsolate, {
        'bytes': widget.imageBytes,
        'rotation': _rotation,
        'filter': _filter,
        'corners': _corners,
      });
      Navigator.pop(
        context,
        ScanEditorResult(
          processedBytes: processedBytes,
          originalBytes: widget.imageBytes,
          corners: _corners,
          filter: _filter,
          rotation: _rotation,
        ),
      );
    } catch (e) {
      debugPrint('Error processing scanned document: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  ColorFilter _getFilterColorFilter(String filter) {
    if (filter == 'bw') {
      return const ColorFilter.matrix(<double>[
        1.5, 1.5, 1.5, 0, -200,
        1.5, 1.5, 1.5, 0, -200,
        1.5, 1.5, 1.5, 0, -200,
        0, 0, 0, 1, 0,
      ]);
    } else if (filter == 'enhanced') {
      return const ColorFilter.matrix(<double>[
        1.2, 0, 0, 0, 10,
        0, 1.2, 0, 0, 10,
        0, 0, 1.2, 0, 10,
        0, 0, 0, 1, 0,
      ]);
    }
    return const ColorFilter.matrix(<double>[
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = appLanguage.value == 'he';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          title: Text(
            getStr('scan_editor_title'),
            style: const TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF10B981)),
              onPressed: _isLoading ? null : _processAndConfirm,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SafeArea(
                child: Column(
                  children: [
                    // Top quick actions
                    Container(
                      color: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.rotate_right, color: Colors.white),
                            onPressed: _rotateClockwise,
                            tooltip: getStr('rotate'),
                          ),
                          _buildFilterButton('original', getStr('filter_original')),
                          _buildFilterButton('bw', getStr('filter_bw')),
                          _buildFilterButton('enhanced', getStr('filter_magic')),
                        ],
                      ),
                    ),
                    // Interactive Cropping Workspace
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final boxSize = Size(constraints.maxWidth, constraints.maxHeight);
                              final visibleRect = getVisibleImageRect(boxSize, _imageSize, _rotation);

                              return Stack(
                                children: [
                                  // The raw image displayed (rotated dynamically via UI)
                                  Positioned.fromRect(
                                    rect: visibleRect,
                                    child: RotatedBox(
                                      quarterTurns: _rotation ~/ 90,
                                      child: ColorFiltered(
                                        colorFilter: _getFilterColorFilter(_filter),
                                        child: Image.memory(
                                          widget.imageBytes,
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Crop overlays (interactive handles)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onPanStart: (details) {
                                        final RenderBox box = context.findRenderObject() as RenderBox;
                                        final localPos = box.globalToLocal(details.globalPosition);

                                        // Map touch relative to visible image coordinates
                                        final double rx = ((localPos.dx - visibleRect.left) / visibleRect.width).clamp(0.0, 1.0);
                                        final double ry = ((localPos.dy - visibleRect.top) / visibleRect.height).clamp(0.0, 1.0);

                                        // Find closest corner
                                        int closestIndex = 0;
                                        double minDistance = double.infinity;
                                        for (int i = 0; i < 4; i++) {
                                          final dx = rx - _corners[i].dx;
                                          final dy = ry - _corners[i].dy;
                                          final dist = sqrt(dx * dx + dy * dy);
                                          if (dist < minDistance) {
                                            minDistance = dist;
                                            closestIndex = i;
                                          }
                                        }

                                        setState(() {
                                          _activeCorner = closestIndex;
                                        });
                                      },
                                      onPanUpdate: (details) {
                                        final RenderBox box = context.findRenderObject() as RenderBox;
                                        final localPos = box.globalToLocal(details.globalPosition);

                                        final double rx = ((localPos.dx - visibleRect.left) / visibleRect.width).clamp(0.0, 1.0);
                                        final double ry = ((localPos.dy - visibleRect.top) / visibleRect.height).clamp(0.0, 1.0);

                                        if (_activeCorner != -1) {
                                          setState(() {
                                            _corners[_activeCorner] = Offset(rx, ry);
                                          });
                                        }
                                      },
                                      onPanEnd: (_) {
                                        setState(() {
                                          _activeCorner = -1;
                                        });
                                      },
                                      child: CustomPaint(
                                        painter: QuadPainter(
                                          corners: _corners,
                                          imageSize: _imageSize,
                                          rotation: _rotation,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFilterButton(String type, String label) {
    final bool isSelected = _filter == type;
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: isSelected ? Colors.indigoAccent[100] : Colors.white70,
        backgroundColor: isSelected ? Colors.indigo[900] : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () => setState(() => _filter = type),
      child: Text(label),
    );
  }
}

class QuadPainter extends CustomPainter {
  final List<Offset> corners; // Normalized (0.0 to 1.0)
  final Size imageSize;
  final int rotation;

  QuadPainter({
    required this.corners,
    required this.imageSize,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final visibleRect = getVisibleImageRect(size, imageSize, rotation);

    // Convert corners to pixel coordinates relative to the visibleRect
    final Offset tl = Offset(
      visibleRect.left + corners[0].dx * visibleRect.width,
      visibleRect.top + corners[0].dy * visibleRect.height,
    );
    final Offset tr = Offset(
      visibleRect.left + corners[1].dx * visibleRect.width,
      visibleRect.top + corners[1].dy * visibleRect.height,
    );
    final Offset bl = Offset(
      visibleRect.left + corners[2].dx * visibleRect.width,
      visibleRect.top + corners[2].dy * visibleRect.height,
    );
    final Offset br = Offset(
      visibleRect.left + corners[3].dx * visibleRect.width,
      visibleRect.top + corners[3].dy * visibleRect.height,
    );

    // 1. Draw dim overlay outside the quadrilateral
    final Path canvasPath = Path()..addRect(Rect.fromLTWH(0, 0, w, h));
    final Path quadPath = Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(bl.dx, bl.dy)
      ..close();

    final Path overlayPath = Path.combine(PathOperation.difference, canvasPath, quadPath);
    final Paint dimPaint = Paint()..color = Colors.black.withOpacity(0.5);
    canvas.drawPath(overlayPath, dimPaint);

    // 2. Draw border lines
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(quadPath, borderPaint);

    // 3. Draw corner handles
    final Paint handlePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    final Paint handleBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const double handleRadius = 10.0;
    for (final pt in [tl, tr, bl, br]) {
      canvas.drawCircle(pt, handleRadius, handlePaint);
      canvas.drawCircle(pt, handleRadius, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant QuadPainter oldDelegate) {
    return oldDelegate.corners != corners ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.rotation != rotation;
  }
}

// Global layout aspect ratio calculation for BoxFit.contain
Rect getVisibleImageRect(Size constraintSize, Size imageSize, int rotation) {
  final bool isRotated = (rotation == 90 || rotation == 270);
  final double imgW = isRotated ? imageSize.height : imageSize.width;
  final double imgH = isRotated ? imageSize.width : imageSize.height;

  final double boxW = constraintSize.width;
  final double boxH = constraintSize.height;

  final double imgRatio = imgW / imgH;
  final double boxRatio = boxW / boxH;

  double dispW, dispH;
  if (imgRatio > boxRatio) {
    dispW = boxW;
    dispH = boxW / imgRatio;
  } else {
    dispH = boxH;
    dispW = boxH * imgRatio;
  }

  final double left = (boxW - dispW) / 2;
  final double top = (boxH - dispH) / 2;

  return Rect.fromLTWH(left, top, dispW, dispH);
}

// Math solver helpers
List<double>? solve8x8(List<List<double>> A, List<double> B) {
  const int n = 8;
  for (int i = 0; i < n; i++) {
    int pivot = i;
    for (int j = i + 1; j < n; j++) {
      if (A[j][i].abs() > A[pivot][i].abs()) {
        pivot = j;
      }
    }
    final tempRow = A[i];
    A[i] = A[pivot];
    A[pivot] = tempRow;
    final tempB = B[i];
    B[i] = B[pivot];
    B[pivot] = tempB;

    if (A[i][i].abs() < 1e-10) {
      return null;
    }

    for (int j = i + 1; j < n; j++) {
      final double factor = A[j][i] / A[i][i];
      for (int k = i; k < n; k++) {
        A[j][k] -= factor * A[i][k];
      }
      B[j] -= factor * B[i];
    }
  }

  final List<double> x = List.filled(n, 0.0);
  for (int i = n - 1; i >= 0; i--) {
    double sum = 0.0;
    for (int j = i + 1; j < n; j++) {
      sum += A[i][j] * x[j];
    }
    x[i] = (B[i] - sum) / A[i][i];
  }
  return x;
}

List<double>? getPerspectiveTransform(
  double x0, double y0,
  double x1, double y1,
  double x2, double y2,
  double x3, double y3,
  double u0, double v0,
  double u1, double v1,
  double u2, double v2,
  double u3, double v3,
) {
  final A = [
    [x0, y0, 1.0, 0.0, 0.0, 0.0, -x0 * u0, -y0 * u0],
    [0.0, 0.0, 0.0, x0, y0, 1.0, -x0 * v0, -y0 * v0],
    [x1, y1, 1.0, 0.0, 0.0, 0.0, -x1 * u1, -y1 * u1],
    [0.0, 0.0, 0.0, x1, y1, 1.0, -x1 * v1, -y1 * v1],
    [x2, y2, 1.0, 0.0, 0.0, 0.0, -x2 * u2, -y2 * u2],
    [0.0, 0.0, 0.0, x2, y2, 1.0, -x2 * v2, -y2 * v2],
    [x3, y3, 1.0, 0.0, 0.0, 0.0, -x3 * u3, -y3 * u3],
    [0.0, 0.0, 0.0, x3, y3, 1.0, -x3 * v3, -y3 * v3],
  ];
  final B = [u0, v0, u1, v1, u2, v2, u3, v3];
  return solve8x8(A, B);
}

// Radial edge detection
List<Offset> detectDocumentCorners(Uint8List grayBytes, int width, int height, int bytesPerRow) {
  final int cx = width ~/ 2;
  final int cy = height ~/ 2;

  final int numRays = 32;
  final List<Offset> points = [];

  for (int i = 0; i < numRays; i++) {
    final double angle = (2 * pi * i) / numRays;
    final double dx = cos(angle);
    final double dy = sin(angle);

    double bestT = 0;
    double maxDiff = -1;

    double prevVal = -1;
    for (double t = 5; t < 300; t += 2) {
      final int px = (cx + t * dx).round();
      final int py = (cy + t * dy).round();

      if (px < 0 || px >= width || py < 0 || py >= height) break;

      final int idx = py * bytesPerRow + px;
      if (idx >= grayBytes.length) break;

      final double val = grayBytes[idx].toDouble();
      if (prevVal >= 0) {
        final double diff = prevVal - val;
        if (diff > maxDiff) {
          maxDiff = diff;
          bestT = t;
        }
      }
      prevVal = val;
    }

    if (maxDiff > 15) {
      points.add(Offset(cx + bestT * dx, cy + bestT * dy));
    }
  }

  final List<Offset> topPoints = [];
  final List<Offset> bottomPoints = [];
  final List<Offset> leftPoints = [];
  final List<Offset> rightPoints = [];

  for (final pt in points) {
    final double dx = pt.dx - cx;
    final double dy = pt.dy - cy;
    final double angle = atan2(dy, dx);
    final double angleNorm = angle < 0 ? angle + 2 * pi : angle;

    if (angleNorm < pi / 4 || angleNorm >= 7 * pi / 4) {
      rightPoints.add(pt);
    } else if (angleNorm >= pi / 4 && angleNorm < 3 * pi / 4) {
      bottomPoints.add(pt);
    } else if (angleNorm >= 3 * pi / 4 && angleNorm < 5 * pi / 4) {
      leftPoints.add(pt);
    } else {
      topPoints.add(pt);
    }
  }

  Line fitLineVertical(List<Offset> pts) {
    if (pts.length < 2) return Line(0, 0, isVertical: true);
    double sumY = 0, sumX = 0, sumY2 = 0, sumXY = 0;
    for (final pt in pts) {
      sumY += pt.dy;
      sumX += pt.dx;
      sumY2 += pt.dy * pt.dy;
      sumXY += pt.dx * pt.dy;
    }
    final int n = pts.length;
    final double denom = (n * sumY2 - sumY * sumY);
    if (denom.abs() < 1e-5) return Line(0, sumX / n, isVertical: true);
    final double a = (n * sumXY - sumX * sumY) / denom;
    final double b = (sumX - a * sumY) / n;
    return Line(a, b, isVertical: true);
  }

  Line fitLineHorizontal(List<Offset> pts) {
    if (pts.length < 2) return Line(0, 0, isVertical: false);
    double sumX = 0, sumY = 0, sumX2 = 0, sumXY = 0;
    for (final pt in pts) {
      sumX += pt.dx;
      sumY += pt.dy;
      sumX2 += pt.dx * pt.dx;
      sumXY += pt.dx * pt.dy;
    }
    final int n = pts.length;
    final double denom = (n * sumX2 - sumX * sumX);
    if (denom.abs() < 1e-5) return Line(0, sumY / n, isVertical: false);
    final double m = (n * sumXY - sumX * sumY) / denom;
    final double c = (sumY - m * sumX) / n;
    return Line(m, c, isVertical: false);
  }

  final lineT = fitLineHorizontal(topPoints);
  final lineB = fitLineHorizontal(bottomPoints);
  final lineL = fitLineVertical(leftPoints);
  final lineR = fitLineVertical(rightPoints);

  Offset intersect(Line horiz, Line vert) {
    final double m = horiz.slope;
    final double c = horiz.intercept;
    final double a = vert.slope;
    final double b = vert.intercept;

    final double denom = 1.0 - m * a;
    if (denom.abs() < 1e-5) {
      return Offset(b, c);
    }
    final double y = (m * b + c) / denom;
    final double x = a * y + b;
    return Offset(x, y);
  }

  final Offset tl = intersect(lineT, lineL);
  final Offset tr = intersect(lineT, lineR);
  final Offset bl = intersect(lineB, lineL);
  final Offset br = intersect(lineB, lineR);

  bool isValidOffset(Offset o) => o.dx >= 0 && o.dx <= width && o.dy >= 0 && o.dy <= height;

  if (isValidOffset(tl) && isValidOffset(tr) && isValidOffset(bl) && isValidOffset(br)) {
    return [
      Offset(tl.dx / width, tl.dy / height),
      Offset(tr.dx / width, tr.dy / height),
      Offset(bl.dx / width, bl.dy / height),
      Offset(br.dx / width, br.dy / height),
    ];
  }

  return const [
    Offset(0.05, 0.05),
    Offset(0.95, 0.05),
    Offset(0.05, 0.95),
    Offset(0.95, 0.95),
  ];
}

class Line {
  final double slope;
  final double intercept;
  final bool isVertical;

  Line(this.slope, this.intercept, {required this.isVertical});
}
