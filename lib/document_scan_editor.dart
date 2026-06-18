import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'main.dart';

class DocumentScanEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const DocumentScanEditorScreen({super.key, required this.imageBytes});

  @override
  State<DocumentScanEditorScreen> createState() => _DocumentScanEditorScreenState();
}

class _DocumentScanEditorScreenState extends State<DocumentScanEditorScreen> {
  bool _isLoading = false;
  int _rotation = 0; // 0, 90, 180, 270
  String _filter = 'original'; // 'original', 'bw', 'enhanced'

  // Crop coordinates (normalized: 0.0 to 1.0)
  double cropLeft = 0.05;
  double cropTop = 0.05;
  double cropRight = 0.95;
  double cropBottom = 0.95;

  int _activeCorner = -1; // 0: TL, 1: TR, 2: BL, 3: BR
  bool _isPanningBox = false;
  Offset _panStartNormalizedOffset = Offset.zero;

  void _rotateClockwise() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
  }

  // Pure Dart image processing in background isolate
  static Uint8List _processImageIsolate(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final double left = params['left'];
    final double top = params['top'];
    final double right = params['right'];
    final double bottom = params['bottom'];
    final int rotation = params['rotation'];
    final String filter = params['filter'];

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

    // 2. Crop
    final int w = image.width;
    final int h = image.height;
    final int cropX = (left * w).round().clamp(0, w);
    final int cropY = (top * h).round().clamp(0, h);
    final int cropW = ((right - left) * w).round().clamp(1, w - cropX);
    final int cropH = ((bottom - top) * h).round().clamp(1, h - cropY);

    image = img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);

    // 3. Filters
    if (filter == 'bw') {
      image = img.grayscale(image);
      image = img.contrast(image, contrast: 150);
    } else if (filter == 'enhanced') {
      image = img.contrast(image, contrast: 125);
      image = img.adjustColor(image, brightness: 1.15);
    }

    return Uint8List.fromList(img.encodeJpg(image, quality: 80));
  }

  Future<void> _processAndConfirm() async {
    setState(() => _isLoading = true);
    try {
      final processedBytes = await compute(_processImageIsolate, {
        'bytes': widget.imageBytes,
        'left': cropLeft,
        'top': cropTop,
        'right': cropRight,
        'bottom': cropBottom,
        'rotation': _rotation,
        'filter': _filter,
      });
      Navigator.pop(context, processedBytes);
    } catch (e) {
      debugPrint('Error processing scanned document: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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
                              return Stack(
                                children: [
                                  // The raw image displayed (rotated dynamically via UI)
                                  RotatedBox(
                                    quarterTurns: _rotation ~/ 90,
                                    child: Image.memory(
                                      widget.imageBytes,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  // Crop overlays (interactive handles)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onPanStart: (details) {
                                        final RenderBox box = context.findRenderObject() as RenderBox;
                                        final localPos = box.globalToLocal(details.globalPosition);
                                        final w = box.size.width;
                                        final h = box.size.height;

                                        final rx = localPos.dx / w;
                                        final ry = localPos.dy / h;

                                        // Check if clicked close to corners (radius 0.08 normalized)
                                        const double hitRange = 0.08;
                                        if ((rx - cropLeft).abs() < hitRange && (ry - cropTop).abs() < hitRange) {
                                          _activeCorner = 0; // Top Left
                                        } else if ((rx - cropRight).abs() < hitRange && (ry - cropTop).abs() < hitRange) {
                                          _activeCorner = 1; // Top Right
                                        } else if ((rx - cropLeft).abs() < hitRange && (ry - cropBottom).abs() < hitRange) {
                                          _activeCorner = 2; // Bottom Left
                                        } else if ((rx - cropRight).abs() < hitRange && (ry - cropBottom).abs() < hitRange) {
                                          _activeCorner = 3; // Bottom Right
                                        } else if (rx > cropLeft && rx < cropRight && ry > cropTop && ry < cropBottom) {
                                          _isPanningBox = true;
                                          _panStartNormalizedOffset = Offset(rx, ry);
                                        }
                                      },
                                      onPanUpdate: (details) {
                                        final RenderBox box = context.findRenderObject() as RenderBox;
                                        final localPos = box.globalToLocal(details.globalPosition);
                                        final w = box.size.width;
                                        final h = box.size.height;

                                        final rx = (localPos.dx / w).clamp(0.0, 1.0);
                                        final ry = (localPos.dy / h).clamp(0.0, 1.0);

                                        setState(() {
                                          if (_activeCorner == 0) {
                                            cropLeft = rx.clamp(0.0, cropRight - 0.1);
                                            cropTop = ry.clamp(0.0, cropBottom - 0.1);
                                          } else if (_activeCorner == 1) {
                                            cropRight = rx.clamp(cropLeft + 0.1, 1.0);
                                            cropTop = ry.clamp(0.0, cropBottom - 0.1);
                                          } else if (_activeCorner == 2) {
                                            cropLeft = rx.clamp(0.0, cropRight - 0.1);
                                            cropBottom = ry.clamp(cropTop + 0.1, 1.0);
                                          } else if (_activeCorner == 3) {
                                            cropRight = rx.clamp(cropLeft + 0.1, 1.0);
                                            cropBottom = ry.clamp(cropTop + 0.1, 1.0);
                                          } else if (_isPanningBox) {
                                            final dx = rx - _panStartNormalizedOffset.dx;
                                            final dy = ry - _panStartNormalizedOffset.dy;

                                            final newLeft = (cropLeft + dx).clamp(0.0, 1.0 - (cropRight - cropLeft));
                                            final newRight = newLeft + (cropRight - cropLeft);
                                            final newTop = (cropTop + dy).clamp(0.0, 1.0 - (cropBottom - cropTop));
                                            final newBottom = newTop + (cropBottom - cropTop);

                                            cropLeft = newLeft;
                                            cropRight = newRight;
                                            cropTop = newTop;
                                            cropBottom = newBottom;

                                            _panStartNormalizedOffset = Offset(rx, ry);
                                          }
                                        });
                                      },
                                      onPanEnd: (_) {
                                        _activeCorner = -1;
                                        _isPanningBox = false;
                                      },
                                      child: CustomPaint(
                                        painter: CropBoxPainter(
                                          left: cropLeft,
                                          top: cropTop,
                                          right: cropRight,
                                          bottom: cropBottom,
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

class CropBoxPainter extends CustomPainter {
  final double left;
  final double top;
  final double right;
  final double bottom;

  CropBoxPainter({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final rectLeft = left * w;
    final rectTop = top * h;
    final rectRight = right * w;
    final rectBottom = bottom * h;

    final cropRect = Rect.fromLTRB(rectLeft, rectTop, rectRight, rectBottom);

    // 1. Draw dim overlays outside crop box
    final paintDim = Paint()..color = Colors.black.withOpacity(0.5);
    canvas.drawRect(Rect.fromLTRB(0, 0, w, rectTop), paintDim);
    canvas.drawRect(Rect.fromLTRB(0, rectTop, rectLeft, rectBottom), paintDim);
    canvas.drawRect(Rect.fromLTRB(rectRight, rectTop, w, rectBottom), paintDim);
    canvas.drawRect(Rect.fromLTRB(0, rectBottom, w, h), paintDim);

    // 2. Draw border
    final paintBorder = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(cropRect, paintBorder);

    // 3. Draw corner handles
    final paintHandle = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;

    const handleRadius = 8.0;
    canvas.drawCircle(Offset(rectLeft, rectTop), handleRadius, paintHandle);
    canvas.drawCircle(Offset(rectRight, rectTop), handleRadius, paintHandle);
    canvas.drawCircle(Offset(rectLeft, rectBottom), handleRadius, paintHandle);
    canvas.drawCircle(Offset(rectRight, rectBottom), handleRadius, paintHandle);
  }

  @override
  bool shouldRepaint(covariant CropBoxPainter oldDelegate) {
    return oldDelegate.left != left ||
        oldDelegate.top != top ||
        oldDelegate.right != right ||
        oldDelegate.bottom != bottom;
  }
}
