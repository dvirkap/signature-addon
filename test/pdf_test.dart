import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'dart:ui';

void main() {
  test('Syncfusion PDF mixed orientations compile test', () {
    // 1. Create mixed document: Page 1 is Portrait, Page 2 is Landscape
    final sf.PdfDocument doc1 = sf.PdfDocument();
    
    // Page 1: Portrait
    final sec1 = doc1.sections!.add();
    sec1.pageSettings.margins.all = 0;
    sec1.pageSettings.size = const Size(595, 842);
    sec1.pageSettings.orientation = sf.PdfPageOrientation.portrait;
    final page1 = sec1.pages.add();
    page1.graphics.drawString('Page 1 - Portrait', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 24), bounds: const Rect.fromLTWH(50, 50, 200, 50));

    // Page 2: Landscape
    final sec2 = doc1.sections!.add();
    sec2.pageSettings.margins.all = 0;
    sec2.pageSettings.size = const Size(595, 842);
    sec2.pageSettings.orientation = sf.PdfPageOrientation.landscape;
    final page2 = sec2.pages.add();
    page2.graphics.drawString('Page 2 - Landscape', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 24), bounds: const Rect.fromLTWH(50, 50, 200, 50));

    final bytes1 = doc1.saveSync();
    doc1.dispose();

    // 2. Load the compiled bytes and verify page sizes
    final reloadedDoc = sf.PdfDocument(inputBytes: bytes1);
    
    print('PAGE 1 SIZE: ${reloadedDoc.pages[0].size}'); // Should be 595 x 842
    print('PAGE 2 SIZE: ${reloadedDoc.pages[1].size}'); // Should be 842 x 595

    reloadedDoc.dispose();
  });

  test('Syncfusion PDF rotation test', () {
    final sf.PdfDocument doc = sf.PdfDocument();
    final sec = doc.sections!.add();
    sec.pageSettings.margins.all = 0;
    sec.pageSettings.size = const Size(595, 842);
    // Setting section.pageSettings.rotate BEFORE adding page
    sec.pageSettings.rotate = sf.PdfPageRotateAngle.rotateAngle90;
    
    final page = sec.pages.add();
    
    // Test scenario 1: Setting page.rotation directly as well
    page.rotation = sf.PdfPageRotateAngle.rotateAngle90;
    
    final bytes = doc.saveSync();
    doc.dispose();
    
    final reloadedDoc = sf.PdfDocument(inputBytes: bytes);
    print('RELOADED PAGE ROTATION (both set, before add): ${reloadedDoc.pages[0].rotation}');
    print('RELOADED PAGE SIZE (both set, before add): ${reloadedDoc.pages[0].size}');
    reloadedDoc.dispose();
  });

  test('Syncfusion PDF rotation test (only section rotate set, before add)', () {
    final sf.PdfDocument doc = sf.PdfDocument();
    final sec = doc.sections!.add();
    sec.pageSettings.margins.all = 0;
    sec.pageSettings.size = const Size(595, 842);
    // Setting section.pageSettings.rotate BEFORE adding page
    sec.pageSettings.rotate = sf.PdfPageRotateAngle.rotateAngle90;
    
    sec.pages.add();
    
    final bytes = doc.saveSync();
    doc.dispose();
    
    final reloadedDoc = sf.PdfDocument(inputBytes: bytes);
    print('RELOADED PAGE ROTATION (only section set, before add): ${reloadedDoc.pages[0].rotation}');
    print('RELOADED PAGE SIZE (only section set, before add): ${reloadedDoc.pages[0].size}');
    reloadedDoc.dispose();
  });

  test('Syncfusion PDF copy page with rotation via template', () {
    // 1. Create a page with 90 degrees rotation
    final sf.PdfDocument doc1 = sf.PdfDocument();
    final sec1 = doc1.sections!.add();
    sec1.pageSettings.margins.all = 0;
    sec1.pageSettings.size = const Size(595, 842);
    sec1.pageSettings.rotate = sf.PdfPageRotateAngle.rotateAngle90;
    final page1 = sec1.pages.add();
    page1.graphics.drawString('Hello Rotation', sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 24), bounds: const Rect.fromLTWH(50, 50, 200, 50));
    final bytes1 = doc1.saveSync();
    doc1.dispose();

    // 2. Load it and copy using template
    final loadedDoc = sf.PdfDocument(inputBytes: bytes1);
    final sourcePage = loadedDoc.pages[0];
    final template = sourcePage.createTemplate();

    final sf.PdfDocument doc2 = sf.PdfDocument();
    final sec2 = doc2.sections!.add();
    sec2.pageSettings.margins.all = 0;
    sec2.pageSettings.size = const Size(595, 842);
    
    // Set rotation before add
    sec2.pageSettings.rotate = sourcePage.rotation;
    final page2 = sec2.pages.add();
    page2.graphics.drawPdfTemplate(template, Offset.zero, sourcePage.size);

    final bytes2 = doc2.saveSync();
    doc2.dispose();
    loadedDoc.dispose();

    // 3. Verify copied page rotation
    final reloadedDoc = sf.PdfDocument(inputBytes: bytes2);
    print('RELOADED COPIED PAGE ROTATION: ${reloadedDoc.pages[0].rotation}');
    print('RELOADED COPIED PAGE SIZE: ${reloadedDoc.pages[0].size}');
    reloadedDoc.dispose();
  });
}
