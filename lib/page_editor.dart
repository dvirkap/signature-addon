import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:image_picker/image_picker.dart';
import 'main.dart';
import 'document_scan_editor.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'premium_paywall.dart';

class PageItem {
  final int originalIndex; // -1 if newly added
  int rotationDegrees; // 0, 90, 180, 270 relative to original
  final bool isBlank;
  Uint8List? imageBytes;
  final Size size;

  // Retroactive scanning metadata
  final Uint8List? scanOriginalBytes;
  List<Offset>? scanCorners;
  String? scanFilter;
  int? scanRotation;

  PageItem({
    required this.originalIndex,
    this.rotationDegrees = 0,
    this.isBlank = false,
    this.imageBytes,
    required this.size,
    this.scanOriginalBytes,
    this.scanCorners,
    this.scanFilter,
    this.scanRotation,
  });
}

class PageEditorScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final bool isPro;

  const PageEditorScreen({
    super.key,
    required this.pdfBytes,
    required this.isPro,
  });

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  bool _isLoading = true;
  List<PageItem> _pages = [];
  late sf.PdfDocument _originalDoc;
  List<Uint8List?> _pageThumbnails = [];

  @override
  void initState() {
    super.initState();
    _loadPdfData();
  }

  Future<void> _loadPdfData() async {
    try {
      _originalDoc = sf.PdfDocument(inputBytes: widget.pdfBytes);
      final List<PageItem> items = [];
      for (int i = 0; i < _originalDoc.pages.count; i++) {
        final page = _originalDoc.pages[i];
        items.add(PageItem(
          originalIndex: i,
          size: Size(page.size.width, page.size.height),
          rotationDegrees: 0,
        ));
      }
      setState(() {
        _pages = items;
        _pageThumbnails = List.filled(_originalDoc.pages.count, null);
        _isLoading = false;
      });
      _renderThumbnails();
    } catch (e) {
      debugPrint('Error loading PDF in page editor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading document: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _renderThumbnails() async {
    try {
      final pdfxDoc = await pdfx.PdfDocument.openData(widget.pdfBytes);
      for (int i = 0; i < _originalDoc.pages.count; i++) {
        final page = await pdfxDoc.getPage(i + 1);
        final pageImage = await page.render(
          width: page.width * 1.5,
          height: page.height * 1.5,
          format: pdfx.PdfPageImageFormat.png,
        );
        await page.close();
        if (mounted) {
          setState(() {
            _pageThumbnails[i] = pageImage?.bytes;
          });
        }
      }
      await pdfxDoc.close();
    } catch (e) {
      debugPrint('Error rendering thumbnails: $e');
    }
  }

  @override
  void dispose() {
    try {
      _originalDoc.dispose();
    } catch (_) {}
    super.dispose();
  }

  // Rotate a page by 90 degrees clockwise
  void _rotatePageClockwise(int index) {
    setState(() {
      _pages[index].rotationDegrees = (_pages[index].rotationDegrees + 90) % 360;
    });
  }

  // Rotate a page by 90 degrees counter-clockwise
  void _rotatePageCounterClockwise(int index) {
    setState(() {
      _pages[index].rotationDegrees = (_pages[index].rotationDegrees - 90 + 360) % 360;
    });
  }

  // Delete page at index
  void _deletePage(int index) {
    setState(() {
      _pages.removeAt(index);
    });
  }


  // Add a blank A4 page at a specific index
  void _addBlankPage(int index) {
    setState(() {
      _pages.insert(
        index,
        PageItem(
          originalIndex: -1,
          isBlank: true,
          size: const Size(595, 842), // Standard A4 points
        ),
      );
    });
  }

  // Scan one or more new pages via native flutter_doc_scanner
  Future<void> _scanNewPages(int index) async {
    if (!widget.isPro) {
      PremiumPaywall.show(context);
      return;
    }

    try {
      final ImageScanResult? result = await FlutterDocScanner().getScannedDocumentAsImages(
        page: 20,
      );
      if (result == null || result.images.isEmpty) {
        return;
      }

      final List<PageItem> newItems = [];
      for (final path in result.images) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          newItems.add(
            PageItem(
              originalIndex: -1,
              imageBytes: bytes,
              size: const Size(595, 842),
              scanOriginalBytes: bytes,
              scanCorners: const [
                Offset(0.0, 0.0),
                Offset(1.0, 0.0),
                Offset(0.0, 1.0),
                Offset(1.0, 1.0),
              ],
              scanFilter: 'original',
              scanRotation: 0,
            ),
          );
        }
      }

      if (newItems.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          for (int i = 0; i < newItems.length; i++) {
            _pages.insert(index + i, newItems[i]);
          }
        });
      }
    } catch (e) {
      debugPrint('Error scanning pages: $e');
    }
  }

  // Pick and add image page from gallery
  Future<void> _addImagePage(int index, ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1600,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;

      // Navigate to the DocumentScanEditorScreen to crop/enhance
      final ScanEditorResult? result = await Navigator.push<ScanEditorResult>(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentScanEditorScreen(imageBytes: bytes),
        ),
      );

      if (result != null) {
        if (!mounted) return;
        setState(() {
          _pages.insert(
            index,
            PageItem(
              originalIndex: -1,
              imageBytes: result.processedBytes,
              size: const Size(595, 842),
              scanOriginalBytes: result.originalBytes,
              scanCorners: result.corners,
              scanFilter: result.filter,
              scanRotation: result.rotation,
            ),
          );
        });
      }
    }
  }

  Future<void> _openRetroactiveScanEditor(int index, PageItem item) async {
    final ScanEditorResult? result = await Navigator.push<ScanEditorResult>(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentScanEditorScreen(
          imageBytes: item.scanOriginalBytes!,
          initialCorners: item.scanCorners,
          initialFilter: item.scanFilter,
          initialRotation: item.scanRotation,
        ),
      ),
    );

    if (result != null) {
      if (!mounted) return;
      setState(() {
        _pages[index] = PageItem(
          originalIndex: item.originalIndex,
          rotationDegrees: item.rotationDegrees,
          isBlank: item.isBlank,
          imageBytes: result.processedBytes,
          size: item.size,
          scanOriginalBytes: result.originalBytes,
          scanCorners: result.corners,
          scanFilter: result.filter,
          scanRotation: result.rotation,
        );
      });
    }
  }

  // Helper to compile edits and save
  Future<void> _saveChanges() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save empty document.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sf.PdfDocument targetDoc = sf.PdfDocument();

      for (final item in _pages) {
        sf.PdfPage page;
        final section = targetDoc.sections!.add();
        section.pageSettings.margins.all = 0;

        if (item.isBlank) {
          section.pageSettings.size = item.size;
          page = section.pages.add();
        } else if (item.imageBytes != null) {
          section.pageSettings.size = item.size;
          page = section.pages.add();
          
          final sf.PdfBitmap bitmap = sf.PdfBitmap(item.imageBytes!);
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(0, 0, page.size.width, page.size.height),
          );
        } else {
          final sourcePage = _originalDoc.pages[item.originalIndex];
          final template = sourcePage.createTemplate();
          
          section.pageSettings.size = sourcePage.size;
          
          page = section.pages.add();
          page.rotation = sourcePage.rotation;
          page.graphics.drawPdfTemplate(template, Offset.zero, sourcePage.size);
        }

        // Apply rotation
        if (item.rotationDegrees != 0) {
          page.rotation = _addRotation(page.rotation, item.rotationDegrees);
        }
        section.pageSettings.rotate = page.rotation;
      }

      final List<int> savedBytes = targetDoc.saveSync();
      targetDoc.dispose();

      Navigator.pop(context, Uint8List.fromList(savedBytes));
    } catch (e) {
      debugPrint('Error saving page edits: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: $e')),
      );
    }
  }

  sf.PdfPageRotateAngle _addRotation(sf.PdfPageRotateAngle current, int degrees) {
    int currentDegrees = 0;
    switch (current) {
      case sf.PdfPageRotateAngle.rotateAngle0:
        currentDegrees = 0;
        break;
      case sf.PdfPageRotateAngle.rotateAngle90:
        currentDegrees = 90;
        break;
      case sf.PdfPageRotateAngle.rotateAngle180:
        currentDegrees = 180;
        break;
      case sf.PdfPageRotateAngle.rotateAngle270:
        currentDegrees = 270;
        break;
    }
    int finalDegrees = (currentDegrees + degrees) % 360;
    switch (finalDegrees) {
      case 90:
        return sf.PdfPageRotateAngle.rotateAngle90;
      case 180:
        return sf.PdfPageRotateAngle.rotateAngle180;
      case 270:
        return sf.PdfPageRotateAngle.rotateAngle270;
      default:
        return sf.PdfPageRotateAngle.rotateAngle0;
    }
  }

  void _showAddPageOptions(int index) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: appLanguage.value == 'he' ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.note_add_outlined),
                title: Text(getStr('insert_blank')),
                onTap: () {
                  Navigator.pop(context);
                  _addBlankPage(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(getStr('scan_page')),
                onTap: () {
                  Navigator.pop(context);
                  _scanNewPages(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(getStr('gallery')),
                onTap: () {
                  Navigator.pop(context);
                  _addImagePage(index, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageCard(int index, PageItem item) {
    final bool isLandscape = (item.size.width > item.size.height);
    final int displayRotation = item.rotationDegrees;
    final bool isEffectivelyLandscape = (displayRotation == 90 || displayRotation == 270)
        ? !isLandscape
        : isLandscape;

    Widget previewWidget;
    if (item.isBlank) {
      previewWidget = Container(
        color: Colors.white,
        child: Center(
          child: Icon(
            Icons.insert_drive_file_outlined,
            size: 32,
            color: Colors.grey[400],
          ),
        ),
      );
    } else if (item.imageBytes != null) {
      previewWidget = Image.memory(
        item.imageBytes!,
        fit: BoxFit.contain,
      );
    } else if (item.originalIndex != -1 &&
        item.originalIndex < _pageThumbnails.length &&
        _pageThumbnails[item.originalIndex] != null) {
      previewWidget = Image.memory(
        _pageThumbnails[item.originalIndex]!,
        fit: BoxFit.contain,
      );
    } else {
      previewWidget = Container(
        color: Colors.grey[100],
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Card(
      key: ValueKey(item),
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // 1. Drag Handle
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Icon(Icons.drag_indicator, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 8),
            // 2. Thumbnail
            SizedBox(
              width: 70,
              height: 90,
              child: Center(
                child: AspectRatio(
                  aspectRatio: isEffectivelyLandscape ? 1.414 : 0.707,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: RotatedBox(
                      quarterTurns: item.rotationDegrees ~/ 90,
                      child: previewWidget,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 3. Info (Page Number)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${getStr('page_indicator_simple')} ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (item.isBlank)
                    Text(
                      getStr('insert_blank'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    )
                  else if (item.imageBytes != null)
                    Text(
                      getStr('scan_page'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    )
                  else if (isLandscape)
                    Text(
                      'לרוחב (Landscape)',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                ],
              ),
            ),
            // 4. Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.scanOriginalBytes != null)
                  IconButton(
                    icon: const Icon(Icons.crop, size: 20, color: Colors.indigoAccent),
                    onPressed: () => _openRetroactiveScanEditor(index, item),
                    tooltip: 'עריכת סריקה',
                  ),
                IconButton(
                  icon: const Icon(Icons.rotate_left, size: 20),
                  onPressed: () => _rotatePageCounterClockwise(index),
                  tooltip: getStr('rotate_counter'),
                ),
                IconButton(
                  icon: const Icon(Icons.rotate_right, size: 20),
                  onPressed: () => _rotatePageClockwise(index),
                  tooltip: getStr('rotate_clockwise'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                  onPressed: () => _deletePage(index),
                  tooltip: getStr('delete_page'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = 1.0 + animValue * 0.03;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = appLanguage.value == 'he';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(getStr('page_editor_title')),
          centerTitle: true,
          actions: [
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveChanges,
                tooltip: getStr('apply_changes'),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: ReorderableListView.builder(
                  physics: const BouncingScrollPhysics(),
                  proxyDecorator: _proxyDecorator,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPageCard(index, _pages[index]);
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final PageItem item = _pages.removeAt(oldIndex);
                      _pages.insert(newIndex, item);
                    });
                  },
                ),
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddPageOptions(_pages.length),
          icon: const Icon(Icons.add),
          label: Text(getStr('scan_page')),
        ),
      ),
    );
  }
}
