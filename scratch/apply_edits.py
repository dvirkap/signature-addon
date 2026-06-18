import os

def main():
    file_path = 'lib/main.dart'
    if not os.path.exists(file_path):
        print(f"Error: {file_path} not found")
        return

    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Remove _pendingSignatures state list declaration
    pending_sig_decl = """  // Pending Signatures
  List<SignatureOverlay> _pendingSignatures = [];\n"""
    if pending_sig_decl in content:
        content = content.replace(pending_sig_decl, "")
        print("Success: Removed _pendingSignatures declaration")
    else:
        # try without trailing newline
        pending_sig_decl_no_nl = """  // Pending Signatures
  List<SignatureOverlay> _pendingSignatures = [];"""
        if pending_sig_decl_no_nl in content:
            content = content.replace(pending_sig_decl_no_nl, "")
            print("Success: Removed _pendingSignatures declaration (no newline)")
        else:
            print("Warning: _pendingSignatures declaration not found")

    # 2. Locate and replace _undoLastSignature, _bakeAllPendingSignatures, _openPageEditor, and _confirmActiveSignaturePlacement
    start_tag = '  Future<void> _undoLastSignature() async {'
    end_tag = '  Future<void> _showSignatureSelectionSheet() async {'
    
    start_idx = content.find(start_tag)
    end_idx = content.find(end_tag)

    if start_idx != -1 and end_idx != -1 and start_idx < end_idx:
        old_block = content[start_idx:end_idx]
        
        new_block = """  Future<void> _undoLastSignature() async {
    if (_pdfHistoryPaths.isEmpty) return;
    final lastPath = _pdfHistoryPaths.removeLast();
    try {
      final file = File(lastPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        double currentScrollX = 0.0;
        double currentScrollY = 0.0;
        try {
          currentScrollX = _pdfViewerController.scrollOffset.dx;
          currentScrollY = _pdfViewerController.scrollOffset.dy;
        } catch (_) {}

        setState(() {
          _currentPdfBytes = bytes;
          _pdfUpdateCounter++;
          _restorePageState = true;
          _targetPage = _currentPage;
          _targetZoom = _zoomLevel;
          _targetScrollX = currentScrollX;
          _targetScrollY = currentScrollY;

          // Cancel active signature if editing
          _signatureBytes = null;
          _signatureImage = null;
        });
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error reading/deleting history file: $e');
    }
  }

  Future<void> _openPageEditor(BuildContext context) async {
    // 1. If there's an active signature overlay, warn or bake it first!
    if (_signatureBytes != null && _signatureImage != null) {
      final confirmBake = await showDialog<bool>(
        context: context,
        builder: (context) => Directionality(
          textDirection: appLanguage.value == 'he' ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(getStr('pro_feature_title')),
            content: Text(appLanguage.value == 'he' 
                ? 'יש לשים את החתימה הנוכחית לפני המעבר לעריכת דפים. לשים כעת?'
                : 'You must place the current signature before editing pages. Place now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(getStr('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(getStr('save')),
              ),
            ],
          ),
        ),
      );
      
      if (confirmBake == true) {
        await _confirmActiveSignaturePlacement();
      } else {
        return; // cancel opening editor
      }
    }

    // 2. Open PageEditorScreen
    final result = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => PageEditorScreen(
          pdfBytes: currentPdfBytes,
          isPro: IapService.instance.isPro.value,
        ),
      ),
    );

    // 3. If edits are returned, save old state to history and update active PDF
    if (result != null) {
      await _pushToHistory(currentPdfBytes);
      setState(() {
        _currentPdfBytes = result;
        _pdfUpdateCounter++;
        
        // Reset state so viewer re-evaluates
        _restorePageState = true;
        _targetPage = 1;
        _targetZoom = 1.0;
        _currentPage = 1;
      });
    }
  }

  Future<void> _confirmActiveSignaturePlacement() async {
    if (_signatureBytes == null || _signatureImage == null) return;

    setState(() => _isProcessing = true);

    try {
      Uint8List bytesToBake = _signatureBytes!;
      ui.Image imageToBake = _signatureImage!;

      if (_signatureCaption != null && _signatureCaption!.isNotEmpty) {
        bytesToBake = await _combineSignatureAndCaption(_signatureBytes!, _signatureCaption!);
        final codec = await ui.instantiateImageCodec(bytesToBake);
        final frame = await codec.getNextFrame();
        imageToBake = frame.image;
      }

      final params = PdfBakeParams(
        pdfBytes: currentPdfBytes,
        signatureBytes: bytesToBake,
        signatureWidth: imageToBake.width,
        signatureHeight: imageToBake.height,
        pageNumber: _currentPage,
        rx: _overlayRx,
        ry: _overlayRy,
        rw: _overlayRw,
        rotation: _overlayRotation,
      );

      final bakedBytes = await compute(_bakeSignatureCompute, params);

      // Save old state to history
      await _pushToHistory(currentPdfBytes);

      setState(() {
        _currentPdfBytes = bakedBytes;
        _pdfUpdateCounter++;

        // Reset active editing signature
        _signatureBytes = null;
        _signatureImage = null;
        _signatureCaption = null;

        // Save target zoom/scroll position for restoration
        _targetPage = _currentPage;
        _targetZoom = _zoomLevel;
        _targetScrollX = _pdfViewerController.scrollOffset.dx;
        _targetScrollY = _pdfViewerController.scrollOffset.dy;
        _restorePageState = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${getStr('error_baking')} $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

"""
        content = content[:start_idx] + new_block + content[end_idx:]
        print("Success: Replaced methods block")
    else:
        print("Error: Could not locate methods block to replace")

    # 3. Simplify _saveDocument
    save_doc_block = """      if (_pendingSignatures.isNotEmpty) {
        await _bakeAllPendingSignatures();
      }

      Uint8List finalBytes = currentPdfBytes;"""
      
    if save_doc_block in content:
        content = content.replace(save_doc_block, "      Uint8List finalBytes = currentPdfBytes;")
        print("Success: Simplified _saveDocument")
    else:
        print("Warning: _saveDocument target block not found")

    # 4. Simplify _saveAndShare
    # Note that save_doc_block occurs multiple times. Since save_doc_block has 6 spaces indent,
    # let's try replacing it with allow_multiple or general replace.
    # In python string.replace replaces all occurrences. Let's make sure both occurrences are replaced.
    # Wait, save_doc_block also exists in _saveAndShare with exactly the same text/indentation.
    # So string.replace(save_doc_block, ...) will replace all occurrences. Let's print how many were replaced.

    # Let's count them first:
    count_saves = content.count(save_doc_block)
    if count_saves > 0:
        content = content.replace(save_doc_block, "      Uint8List finalBytes = currentPdfBytes;")
        print(f"Success: Replaced save/share pending signature check {count_saves} times")
    else:
        # let's try with 8 spaces indent
        save_doc_block_8 = """        if (_pendingSignatures.isNotEmpty) {
          await _bakeAllPendingSignatures();
        }

        Uint8List finalBytes = currentPdfBytes;"""
        count_saves_8 = content.count(save_doc_block_8)
        if count_saves_8 > 0:
            content = content.replace(save_doc_block_8, "        Uint8List finalBytes = currentPdfBytes;")
            print(f"Success: Replaced save/share pending signature check (8 spaces) {count_saves_8} times")
        else:
            print("Warning: save/share pending signature check block not found")

    # 5. Restore scroll/zoom state in onDocumentLoaded
    old_restore = """                        if (_restorePageState) {
                          _restorePageState = false;
                        }"""
    
    new_restore = """                        if (_restorePageState) {
                          _restorePageState = false;
                          if (_targetScrollX != null && _targetScrollY != null) {
                            final double zoom = _targetZoom;
                            final double x = _targetScrollX!;
                            final double y = _targetScrollY!;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _pdfViewerController.zoomLevel = zoom;
                                int count = 0;
                                Timer.periodic(const Duration(milliseconds: 30), (timer) {
                                  if (!mounted || count >= 15) {
                                    timer.cancel();
                                    return;
                                  }
                                  _pdfViewerController.jumpTo(xOffset: x, yOffset: y);
                                  count++;
                                });
                              }
                            });
                          }
                        }"""
                        
    if old_restore in content:
        content = content.replace(old_restore, new_restore)
        print("Success: Updated onDocumentLoaded state restoration")
    else:
        print("Warning: onDocumentLoaded restoration block not found")

    # 6. Remove dynamic overlay rendering of pending signatures in build()
    pending_render_start = '        // Pending Signatures (Baked-in preview)'
    pending_render_end = '        // Active Signature Overlay (Editable)'
    
    pr_start_idx = content.find(pending_render_start)
    pr_end_idx = content.find(pending_render_end)
    
    if pr_start_idx != -1 and pr_end_idx != -1 and pr_start_idx < pr_end_idx:
        content = content[:pr_start_idx] + content[pr_end_idx:]
        print("Success: Removed pending signature overlays rendering")
    else:
        print("Warning: Could not find pending signatures rendering block in build()")

    # Write changes back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done editing lib/main.dart successfully!")

if __name__ == '__main__':
    main()
