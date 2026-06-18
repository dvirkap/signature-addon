import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:image_picker/image_picker.dart';
import 'main.dart';
import 'document_scan_editor.dart';

class PageItem {
  final int originalIndex; // -1 if newly added
  int rotationDegrees; // 0, 90, 180, 270 relative to original
  final bool isBlank;
  final Uint8List? imageBytes;
  final Size size;

  PageItem({
    required this.originalIndex,
    this.rotationDegrees = 0,
    this.isBlank = false,
    this.imageBytes,
    required this.size,
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
        _isLoading = false;
      });
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

  // Move page left
  void _movePageLeft(int index) {
    if (index <= 0) return;
    setState(() {
      final item = _pages.removeAt(index);
      _pages.insert(index - 1, item);
    });
  }

  // Move page right
  void _movePageRight(int index) {
    if (index >= _pages.length - 1) return;
    setState(() {
      final item = _pages.removeAt(index);
      _pages.insert(index + 1, item);
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

  // Pick and add image page
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
      final processedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentScanEditorScreen(imageBytes: bytes),
        ),
      );

      if (processedBytes != null) {
        if (!mounted) return;
        setState(() {
          _pages.insert(
            index,
            PageItem(
              originalIndex: -1,
              imageBytes: processedBytes,
              size: const Size(595, 842),
            ),
          );
        });
      }
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
        if (item.isBlank) {
          final section = targetDoc.sections!.add();
          section.pageSettings.size = item.size;
          section.pageSettings.margins.all = 0;
          page = section.pages.add();
        } else if (item.imageBytes != null) {
          final section = targetDoc.sections!.add();
          section.pageSettings.size = item.size;
          section.pageSettings.margins.all = 0;
          page = section.pages.add();
          
          final sf.PdfBitmap bitmap = sf.PdfBitmap(item.imageBytes!);
          page.graphics.drawImage(
            bitmap,
            Rect.fromLTWH(0, 0, page.size.width, page.size.height),
          );
        } else {
          final sourcePage = _originalDoc.pages[item.originalIndex];
          final template = sourcePage.createTemplate();
          
          final section = targetDoc.sections!.add();
          section.pageSettings.size = sourcePage.size;
          section.pageSettings.margins.all = 0;
          
          page = section.pages.add();
          page.graphics.drawPdfTemplate(template, Offset.zero, sourcePage.size);
        }

        // Apply rotation
        if (item.rotationDegrees != 0) {
          page.rotation = _addRotation(page.rotation, item.rotationDegrees);
        }
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
                  _addImagePage(index, ImageSource.camera);
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
    // Rotate indicator
    final int displayRotation = item.rotationDegrees;
    final bool isEffectivelyLandscape = (displayRotation == 90 || displayRotation == 270)
        ? !isLandscape
        : isLandscape;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        children: [
          // Drag/Move top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 18),
                  onPressed: index > 0 ? () => _movePageLeft(index) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Text(
                  '${getStr('page_indicator_simple')} ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: index < _pages.length - 1 ? () => _movePageRight(index) : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Page Preview Area
          Expanded(
            child: Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: AspectRatio(
                  aspectRatio: isEffectivelyLandscape ? 1.414 : 0.707,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey[400]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(1, 2),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            item.isBlank
                                ? Icons.insert_drive_file_outlined
                                : item.imageBytes != null
                                    ? Icons.image_outlined
                                    : Icons.picture_as_pdf_outlined,
                            size: 36,
                            color: Colors.grey[400],
                          ),
                        ),
                        if (item.rotationDegrees != 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.indigo.withOpacity(0.8),
                              child: Text(
                                '${item.rotationDegrees}°',
                                style: const TextStyle(color: Colors.white, fontSize: 8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Actions bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.rotate_left, size: 18),
                onPressed: () => _rotatePageCounterClockwise(index),
                tooltip: getStr('rotate_counter'),
              ),
              IconButton(
                icon: const Icon(Icons.rotate_right, size: 18),
                onPressed: () => _rotatePageClockwise(index),
                tooltip: getStr('rotate_clockwise'),
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () => _deletePage(index),
                tooltip: getStr('delete_page'),
              ),
            ],
          ),
        ],
      ),
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
                child: Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return _buildPageCard(index, _pages[index]);
                        },
                      ),
                    ),
                  ],
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
