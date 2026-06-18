import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'translations.dart';
import 'page_editor.dart';
import 'iap_service.dart';
import 'premium_paywall.dart';

final ValueNotifier<String> appLanguage = ValueNotifier('he');

String getStr(String key) {
  final lang = appLanguage.value;
  return localizedValues[lang]?[key] ?? localizedValues['en']?[key] ?? key;
}

bool isRtl(String langCode) {
  return const ['he', 'ar', 'fa', 'ur', 'yi'].contains(langCode);
}

class AppSettings {
  static Future<File> get _settingsFile async {
    final docDir = await getApplicationDocumentsDirectory();
    return File('${docDir.path}/app_settings.json');
  }

  static Future<Map<String, dynamic>> readSettings() async {
    try {
      final file = await _settingsFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error reading settings: $e');
    }
    return {};
  }

  static Future<void> writeSetting(String key, dynamic value) async {
    try {
      final file = await _settingsFile;
      final settings = await readSettings();
      settings[key] = value;
      await file.writeAsString(json.encode(settings));
    } catch (e) {
      debugPrint('Error writing setting: $e');
    }
  }

  static Future<String> getLanguage() async {
    final settings = await readSettings();
    return settings['language'] ?? 'he';
  }

  static Future<String> getPrintedName() async {
    final settings = await readSettings();
    return settings['printed_name'] ?? '';
  }
}


class PdfBakeParams {
  final Uint8List pdfBytes;
  final Uint8List signatureBytes;
  final int signatureWidth;
  final int signatureHeight;
  final int pageNumber;
  final double rx;
  final double ry;
  final double rw;
  final double rotation;

  PdfBakeParams({
    required this.pdfBytes,
    required this.signatureBytes,
    required this.signatureWidth,
    required this.signatureHeight,
    required this.pageNumber,
    required this.rx,
    required this.ry,
    required this.rw,
    required this.rotation,
  });
}

class SignatureOverlay {
  final Uint8List signatureBytes;
  final int signatureWidth;
  final int signatureHeight;
  final int pageNumber;
  final double rx;
  final double ry;
  final double rw;
  final double rotation;
  final ui.Image image;

  SignatureOverlay({
    required this.signatureBytes,
    required this.signatureWidth,
    required this.signatureHeight,
    required this.pageNumber,
    required this.rx,
    required this.ry,
    required this.rw,
    required this.rotation,
    required this.image,
  });
}

Uint8List _bakeSignatureCompute(PdfBakeParams params) {
  final document = sf.PdfDocument(inputBytes: params.pdfBytes);
  final pageNumber = params.pageNumber;

  if (pageNumber > 0 && pageNumber <= document.pages.count) {
    final page = document.pages[pageNumber - 1];

    final double pdfWidth = page.size.width;
    final double pdfHeight = page.size.height;

    // Detect page rotation
    int pageRotationDegrees = 0;
    switch (page.rotation) {
      case sf.PdfPageRotateAngle.rotateAngle0:
        pageRotationDegrees = 0;
        break;
      case sf.PdfPageRotateAngle.rotateAngle90:
        pageRotationDegrees = 90;
        break;
      case sf.PdfPageRotateAngle.rotateAngle180:
        pageRotationDegrees = 180;
        break;
      case sf.PdfPageRotateAngle.rotateAngle270:
        pageRotationDegrees = 270;
        break;
    }

    final bool isRotated90or270 = pageRotationDegrees == 90 || pageRotationDegrees == 270;
    final double visualWidth = isRotated90or270 ? pdfHeight : pdfWidth;
    final double visualHeight = isRotated90or270 ? pdfWidth : pdfHeight;

    final double visualCenterX = params.rx * visualWidth;
    final double visualCenterY = params.ry * visualHeight;

    final double visualSigWidth = params.rw * visualWidth;
    final double visualSigHeight = visualSigWidth * (params.signatureHeight / params.signatureWidth);

    double pdfCenterX = visualCenterX;
    double pdfCenterY = visualCenterY;
    double angleInDegrees = (params.rotation * 180 / pi);

    if (pageRotationDegrees == 90) {
      pdfCenterX = visualCenterY;
      pdfCenterY = pdfHeight - visualCenterX;
      angleInDegrees = angleInDegrees - 90;
    } else if (pageRotationDegrees == 180) {
      pdfCenterX = pdfWidth - visualCenterX;
      pdfCenterY = pdfHeight - visualCenterY;
      angleInDegrees = angleInDegrees - 180;
    } else if (pageRotationDegrees == 270) {
      pdfCenterX = pdfWidth - visualCenterY;
      pdfCenterY = visualCenterX;
      angleInDegrees = angleInDegrees - 270;
    }

    print('ISOLATE BAKE DEBUG: pdfSize=${page.size.width}x${page.size.height}, pageRotationDegrees=$pageRotationDegrees, visualWidth=$visualWidth, visualHeight=$visualHeight, rx=${params.rx}, ry=${params.ry}, visualCenterX=$visualCenterX, visualCenterY=$visualCenterY, pdfCenterX=$pdfCenterX, pdfCenterY=$pdfCenterY, rotation=${params.rotation}, angleInDegrees=$angleInDegrees');

    final sf.PdfBitmap image = sf.PdfBitmap(params.signatureBytes);

    page.graphics.save();
    page.graphics.translateTransform(pdfCenterX, pdfCenterY);
    page.graphics.rotateTransform(angleInDegrees);
    page.graphics.drawImage(
      image,
      Rect.fromLTWH(
        -visualSigWidth / 2,
        -visualSigHeight / 2,
        visualSigWidth,
        visualSigHeight,
      ),
    );
    page.graphics.restore();
  }

  final List<int> savedBytes = document.saveSync();
  document.dispose();
  return Uint8List.fromList(savedBytes);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IapService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final lang = await AppSettings.getLanguage();
    appLanguage.value = lang;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return MaterialApp(
          title: lang == 'he' ? 'Just sign - ╫ñ╫⌐╫ץ╫ר ╫£╫ק╫¬╫ץ╫¥' : 'Just sign',
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: appSupportedLanguages.keys.map((code) => Locale(code)).toList(),
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Assistant',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF4F46E5),
              primary: const Color(0xFF4F46E5),
              secondary: const Color(0xFF10B981),
            ),
          ),
          home: const DashboardScreen(),
        );
      },
    );
  }
}

// Advanced Image Processing to remove background and crop signatures
Future<Uint8List> processSignatureImage(Uint8List originalBytes) async {
  try {
    final codec = await ui.instantiateImageCodec(originalBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final int width = image.width;
    final int height = image.height;

    final ByteData? bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return originalBytes;

    final Uint8List pixels = bd.buffer.asUint8List();

    // Find dynamic threshold based on maximum brightness (to handle shadows)
    double maxBrightness = 0;
    for (int i = 0; i < pixels.length; i += 4) {
      final double b = (pixels[i] + pixels[i + 1] + pixels[i + 2]) / 3.0;
      if (b > maxBrightness) maxBrightness = b;
    }

    // White paper is usually close to max brightness. Threshold is 45 levels below max.
    final double threshold = maxBrightness - 45.0;
    final double finalThreshold = threshold.clamp(150.0, 215.0);

    int minX = width;
    int maxX = 0;
    int minY = height;
    int maxY = 0;
    bool hasInk = false;

    // Step 1: Filter pixels (transparency & ink contrast boost)
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int offset = (y * width + x) * 4;
        final int r = pixels[offset];
        final int g = pixels[offset + 1];
        final int b = pixels[offset + 2];
        final int a = pixels[offset + 3];

        if (a < 10) {
          pixels[offset + 3] = 0; // Keep transparent
          continue;
        }

        final double brightness = (r + g + b) / 3.0;

        if (brightness > finalThreshold) {
          pixels[offset + 3] = 0; // Make paper transparent
        } else {
          hasInk = true;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;

          // Increase contrast (sharpen ink lines)
          // Maintain color tone (e.g. blue or black ink) but make it crisper
          final double factor = (brightness / finalThreshold) * 0.4;
          pixels[offset] = (r * factor).toInt().clamp(0, 255);
          pixels[offset + 1] = (g * factor).toInt().clamp(0, 255);
          pixels[offset + 2] = (b * factor).toInt().clamp(0, 255);
          pixels[offset + 3] = 255; // Keep ink fully opaque
        }
      }
    }

    if (!hasInk) return originalBytes;

    // Add a tiny padding margin around signature
    const int padding = 6;
    minX = max(0, minX - padding);
    maxX = min(width - 1, maxX + padding);
    minY = max(0, minY - padding);
    maxY = min(height - 1, maxY + padding);

    final int croppedWidth = maxX - minX + 1;
    final int croppedHeight = maxY - minY + 1;

    if (croppedWidth <= 0 || croppedHeight <= 0) return originalBytes;

    // Copy cropped image content
    final Uint8List croppedPixels = Uint8List(croppedWidth * croppedHeight * 4);
    for (int y = 0; y < croppedHeight; y++) {
      for (int x = 0; x < croppedWidth; x++) {
        final int srcOffset = ((minY + y) * width + (minX + x)) * 4;
        final int destOffset = (y * croppedWidth + x) * 4;

        croppedPixels[destOffset] = pixels[srcOffset];
        croppedPixels[destOffset + 1] = pixels[srcOffset + 1];
        croppedPixels[destOffset + 2] = pixels[srcOffset + 2];
        croppedPixels[destOffset + 3] = pixels[srcOffset + 3];
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      croppedPixels,
      croppedWidth,
      croppedHeight,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final croppedImage = await completer.future;

    final ByteData? pngData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    if (pngData == null) return originalBytes;
    return pngData.buffer.asUint8List();
  } catch (e) {
    debugPrint('Error processing signature: $e');
    return originalBytes;
  }
}

// Simple Storage Helper for Signature Images
class SignatureStorage {
  static Future<Directory> get _signaturesDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/signatures');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<List<File>> getSignatures() async {
    try {
      final dir = await _signaturesDir;
      final List<FileSystemEntity> list = dir.listSync();
      final List<File> files = [];
      for (var item in list) {
        if (item is File &&
            (item.path.endsWith('.png') ||
                item.path.endsWith('.jpg') ||
                item.path.endsWith('.jpeg'))) {
          files.add(item);
        }
      }
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      debugPrint('Error getting signatures: $e');
      return [];
    }
  }

  static Future<File> saveSignature(Uint8List bytes, {String? label, bool process = true}) async {
    final dir = await _signaturesDir;
    // Process image: remove background paper, crop to bounds if requested
    final processedBytes = process ? await processSignatureImage(bytes) : bytes;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final String fileName;
    if (label != null && label.isNotEmpty) {
      final encoded = Uri.encodeComponent(label);
      fileName = 'sig_${timestamp}_$encoded.png';
    } else {
      fileName = 'sig_$timestamp.png';
    }
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(processedBytes);
    return file;
  }

  static Future<void> deleteSignature(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting signature: $e');
    }
  }
}

String getSignatureLabel(File file, String locale) {
  final name = file.path.split('/').last.split('\\').last;
  final parts = name.split('_');
  if (parts.length >= 3) {
    try {
      final labelPart = parts[2].split('.').first;
      final decoded = Uri.decodeComponent(labelPart);
      if (decoded.isNotEmpty) return decoded;
    } catch (e) {
      // ignore
    }
  }
  return locale == 'he' ? '╫ק╫¬╫ש╫₧╫פ/╫ק╫ץ╫¬╫₧╫¬' : 'Signature/Stamp';
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

String formatDateTime(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final year = dt.year;
  final hour = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$min';
}

String getPdfDisplayName(File file) {
  final name = file.path.split('/').last.split('\\').last;
  final regex = RegExp(r'_signed_\d+\.pdf$');
  if (regex.hasMatch(name)) {
    return name.replaceAll(regex, '.pdf');
  }
  return name;
}

Future<String?> _promptSignatureLabel(BuildContext context, String locale) async {
  final controller = TextEditingController();
  final String title = getStr('stamp_label_prompt_title');
  final String hint = getStr('stamp_label_prompt_hint');
  final String cancel = getStr('cancel');
  final String save = getStr('save');

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Directionality(
      textDirection: locale == 'he' ? TextDirection.rtl : TextDirection.ltr,
      child: AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(save),
          ),
        ],
      ),
    ),
  );
}

class PlacedSignature {
  final Uint8List bytes;
  final ui.Image image;
  double rx; // relative center X (0.0 to 1.0)
  double ry; // relative center Y (0.0 to 1.0)
  double rw; // relative width on page (0.0 to 1.0)
  double rotation; // In radians
  int pageNumber;

  PlacedSignature({
    required this.bytes,
    required this.image,
    required this.rx,
    required this.ry,
    required this.rw,
    required this.rotation,
    required this.pageNumber,
  });
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  bool _isLoading = false;
  List<File> _recentFiles = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleIncomingIntent();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final archiveDir = Directory('${docDir.path}/archive');
      if (await archiveDir.exists()) {
        final list = archiveDir.listSync();
        final List<File> files = [];
        for (var item in list) {
          if (item is File && item.path.endsWith('.pdf')) {
            files.add(item);
          }
        }
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        setState(() {
          _recentFiles = files;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent files: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleIncomingIntent();
    }
  }

  Future<void> _handleIncomingIntent() async {
    const channel = MethodChannel('com.example.signature_addon/intent');
    try {
      final Map? intentData = await channel.invokeMethod('getIncomingIntent');
      if (intentData != null && intentData['filePath'] != null) {
        final String path = intentData['filePath'];
        final String name = intentData['fileName'] ?? 'document.pdf';
        final file = File(path);
        if (await file.exists()) {
          setState(() => _isLoading = true);
          final bytes = await file.readAsBytes();
          _openEditor(bytes, name);
        }
      }
    } catch (e) {
      debugPrint('Error intent: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPdfFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        _openEditor(bytes, result.files.single.name);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('╫⌐╫ע╫ש╫נ╫פ: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openEditor(Uint8List bytes, String name) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditorScreen(pdfBytes: bytes, pdfName: name),
      ),
    ).then((_) => _loadRecentFiles());
  }

  Widget _buildChangelogItem(String version, String changes, {required bool isLatest}) {
    final isHe = appLanguage.value == 'he';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLatest ? const Color(0xFF4F46E5).withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLatest ? const Color(0xFF4F46E5).withOpacity(0.2) : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${getStr('version')} $version',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isLatest ? const Color(0xFF4F46E5) : Colors.black87,
                ),
              ),
              if (isLatest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isHe ? '╫ó╫ף╫¢╫á╫ש' : 'Current',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            changes,
            style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: appLanguage.value == 'he' ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            getStr('about_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: Color(0xFF4F46E5),
                    child: Icon(Icons.gesture, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    getStr('app_title'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${getStr('version')} 1.1.0',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    getStr('about_desc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const Divider(height: 32, thickness: 1),
                  Align(
                    alignment: appLanguage.value == 'he' ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(
                      getStr('whats_new_title'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildChangelogItem(
                    '1.1.0',
                    getStr('version_changelog_1_1_0'),
                    isLatest: true,
                  ),
                  const SizedBox(height: 12),
                  _buildChangelogItem(
                    '1.0.0',
                    getStr('version_changelog_1_0_0'),
                    isLatest: false,
                  ),
                ],
              ),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(getStr('close'), style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final currentLang = appLanguage.value;
        final isRtlLang = isRtl(currentLang);
        
        // Prepare sorted list of languages: Hebrew and English first, then rest sorted alphabetically
        final topCodes = ['he', 'en'];
        final otherCodes = appSupportedLanguages.keys
            .where((code) => !topCodes.contains(code))
            .toList();
            
        otherCodes.sort((a, b) {
          final nameA = appSupportedLanguages[a] ?? '';
          final nameB = appSupportedLanguages[b] ?? '';
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        });
        
        final allCodes = [...topCodes, ...otherCodes];
        
        return Directionality(
          textDirection: isRtlLang ? TextDirection.rtl : TextDirection.ltr,
          child: AlertDialog(
            title: Text(getStr('select_language'), textAlign: TextAlign.center),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.5,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allCodes.length,
                itemBuilder: (context, index) {
                  final code = allCodes[index];
                  final name = appSupportedLanguages[code] ?? code;
                  final isSelected = code == currentLang;
                  
                  return ListTile(
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                        : null,
                    onTap: () {
                      AppSettings.writeSetting('language', code);
                      appLanguage.value = code;
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        final isRtlLang = isRtl(lang);

        return Directionality(
          textDirection: isRtlLang ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            drawer: Drawer(
              child: Column(
                children: [
                  UserAccountsDrawerHeader(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    currentAccountPicture: const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.gesture, size: 40, color: Color(0xFF4F46E5)),
                    ),
                    accountName: Text(
                      lang == 'he' ? '╫ף╫ס╫ש╫¿ ╫º╫ñ╫£╫ƒ' : 'Dvir Kaplan',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    accountEmail: Text(
                      lang == 'he' ? '╫⌐╫ש╫¿╫ץ╫¬ ╫£╫ª╫ש╫ס╫ץ╫¿' : 'Public Service',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF4F46E5)),
                          title: Text(getStr('pick_pdf')),
                          onTap: () {
                            Navigator.pop(context);
                            _pickPdfFile();
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.gesture, color: Color(0xFF4F46E5)),
                          title: Text(getStr('manage_signatures')),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SignatureManagerScreen(),
                              ),
                            ).then((_) => _loadRecentFiles());
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.archive, color: Color(0xFF4F46E5)),
                          title: Text(getStr('archive_title')),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ArchiveScreen(),
                              ),
                            ).then((_) => _loadRecentFiles());
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.language, color: Color(0xFF4F46E5)),
                          title: Text(getStr('language')),
                          onTap: () {
                            Navigator.pop(context);
                            _showLanguageSelectionDialog(context);
                          },
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: IapService.instance.isPro,
                          builder: (builderContext, isProUnlocked, child) {
                            return ListTile(
                              leading: Icon(
                                isProUnlocked ? Icons.verified : Icons.star,
                                color: const Color(0xFF4F46E5),
                              ),
                              title: Text(
                                isProUnlocked
                                    ? (lang == 'he' ? '╫ע╫¿╫í╫¬ PRO ╫ñ╫ó╫ש╫£╫פ' : 'PRO Version Active')
                                    : getStr('upgrade_to_pro'),
                                style: TextStyle(
                                  fontWeight: isProUnlocked ? FontWeight.normal : FontWeight.bold,
                                  color: isProUnlocked ? Colors.green : const Color(0xFF4F46E5),
                                ),
                              ),
                              subtitle: isProUnlocked
                                  ? null
                                  : Text(
                                      lang == 'he' ? '╫ó╫¿╫ש╫¢╫¬ ╫ף╫ñ╫ש╫¥ ╫ץ╫í╫¿╫ש╫º╫¬ ╫₧╫í╫₧╫¢╫ש╫¥' : 'Page editing & scanning',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                              onTap: () {
                                Navigator.pop(builderContext);
                                if (!isProUnlocked) {
                                  PremiumPaywall.show(context);
                                }
                              },
                            );
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.info_outline, color: Color(0xFF4F46E5)),
                          title: Text(getStr('about_app')),
                          onTap: () {
                            Navigator.pop(context);
                            _showAboutDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '${getStr('version')} 1.1.0',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            appBar: AppBar(
              title: Text('v2.8 | ${getStr('dashboard_title')}'),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.gesture),
                  tooltip: getStr('manage_signatures'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SignatureManagerScreen(),
                      ),
                    ).then((_) => _loadRecentFiles());
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 30),
                            Center(
                              child: Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _pickPdfFile,
                                    icon: const Icon(Icons.picture_as_pdf, size: 24),
                                    label: Text(getStr('pick_file_to_load'), style: const TextStyle(fontSize: 18)),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      minimumSize: const Size(260, 60),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const SignatureManagerScreen(),
                                        ),
                                      ).then((_) => _loadRecentFiles());
                                    },
                                    icon: const Icon(Icons.gesture, size: 20),
                                    label: Text(getStr('manage_my_signatures'), style: const TextStyle(fontSize: 16)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      minimumSize: const Size(260, 50),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  getStr('recent_documents'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (_recentFiles.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const ArchiveScreen(),
                                        ),
                                      ).then((_) => _loadRecentFiles());
                                    },
                                    child: Text(getStr('all')),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _recentFiles.isEmpty
                                ? Card(
                                    elevation: 0,
                                    color: Colors.grey[50],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        children: [
                                          Icon(Icons.archive_outlined, size: 40, color: Colors.grey[400]),
                                          const SizedBox(height: 12),
                                          Text(
                                            getStr('no_archived_files'),
                                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _recentFiles.length,
                                    itemBuilder: (context, index) {
                                      final file = _recentFiles[index];
                                      final name = getPdfDisplayName(file);
                                      final dateStr = formatDateTime(file.lastModifiedSync());
                                      final sizeStr = formatFileSize(file.lengthSync());

                                      return Card(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          leading: const CircleAvatar(
                                            backgroundColor: Color(0xFFE0E7FF),
                                            child: Icon(Icons.picture_as_pdf, color: Color(0xFF4F46E5), size: 20),
                                          ),
                                          title: Text(
                                            name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            '$dateStr Γאó $sizeStr',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (context) => PdfReaderScreen(file: file, displayName: name),
                                              ),
                                            ).then((_) => _loadRecentFiles());
                                          },
                                        ),
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

// Signature Management Screen
class SignatureManagerScreen extends StatefulWidget {
  const SignatureManagerScreen({super.key});

  @override
  State<SignatureManagerScreen> createState() => _SignatureManagerScreenState();
}

class _SignatureManagerScreenState extends State<SignatureManagerScreen> {
  List<File> _signatures = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSignatures();
  }

  Future<void> _loadSignatures() async {
    setState(() => _isLoading = true);
    final list = await SignatureStorage.getSignatures();
    setState(() {
      _signatures = list;
      _isLoading = false;
    });
  }

  Future<void> _addFromCamera() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final processed = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => SignatureCropEditorScreen(imageBytes: bytes),
        ),
      );
      if (processed != null) {
        if (!mounted) return;
        final label = await _promptSignatureLabel(context, appLanguage.value);
        await SignatureStorage.saveSignature(processed, label: label, process: false);
        _loadSignatures();
      }
    }
  }

  Future<void> _addFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final processed = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => SignatureCropEditorScreen(imageBytes: bytes),
        ),
      );
      if (processed != null) {
        if (!mounted) return;
        final label = await _promptSignatureLabel(context, appLanguage.value);
        await SignatureStorage.saveSignature(processed, label: label, process: false);
        _loadSignatures();
      }
    }
  }

  Future<void> _deleteSignature(String path) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: appLanguage.value == 'he' ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(getStr('delete_signature')),
          content: Text(getStr('confirm_delete_signature')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(getStr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(getStr('delete')),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      await SignatureStorage.deleteSignature(path);
      _loadSignatures();
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: appLanguage.value == 'he' ? TextDirection.rtl : TextDirection.ltr,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: Text(getStr('add_from_camera')),
                  onTap: () {
                    Navigator.pop(context);
                    _addFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text(getStr('add_from_gallery')),
                  onTap: () {
                    Navigator.pop(context);
                    _addFromGallery();
                  },
                ),
              ],
            ),
          ),
        ),
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
          title: Text(getStr('manage_signatures')),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddOptions,
          icon: const Icon(Icons.add),
          label: Text(getStr('add_signature_stamp')),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _signatures.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.gesture, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            getStr('no_saved_signatures'),
                            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            getStr('click_to_add'),
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _signatures.length,
                        itemBuilder: (context, index) {
                          final file = _signatures[index];
                          final label = getSignatureLabel(file, appLanguage.value);
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                          child: Image.file(
                                            file,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: double.infinity,
                                      color: Colors.grey[100],
                                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                      child: Text(
                                        label,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.red.withOpacity(0.9),
                                    radius: 16,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete, size: 14, color: Colors.white),
                                      onPressed: () => _deleteSignature(file.path),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ),
    );
  }
}

class EditorScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String pdfName;

  const EditorScreen({super.key, required this.pdfBytes, required this.pdfName});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey _pdfViewerKey = GlobalKey();
  final GlobalKey _activeSignatureKey = GlobalKey();

  bool _isProcessing = false;

  // Viewport tracking state for overlays (prevents lag/drift during scroll/zoom)
  int _currentPage = 1;
  double _zoomLevel = 1.0;
  int _pdfUpdateCounter = 0;

  // Real-time PDF bytes and Undo history
  Uint8List? _currentPdfBytes;
  Uint8List get currentPdfBytes => _currentPdfBytes ?? widget.pdfBytes;
  final List<String> _pdfHistoryPaths = [];

  Future<void> _pushToHistory(Uint8List bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final historyDir = Directory('${tempDir.path}/pdf_history_cache');
      if (!await historyDir.exists()) {
        await historyDir.create(recursive: true);
      }
      final filePath = '${historyDir.path}/history_${DateTime.now().microsecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      _pdfHistoryPaths.add(filePath);
      setState(() {});
    } catch (e) {
      debugPrint('Error writing history to disk: $e');
    }
  }

  void _cleanupHistoryCache() {
    for (final path in _pdfHistoryPaths) {
      try {
        final file = File(path);
        file.exists().then((exists) {
          if (exists) {
            file.delete().catchError((e) {
              debugPrint('Error deleting history file on cleanup: $e');
            });
          }
        });
      } catch (e) {
        debugPrint('Error during history file cleanup: $e');
      }
    }
    _pdfHistoryPaths.clear();
  }

  // Page restoration state
  bool _restorePageState = false;
  int _targetPage = 1;
  double _targetZoom = 1.0;
  double? _targetScrollX;
  double? _targetScrollY;

  // PDF page sizes loaded on startup
  List<Size> _pdfPageSizes = [];
  List<int> _pdfPageRotations = [];

  // Active Signature Overlay State
  Uint8List? _signatureBytes;
  ui.Image? _signatureImage;
  String? _signatureCaption;

  // Pending Signatures
  List<SignatureOverlay> _pendingSignatures = [];

  // Page-relative values for active signature
  double _overlayRx = 0.5; // center X (0.0 to 1.0)
  double _overlayRy = 0.5; // center Y (0.0 to 1.0)
  double _overlayRw = 0.3; // width relative to page width (0.0 to 1.0)
  double _overlayRotation = 0.0; // In radians

  // Gesture Tracker Base values
  double _baseRw = 0.3;
  double _baseRotation = 0.0;
  double _baseRx = 0.5;
  double _baseRy = 0.5;
  Offset _startFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentPdfBytes = widget.pdfBytes;
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _cleanupHistoryCache();
    super.dispose();
  }


  Size? _getViewportSize() {
    if (_pdfViewerKey.currentContext == null) return null;
    final renderBox = _pdfViewerKey.currentContext!.findRenderObject() as RenderBox?;
    return renderBox?.size;
  }

  double _getWPageZoomed() {
    final viewportSize = _getViewportSize();
    if (viewportSize == null || _pdfPageSizes.isEmpty) return 1.0;

    final pageIndex = _currentPage - 1;
    if (pageIndex < 0 || pageIndex >= _pdfPageSizes.length) return 1.0;
    final pdfSize = _pdfPageSizes[pageIndex];

    final int rotation = _pdfPageRotations.length > pageIndex ? _pdfPageRotations[pageIndex] : 0;
    final bool isRotated90or270 = rotation == 90 || rotation == 270;

    final double W_viewport = viewportSize.width;
    final double H_viewport = viewportSize.height;
    final double W_pdf = isRotated90or270 ? pdfSize.height : pdfSize.width;
    final double H_pdf = isRotated90or270 ? pdfSize.width : pdfSize.height;

    final double fitScale = min(W_viewport / W_pdf, H_viewport / H_pdf);
    final double W_page_unzoomed = W_pdf * fitScale;

    return W_page_unzoomed * _zoomLevel;
  }

  double _getHPageZoomed() {
    final viewportSize = _getViewportSize();
    if (viewportSize == null || _pdfPageSizes.isEmpty) return 1.0;

    final pageIndex = _currentPage - 1;
    if (pageIndex < 0 || pageIndex >= _pdfPageSizes.length) return 1.0;
    final pdfSize = _pdfPageSizes[pageIndex];

    final int rotation = _pdfPageRotations.length > pageIndex ? _pdfPageRotations[pageIndex] : 0;
    final bool isRotated90or270 = rotation == 90 || rotation == 270;

    final double W_viewport = viewportSize.width;
    final double H_viewport = viewportSize.height;
    final double W_pdf = isRotated90or270 ? pdfSize.height : pdfSize.width;
    final double H_pdf = isRotated90or270 ? pdfSize.width : pdfSize.height;

    final double fitScale = min(W_viewport / W_pdf, H_viewport / H_pdf);
    final double H_page_unzoomed = H_pdf * fitScale;

    return H_page_unzoomed * _zoomLevel;
  }

  Offset _getPageStart() {
    final viewportSize = _getViewportSize();
    if (viewportSize == null || _pdfPageSizes.isEmpty) return Offset.zero;

    final pageIndex = _currentPage - 1;
    if (pageIndex < 0 || pageIndex >= _pdfPageSizes.length) return Offset.zero;
    final pdfSize = _pdfPageSizes[pageIndex];

    final int rotation = _pdfPageRotations.length > pageIndex ? _pdfPageRotations[pageIndex] : 0;
    final bool isRotated90or270 = rotation == 90 || rotation == 270;

    final double W_viewport = viewportSize.width;
    final double H_viewport = viewportSize.height;
    final double W_pdf = isRotated90or270 ? pdfSize.height : pdfSize.width;
    final double H_pdf = isRotated90or270 ? pdfSize.width : pdfSize.height;

    final double fitScale = min(W_viewport / W_pdf, H_viewport / H_pdf);
    final double W_page_unzoomed = W_pdf * fitScale;
    final double H_page_unzoomed = H_pdf * fitScale;

    final double zoom = _zoomLevel;
    
    double scrollX = 0.0;
    double scrollY = 0.0;
    try {
      scrollX = _pdfViewerController.scrollOffset.dx;
      scrollY = _pdfViewerController.scrollOffset.dy;
    } catch (_) {}

    final double W_page_zoomed = W_page_unzoomed * zoom;
    final double H_page_zoomed = H_page_unzoomed * zoom;

    final double scrollXZoomed = scrollX * zoom;
    final double scrollYZoomed = scrollY * zoom;

    final double x_page_start = max(0.0, (W_viewport - W_page_zoomed) / 2) - scrollXZoomed;
    final double y_page_start = max(0.0, (H_viewport - H_page_zoomed) / 2) - scrollYZoomed;

    debugPrint('POSITION DEBUG: zoom=$zoom, scroll=($scrollX, $scrollY), scrollZoomed=($scrollXZoomed, $scrollYZoomed), viewport=(${W_viewport}x${H_viewport}), pageZoomed=(${W_page_zoomed}x${H_page_zoomed}), pageStart=(${x_page_start}, ${y_page_start})');

    return Offset(x_page_start, y_page_start);
  }

  Future<void> _loadSignatureFromBytes(Uint8List bytes, {String? defaultLabel}) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    final double W_page_zoomed = _getWPageZoomed();
    final double H_page_zoomed = _getHPageZoomed();
    final viewportSize = _getViewportSize();

    double initialRx = 0.5;
    double initialRy = 0.5;
    double initialRw = 0.3;

    if (viewportSize != null && W_page_zoomed > 0 && H_page_zoomed > 0) {
      final double W_viewport = viewportSize.width;
      final double H_viewport = viewportSize.height;

      double scrollX = 0.0;
      double scrollY = 0.0;
      try {
        scrollX = _pdfViewerController.scrollOffset.dx;
        scrollY = _pdfViewerController.scrollOffset.dy;
      } catch (_) {}

      // Find the visual center of the viewport relative to the page start
      final double scrollXZoomed = scrollX * _zoomLevel;
      final double scrollYZoomed = scrollY * _zoomLevel;
      final double centerXOnPage = W_viewport / 2 + scrollXZoomed;
      final double centerYOnPage = H_viewport / 2 + scrollYZoomed;

      // Normalize to page relative coordinate (0.0 to 1.0)
      initialRx = (centerXOnPage / W_page_zoomed).clamp(0.0, 1.0);
      initialRy = (centerYOnPage / H_page_zoomed).clamp(0.0, 1.0);

      // Sizing: Target a screen-space width of 140 logical pixels, clamped to 40% of viewport width
      double targetVisualWidth = 140.0;
      targetVisualWidth = targetVisualWidth.clamp(40.0, W_viewport * 0.4);
      initialRw = (targetVisualWidth / W_page_zoomed).clamp(0.05, 0.9);
    }

    setState(() {
      _signatureBytes = bytes;
      _signatureImage = frame.image;
      _signatureCaption = defaultLabel;
      _overlayRx = initialRx;
      _overlayRy = initialRy;
      _overlayRw = initialRw;
      _overlayRotation = 0.0;
    });
  }

  Future<void> _scanSignatureFromCamera() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final processed = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => SignatureCropEditorScreen(imageBytes: bytes),
        ),
      );
      if (processed != null) {
        if (!mounted) return;
        final label = await _promptSignatureLabel(context, appLanguage.value);
        await SignatureStorage.saveSignature(processed, label: label, process: false);
        await _loadSignatureFromBytes(processed, defaultLabel: label);
      }
    }
  }

  Future<void> _pickSignatureFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final processed = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => SignatureCropEditorScreen(imageBytes: bytes),
        ),
      );
      if (processed != null) {
        if (!mounted) return;
        final label = await _promptSignatureLabel(context, appLanguage.value);
        await SignatureStorage.saveSignature(processed, label: label, process: false);
        await _loadSignatureFromBytes(processed, defaultLabel: label);
      }
    }
  }

  Future<void> _undoLastSignature() async {
    if (_pendingSignatures.isNotEmpty) {
      setState(() {
        _pendingSignatures.removeLast();
        _signatureBytes = null;
        _signatureImage = null;
      });
      return;
    }

    if (_pdfHistoryPaths.isEmpty) return;
    final lastPath = _pdfHistoryPaths.removeLast();
    try {
      final file = File(lastPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        setState(() {
          _currentPdfBytes = bytes;
          _pdfUpdateCounter++;
          _restorePageState = true;
          _targetPage = _currentPage;
          _targetZoom = _zoomLevel;

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

  Future<void> _bakeAllPendingSignatures() async {
    if (_pendingSignatures.isEmpty) return;
    
    setState(() => _isProcessing = true);
    try {
      await _pushToHistory(currentPdfBytes);
      
      Uint8List bytes = currentPdfBytes;
      for (final sig in _pendingSignatures) {
        final params = PdfBakeParams(
          pdfBytes: bytes,
          signatureBytes: sig.signatureBytes,
          signatureWidth: sig.signatureWidth,
          signatureHeight: sig.signatureHeight,
          pageNumber: sig.pageNumber,
          rx: sig.rx,
          ry: sig.ry,
          rw: sig.rw,
          rotation: sig.rotation,
        );
        bytes = await compute(_bakeSignatureCompute, params);
      }
      
      setState(() {
        _currentPdfBytes = bytes;
        _pendingSignatures.clear();
        _pdfUpdateCounter++;
        _restorePageState = true;
        _targetPage = _currentPage;
        _targetZoom = _zoomLevel;
        _targetScrollX = _pdfViewerController.scrollOffset.dx;
        _targetScrollY = _pdfViewerController.scrollOffset.dy;
      });
    } catch (e) {
      debugPrint('Error baking pending signatures: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${getStr('error_baking')} $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
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
                ? '╫ש╫⌐ ╫£╫º╫ס╫ó ╫נ╫¬ ╫פ╫ק╫¬╫ש╫₧╫פ ╫פ╫á╫ץ╫¢╫ק╫ש╫¬ ╫£╫ñ╫á╫ש ╫פ╫₧╫ó╫ס╫¿ ╫£╫ó╫¿╫ש╫¢╫¬ ╫ף╫ñ╫ש╫¥. ╫£╫º╫ס╫ó ╫¢╫ó╫¬?'
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

    // Bake all pending signatures before passing to PageEditorScreen
    if (_pendingSignatures.isNotEmpty) {
      await _bakeAllPendingSignatures();
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

      setState(() {
        _pendingSignatures.add(SignatureOverlay(
          signatureBytes: bytesToBake,
          signatureWidth: imageToBake.width,
          signatureHeight: imageToBake.height,
          pageNumber: _currentPage,
          rx: _overlayRx,
          ry: _overlayRy,
          rw: _overlayRw,
          rotation: _overlayRotation,
          image: imageToBake,
        ));

        // Reset active editing signature
        _signatureBytes = null;
        _signatureImage = null;
        _signatureCaption = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${getStr('error_baking')} $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _showSignatureSelectionSheet() async {
    final List<File> savedSignatures = await SignatureStorage.getSignatures();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: appLanguage.value == 'he' ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    getStr('select_or_add'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _scanSignatureFromCamera();
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: Text(getStr('camera')),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _pickSignatureFromGallery();
                        },
                        icon: const Icon(Icons.photo_library),
                        label: Text(getStr('gallery')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    getStr('saved_signatures'),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: savedSignatures.isEmpty
                        ? Center(
                            child: Text(
                              getStr('no_saved_device'),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: savedSignatures.length,
                            itemBuilder: (context, index) {
                              final file = savedSignatures[index];
                              final label = getSignatureLabel(file, appLanguage.value);
                              return GestureDetector(
                                onTap: () async {
                                  Navigator.pop(context);
                                  final bytes = await file.readAsBytes();
                                  _loadSignatureFromBytes(bytes);
                                },
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SizedBox(
                                    width: 120,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Image.file(
                                              file,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: double.infinity,
                                          color: Colors.grey[100],
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                          child: Text(
                                            label,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveDocument() async {
    setState(() => _isProcessing = true);

    try {
      // If there's an active signature editing, bake it now
      if (_signatureBytes != null && _signatureImage != null) {
        await _confirmActiveSignaturePlacement();
      }

      if (_pendingSignatures.isNotEmpty) {
        await _bakeAllPendingSignatures();
      }

      Uint8List finalBytes = currentPdfBytes;

      // Save to internal archive
      final docDir = await getApplicationDocumentsDirectory();
      final archiveDir = Directory('${docDir.path}/archive');
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanName = widget.pdfName.replaceAll('.pdf', '');
      final filename = '${cleanName}_signed_$timestamp.pdf';
      final file = File('${archiveDir.path}/$filename');
      await file.writeAsBytes(finalBytes);

      // Attempt to save to public Downloads or chosen folder
      String? targetDirPath;
      bool savedSuccessfully = false;

      if (Platform.isAndroid) {
        final defaultDownloadDir = Directory('/storage/emulated/0/Download');
        if (await defaultDownloadDir.exists()) {
          try {
            final targetFile = File('${defaultDownloadDir.path}/$filename');
            await targetFile.writeAsBytes(finalBytes);
            targetDirPath = defaultDownloadDir.path;
            savedSuccessfully = true;
          } catch (e) {
            debugPrint('Writing to /storage/emulated/0/Download failed: $e. Falling back to folder picker.');
          }
        }
      }

      if (!savedSuccessfully) {
        // Fallback to picker
        final selectedDir = await FilePicker.platform.getDirectoryPath();
        if (selectedDir != null) {
          final targetFile = File('$selectedDir/$filename');
          await targetFile.writeAsBytes(finalBytes);
          targetDirPath = selectedDir;
          savedSuccessfully = true;
        } else {
          // User cancelled folder picker
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(getStr('cancel'))),
          );
          setState(() => _isProcessing = false);
          return;
        }
      }

      if (savedSuccessfully) {
        final successMsg = appLanguage.value == 'he'
            ? '╫פ╫₧╫í╫₧╫ת ╫á╫⌐╫₧╫¿ ╫ס╫פ╫ª╫£╫ק╫פ ╫ס-$targetDirPath'
            : 'Document saved successfully to $targetDirPath';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Return to dashboard
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('╫⌐╫ע╫ש╫נ╫פ: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveAndShare() async {
    setState(() => _isProcessing = true);

    try {
      // If there's an active signature editing, bake it now
      if (_signatureBytes != null && _signatureImage != null) {
        await _confirmActiveSignaturePlacement();
      }

      if (_pendingSignatures.isNotEmpty) {
        await _bakeAllPendingSignatures();
      }

      Uint8List finalBytes = currentPdfBytes;

      final docDir = await getApplicationDocumentsDirectory();
      final archiveDir = Directory('${docDir.path}/archive');
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanName = widget.pdfName.replaceAll('.pdf', '');
      final file = File('${archiveDir.path}/${cleanName}_signed_$timestamp.pdf');
      await file.writeAsBytes(finalBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: getStr('app_title'),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('╫⌐╫ע╫ש╫נ╫פ: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = (now.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  Future<Uint8List> _combineSignatureAndCaption(Uint8List sigBytes, String caption) async {
    final codec = await ui.instantiateImageCodec(sigBytes);
    final frame = await codec.getNextFrame();
    final sigImage = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final double fontSize = sigImage.height * 0.12;
    final textPainter = TextPainter(
      text: TextSpan(
        text: caption,
        style: TextStyle(
          fontSize: fontSize.clamp(12.0, 48.0),
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    );
    textPainter.layout();

    final double padding = sigImage.height * 0.08;
    final double combinedWidth = max(sigImage.width.toDouble(), textPainter.width) + 16.0;
    final double combinedHeight = sigImage.height + padding + textPainter.height + 16.0;

    final double sigLeft = (combinedWidth - sigImage.width) / 2;
    canvas.drawImage(sigImage, Offset(sigLeft, 8.0), Paint());

    final double textLeft = (combinedWidth - textPainter.width) / 2;
    final double textTop = 8.0 + sigImage.height + padding;
    textPainter.paint(canvas, Offset(textLeft, textTop));

    final picture = recorder.endRecording();
    final combinedImage = await picture.toImage(combinedWidth.ceil(), combinedHeight.ceil());
    final byteData = await combinedImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return sigBytes;
    return byteData.buffer.asUint8List();
  }

  Future<String?> _promptCaption(BuildContext context, String currentCaption) async {
    final controller = TextEditingController(text: currentCaption);
    final isRtl = appLanguage.value == 'he';
    return showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(getStr('stamp_caption')),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: getStr('stamp_label_prompt_hint'),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, currentCaption),
              child: Text(getStr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(getStr('save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> textToImage(String text, {required double fontSize, required Color color}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    );
    
    textPainter.layout();
    textPainter.paint(canvas, const Offset(2, 2));
    
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      textPainter.width.ceil() + 6,
      textPainter.height.ceil() + 6,
    );
    
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception("Could not generate text image");
    return byteData.buffer.asUint8List();
  }

  Widget _colorOption(Color color, Color selectedColor, Function(Color) onSelect) {
    final isSelected = color == selectedColor;
    return GestureDetector(
      onTap: () => onSelect(color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.green : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              spreadRadius: 1,
            )
          ]
        ),
      ),
    );
  }

  Future<void> _showTextInputDialog({
    required String initialText,
    required String title,
    required bool isPrintedName,
  }) async {
    final controller = TextEditingController(text: initialText);
    Color selectedColor = Colors.black;
    double selectedSize = 24.0;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: appLanguage.value == 'he' ? TextDirection.rtl : TextDirection.ltr,
              child: AlertDialog(
                title: Text(title, textAlign: TextAlign.center),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: getStr('enter_text_hint'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _colorOption(Colors.black, selectedColor, (c) => setDialogState(() => selectedColor = c)),
                          _colorOption(const Color(0xFF1E3A8A), selectedColor, (c) => setDialogState(() => selectedColor = c)), // Dark Blue
                          _colorOption(const Color(0xFF4F46E5), selectedColor, (c) => setDialogState(() => selectedColor = c)), // Indigo
                          _colorOption(Colors.red[800]!, selectedColor, (c) => setDialogState(() => selectedColor = c)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('${getStr('text_size')} ${selectedSize.round()}'),
                      Slider(
                        value: selectedSize,
                        min: 14.0,
                        max: 48.0,
                        divisions: 17,
                        onChanged: (val) => setDialogState(() => selectedSize = val),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(getStr('cancel')),
                  ),
                  TextButton(
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        if (isPrintedName) {
                          await AppSettings.writeSetting('printed_name', text);
                        }
                        Navigator.pop(context);
                        final bytes = await textToImage(text, fontSize: selectedSize, color: selectedColor);
                        _loadSignatureFromBytes(bytes);
                      }
                    },
                    child: Text(getStr('save_confirm')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTextOverlayDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: appLanguage.value == 'he' ? TextDirection.rtl : TextDirection.ltr,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.text_format),
                    title: Text(getStr('free_text')),
                    onTap: () {
                      Navigator.pop(context);
                      _showTextInputDialog(
                        initialText: '',
                        title: getStr('free_text'),
                        isPrintedName: false,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.date_range),
                    title: Text(getStr('current_date')),
                    onTap: () {
                      Navigator.pop(context);
                      _showTextInputDialog(
                        initialText: _formatCurrentDate(),
                        title: getStr('current_date'),
                        isPrintedName: false,
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(getStr('printed_name')),
                    onTap: () async {
                      Navigator.pop(context);
                      final savedName = await AppSettings.getPrintedName();
                      _showTextInputDialog(
                        initialText: savedName,
                        title: getStr('printed_name_saved'),
                        isPrintedName: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double W_page_zoomed = _getWPageZoomed();
    final double H_page_zoomed = _getHPageZoomed();
    final Offset pageStart = _getPageStart();

    // Active signature calculations if present
    double activeSigLeft = 0;
    double activeSigTop = 0;
    double activeSigWidth = 0;
    double activeSigHeight = 0;
    double toolbarLeft = 0;
    double toolbarTop = 0;

    if (_signatureBytes != null && _signatureImage != null) {
      activeSigWidth = _overlayRw * W_page_zoomed;
      activeSigHeight = activeSigWidth * (_signatureImage!.height / _signatureImage!.width);
      final double activeSigCenterX = pageStart.dx + _overlayRx * W_page_zoomed;
      final double activeSigCenterY = pageStart.dy + _overlayRy * H_page_zoomed;
      activeSigLeft = activeSigCenterX - activeSigWidth / 2;
      activeSigTop = activeSigCenterY - activeSigHeight / 2;

      print('VISUAL OVERLAY DEBUG: rx=$_overlayRx, ry=$_overlayRy, rw=$_overlayRw, activeSigCenterX=$activeSigCenterX, activeSigCenterY=$activeSigCenterY, activeSigLeft=$activeSigLeft, activeSigTop=$activeSigTop, W_page_zoomed=$W_page_zoomed, H_page_zoomed=$H_page_zoomed, pageStart=$pageStart');

      // Toolbar positioning (centered horizontally above or below the signature)
      toolbarTop = activeSigTop - 54;
      if (toolbarTop < 10) {
        toolbarTop = activeSigTop + activeSigHeight + 14;
      }
      final double screenWidth = MediaQuery.of(context).size.width;
      toolbarLeft = (activeSigCenterX - 80).clamp(10.0, screenWidth - 170.0);
    }

    final isRtl = appLanguage.value == 'he';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text('v2.8 | ${widget.pdfName}'),
          actions: [
            if (_pdfHistoryPaths.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _undoLastSignature,
                tooltip: getStr('undo_last'),
              ),
            ValueListenableBuilder<bool>(
              valueListenable: IapService.instance.isPro,
              builder: (builderContext, isProUnlocked, child) {
                return IconButton(
                  icon: Icon(
                    Icons.pages,
                    color: isProUnlocked ? null : const Color(0xFF38BDF8),
                  ),
                  onPressed: () {
                    if (isProUnlocked) {
                      _openPageEditor(context);
                    } else {
                      PremiumPaywall.show(context);
                    }
                  },
                  tooltip: getStr('page_editor_title'),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.text_fields),
              onPressed: _showTextOverlayDialog,
              tooltip: getStr('add_text_or_date'),
            ),
            IconButton(
              icon: const Icon(Icons.gesture),
              onPressed: _showSignatureSelectionSheet,
              tooltip: getStr('add_signature_stamp'),
            ),
            if (_pdfHistoryPaths.isNotEmpty || _signatureBytes != null) ...[
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _isProcessing ? null : _saveDocument,
                tooltip: getStr('save_document'),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _isProcessing ? null : _saveAndShare,
                tooltip: getStr('share_document'),
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // PDF Viewer wrapped in a NotificationListener to capture scroll updates
              NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (notification.depth == 0 && _signatureBytes != null) {
                    setState(() {});
                  }
                  return false; // Allow the scroll notification to bubble up
                },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        key: _pdfViewerKey,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: SfPdfViewer.memory(
                            currentPdfBytes,
                            key: ValueKey('pdf_viewer_$_pdfUpdateCounter'),
                            controller: _pdfViewerController,
                            initialScrollOffset: Offset(_targetScrollX ?? 0, _targetScrollY ?? 0),
                            initialZoomLevel: _targetZoom > 0 ? _targetZoom : 1.0,
                      canShowScrollHead: false,
                      pageLayoutMode: PdfPageLayoutMode.single,
                      scrollDirection: PdfScrollDirection.vertical,
                      enableTextSelection: false,
                      enableDocumentLinkAnnotation: false,
                      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                        try {
                          final formFields = _pdfViewerController.getFormFields();
                          for (final field in formFields) {
                            field.readOnly = true;
                          }
                        } catch (e) {
                          debugPrint('Error locking form fields: $e');
                        }

                        final List<Size> sizes = [];
                        final List<int> rotations = [];
                        for (int i = 0; i < details.document.pages.count; i++) {
                          final page = details.document.pages[i];
                          sizes.add(Size(page.size.width, page.size.height));
                          int rotationAngle = 0;
                          switch (page.rotation) {
                            case sf.PdfPageRotateAngle.rotateAngle90:
                              rotationAngle = 90;
                              break;
                            case sf.PdfPageRotateAngle.rotateAngle180:
                              rotationAngle = 180;
                              break;
                            case sf.PdfPageRotateAngle.rotateAngle270:
                              rotationAngle = 270;
                              break;
                            default:
                              rotationAngle = 0;
                          }
                          rotations.add(rotationAngle);
                        }
                        setState(() {
                          _pdfPageSizes = sizes;
                          _pdfPageRotations = rotations;
                        });

                        if (_restorePageState) {
                          _restorePageState = false;
                        }
                      },
                      onZoomLevelChanged: (PdfZoomDetails details) {
                        _zoomLevel = details.newZoomLevel;
                        if (_signatureBytes != null) {
                          setState(() {});
                        }
                      },
                      onPageChanged: (PdfPageChangedDetails details) {
                        setState(() {
                          _currentPage = details.newPageNumber;
                          _zoomLevel = 1.0;
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),

        // Pending Signatures (Baked-in preview)
        ..._pendingSignatures.where((sig) => sig.pageNumber == _currentPage).map((sig) {
          final double sigWidth = sig.rw * W_page_zoomed;
          final double sigHeight = sigWidth * (sig.signatureHeight / sig.signatureWidth);
          final double sigCenterX = pageStart.dx + sig.rx * W_page_zoomed;
          final double sigCenterY = pageStart.dy + sig.ry * H_page_zoomed;
          final double sigLeft = sigCenterX - sigWidth / 2;
          final double sigTop = sigCenterY - sigHeight / 2;

          return Positioned(
            left: sigLeft,
            top: sigTop,
            child: IgnorePointer( // Prevent pending signatures from absorbing gestures
              child: Transform.rotate(
                angle: sig.rotation,
                child: Image.memory(
                  sig.signatureBytes,
                  width: sigWidth,
                  height: sigHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }),

        // Active Signature Overlay (Editable)
        if (_signatureBytes != null && _signatureImage != null)
                Positioned(
                  left: activeSigLeft - 10,
                  top: activeSigTop - 10,
                  child: GestureDetector(
                    onScaleStart: (details) {
                      _baseRw = _overlayRw;
                      _baseRotation = _overlayRotation;
                      _baseRx = _overlayRx;
                      _baseRy = _overlayRy;
                      _startFocalPoint = details.focalPoint;
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        _overlayRw = (_baseRw * details.scale).clamp(0.05, 0.9);
                        _overlayRotation = _baseRotation + details.rotation;

                        final Offset delta = details.focalPoint - _startFocalPoint;
                        final double deltaRx = delta.dx / W_page_zoomed;
                        final double deltaRy = delta.dy / H_page_zoomed;

                        _overlayRx = (_baseRx + deltaRx).clamp(0.0, 1.0);
                        _overlayRy = (_baseRy + deltaRy).clamp(0.0, 1.0);
                      });
                    },
                    child: Transform.rotate(
                      angle: _overlayRotation,
                      child: Stack(
                        children: [
                          // Base container that defines Stack bounds and handles hit testing correctly
                          Container(
                            width: activeSigWidth + 20,
                            height: activeSigHeight + 50,
                            color: Colors.transparent,
                          ),
                          // Signature image positioned inside Stack bounds
                          Positioned(
                            left: 10,
                            top: 10,
                            child: Container(
                              key: _activeSignatureKey,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF4F46E5), width: 1.5, style: BorderStyle.solid),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.memory(
                                    _signatureBytes!,
                                    width: activeSigWidth,
                                    height: activeSigHeight,
                                    fit: BoxFit.contain,
                                  ),
                                  if (_signatureCaption != null && _signatureCaption!.isNotEmpty)
                                    Container(
                                      color: Colors.white.withOpacity(0.8),
                                      width: activeSigWidth,
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        _signatureCaption!,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: (activeSigWidth * 0.1).clamp(8.0, 20.0),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // Resize/Scale handle at bottom-right
                          Positioned(
                            left: activeSigWidth,
                            top: activeSigHeight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (details) {
                                final RenderBox? renderBox = _activeSignatureKey.currentContext?.findRenderObject() as RenderBox?;
                                if (renderBox != null) {
                                  final Offset localCenter = Offset(renderBox.size.width / 2, renderBox.size.height / 2);
                                  final Offset globalCenter = renderBox.localToGlobal(localCenter);
                                  final double currentDistance = (details.globalPosition - globalCenter).distance;

                                  final double aspect = _signatureImage!.height / _signatureImage!.width;
                                  final double w = 2 * currentDistance / sqrt(1 + aspect * aspect);

                                  setState(() {
                                    _overlayRw = (w / W_page_zoomed).clamp(0.05, 0.9);
                                  });
                                }
                              },
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F46E5),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Floating Contextual Toolbar
              if (_signatureBytes != null && _signatureImage != null)
                Positioned(
                  left: toolbarLeft,
                  top: toolbarTop,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Delete
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          tooltip: getStr('delete_signature'),
                          onPressed: () {
                            setState(() {
                              _signatureBytes = null;
                              _signatureImage = null;
                              _signatureCaption = null;
                            });
                          },
                        ),
                        Container(height: 16, width: 1, color: Colors.grey[300]),
                        // Edit Caption
                        IconButton(
                          icon: const Icon(Icons.closed_caption_outlined, color: Color(0xFF4F46E5), size: 20),
                          tooltip: getStr('edit_caption'),
                          onPressed: () async {
                            final newCaption = await _promptCaption(context, _signatureCaption ?? '');
                            if (newCaption != null) {
                              setState(() {
                                _signatureCaption = newCaption;
                              });
                            }
                          },
                        ),
                        Container(height: 16, width: 1, color: Colors.grey[300]),
                        // Rotate
                        IconButton(
                          icon: const Icon(Icons.rotate_right, color: Color(0xFF4F46E5), size: 20),
                          tooltip: '╫í╫ץ╫ס╫ס 90┬░',
                          onPressed: () {
                            setState(() {
                              _overlayRotation = (_overlayRotation + pi / 2) % (2 * pi);
                            });
                          },
                        ),
                        Container(height: 16, width: 1, color: Colors.grey[300]),
                        // Confirm
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green, size: 20),
                          tooltip: getStr('save'),
                          onPressed: _confirmActiveSignaturePlacement,
                        ),
                      ],
                    ),
                  ),
                ),

              // Floating Page Number Indicator
              if (_pdfPageSizes.isNotEmpty)
                Positioned(
                  bottom: 24,
                  left: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      getStr('page_indicator')
                          .replaceAll('{current}', '$_currentPage')
                          .replaceAll('{total}', '${_pdfPageSizes.length}'),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignatureCropEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const SignatureCropEditorScreen({super.key, required this.imageBytes});

  @override
  State<SignatureCropEditorScreen> createState() => _SignatureCropEditorScreenState();
}

class _SignatureCropEditorScreenState extends State<SignatureCropEditorScreen> {
  ui.Image? _previewImage;
  Uint8List? _previewRawPixels;
  ui.Image? _processedPreviewImage;

  bool _isLoading = true;
  bool _isSaving = false;

  // Normalized Crop Bounding Box coordinates
  double cropLeft = 0.1;
  double cropTop = 0.1;
  double cropRight = 0.9;
  double cropBottom = 0.9;

  // Cleaning Settings
  double _thresholdValue = 180.0;
  String _inkColor = 'original'; // 'original', 'black', 'blue'

  int _activeCorner = -1; // 0: TL, 1: TR, 2: BL, 3: BR
  bool _isPanningBox = false;
  Offset _panStartNormalizedOffset = Offset.zero;

  bool _isProcessingPreview = false;
  bool _needsProcessAgain = false;

  @override
  void initState() {
    super.initState();
    _initImage();
  }

  Future<void> _initImage() async {
    try {
      // Decode original to find original dimensions
      final codecOriginal = await ui.instantiateImageCodec(widget.imageBytes);
      final frameOriginal = await codecOriginal.getNextFrame();
      final imageOriginal = frameOriginal.image;

      final int origW = imageOriginal.width;
      final int origH = imageOriginal.height;

      // Downsample to max dimension 600 for fast real-time preview processing
      int targetW = origW;
      int targetH = origH;
      if (origW > 600 || origH > 600) {
        if (origW > origH) {
          targetW = 600;
          targetH = (origH * (600 / origW)).round();
        } else {
          targetH = 600;
          targetW = (origW * (600 / origH)).round();
        }
      }

      final previewCodec = await ui.instantiateImageCodec(
        widget.imageBytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final previewFrame = await previewCodec.getNextFrame();
      final previewImage = previewFrame.image;

      final ByteData? bd = await previewImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bd == null) throw Exception("Could not read image byte data");

      _previewImage = previewImage;
      _previewRawPixels = bd.buffer.asUint8List();

      // Dynamic default threshold calculation
      double maxBrightness = 0;
      for (int i = 0; i < _previewRawPixels!.length; i += 4) {
        final double b = (_previewRawPixels![i] + _previewRawPixels![i + 1] + _previewRawPixels![i + 2]) / 3.0;
        if (b > maxBrightness) maxBrightness = b;
      }
      _thresholdValue = (maxBrightness - 45.0).clamp(100.0, 245.0);

      setState(() {
        _isLoading = false;
      });

      _triggerPreviewUpdate();
    } catch (e) {
      debugPrint('Error loading image in editor: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('╫⌐╫ע╫ש╫נ╫פ ╫ס╫ר╫ó╫ש╫á╫¬ ╫פ╫¬╫₧╫ץ╫á╫פ: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  void _triggerPreviewUpdate() {
    if (_isProcessingPreview) {
      _needsProcessAgain = true;
      return;
    }
    _isProcessingPreview = true;
    _updatePreview().then((_) {
      _isProcessingPreview = false;
      if (_needsProcessAgain) {
        _needsProcessAgain = false;
        _triggerPreviewUpdate();
      }
    });
  }

  Future<void> _updatePreview() async {
    if (_previewRawPixels == null || _previewImage == null) return;

    final int width = _previewImage!.width;
    final int height = _previewImage!.height;

    final int left = (cropLeft * width).round().clamp(0, width - 1);
    final int top = (cropTop * height).round().clamp(0, height - 1);
    final int right = (cropRight * width).round().clamp(0, width - 1);
    final int bottom = (cropBottom * height).round().clamp(0, height - 1);

    final int croppedWidth = right - left + 1;
    final int croppedHeight = bottom - top + 1;

    if (croppedWidth <= 0 || croppedHeight <= 0) return;

    final Uint8List destPixels = Uint8List(croppedWidth * croppedHeight * 4);

    for (int y = 0; y < croppedHeight; y++) {
      for (int x = 0; x < croppedWidth; x++) {
        final int srcOffset = ((y + top) * width + (x + left)) * 4;
        final int destOffset = (y * croppedWidth + x) * 4;

        final int r = _previewRawPixels![srcOffset];
        final int g = _previewRawPixels![srcOffset + 1];
        final int b = _previewRawPixels![srcOffset + 2];
        final int a = _previewRawPixels![srcOffset + 3];

        if (a < 10) {
          destPixels[destOffset] = 0;
          destPixels[destOffset + 1] = 0;
          destPixels[destOffset + 2] = 0;
          destPixels[destOffset + 3] = 0;
          continue;
        }

        final double brightness = (r + g + b) / 3.0;

        if (brightness > _thresholdValue) {
          destPixels[destOffset] = 0;
          destPixels[destOffset + 1] = 0;
          destPixels[destOffset + 2] = 0;
          destPixels[destOffset + 3] = 0;
        } else {
          final double fadeRange = 20.0;
          double alphaPercent = 1.0;
          if (_thresholdValue - brightness < fadeRange) {
            alphaPercent = (_thresholdValue - brightness) / fadeRange;
          }
          final int alpha = (alphaPercent * 255).round().clamp(0, 255);

          if (_inkColor == 'black') {
            destPixels[destOffset] = 0;
            destPixels[destOffset + 1] = 0;
            destPixels[destOffset + 2] = 0;
            destPixels[destOffset + 3] = alpha;
          } else if (_inkColor == 'blue') {
            destPixels[destOffset] = 16;
            destPixels[destOffset + 1] = 37;
            destPixels[destOffset + 2] = 122;
            destPixels[destOffset + 3] = alpha;
          } else {
            destPixels[destOffset] = r;
            destPixels[destOffset + 1] = g;
            destPixels[destOffset + 2] = b;
            destPixels[destOffset + 3] = alpha;
          }
        }
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      destPixels,
      croppedWidth,
      croppedHeight,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final processedImg = await completer.future;

    if (mounted) {
      setState(() {
        _processedPreviewImage = processedImg;
      });
    }
  }

  Future<Uint8List> _processFullImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final int width = image.width;
    final int height = image.height;

    final ByteData? bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return widget.imageBytes;

    final Uint8List pixels = bd.buffer.asUint8List();

    int left = (cropLeft * width).round().clamp(0, width - 1);
    int top = (cropTop * height).round().clamp(0, height - 1);
    int right = (cropRight * width).round().clamp(0, width - 1);
    int bottom = (cropBottom * height).round().clamp(0, height - 1);

    int croppedWidth = right - left + 1;
    int croppedHeight = bottom - top + 1;

    if (croppedWidth <= 0 || croppedHeight <= 0) return widget.imageBytes;

    final Uint8List destPixels = Uint8List(croppedWidth * croppedHeight * 4);

    for (int y = 0; y < croppedHeight; y++) {
      for (int x = 0; x < croppedWidth; x++) {
        final int srcOffset = ((y + top) * width + (x + left)) * 4;
        final int destOffset = (y * croppedWidth + x) * 4;

        final int r = pixels[srcOffset];
        final int g = pixels[srcOffset + 1];
        final int b = pixels[srcOffset + 2];
        final int a = pixels[srcOffset + 3];

        if (a < 10) {
          destPixels[destOffset] = 0;
          destPixels[destOffset + 1] = 0;
          destPixels[destOffset + 2] = 0;
          destPixels[destOffset + 3] = 0;
          continue;
        }

        final double brightness = (r + g + b) / 3.0;

        if (brightness > _thresholdValue) {
          destPixels[destOffset] = 0;
          destPixels[destOffset + 1] = 0;
          destPixels[destOffset + 2] = 0;
          destPixels[destOffset + 3] = 0;
        } else {
          final double fadeRange = 20.0;
          double alphaPercent = 1.0;
          if (_thresholdValue - brightness < fadeRange) {
            alphaPercent = (_thresholdValue - brightness) / fadeRange;
          }
          final int alpha = (alphaPercent * 255).round().clamp(0, 255);

          if (_inkColor == 'black') {
            destPixels[destOffset] = 0;
            destPixels[destOffset + 1] = 0;
            destPixels[destOffset + 2] = 0;
            destPixels[destOffset + 3] = alpha;
          } else if (_inkColor == 'blue') {
            destPixels[destOffset] = 16;
            destPixels[destOffset + 1] = 37;
            destPixels[destOffset + 2] = 122;
            destPixels[destOffset + 3] = alpha;
          } else {
            destPixels[destOffset] = r;
            destPixels[destOffset + 1] = g;
            destPixels[destOffset + 2] = b;
            destPixels[destOffset + 3] = alpha;
          }
        }
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      destPixels,
      croppedWidth,
      croppedHeight,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final croppedImage = await completer.future;

    final ByteData? pngData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    if (pngData == null) return widget.imageBytes;
    return pngData.buffer.asUint8List();
  }

  void _onSave() async {
    setState(() {
      _isSaving = true;
    });
    try {
      final processedBytes = await _processFullImage();
      if (mounted) {
        Navigator.pop(context, processedBytes);
      }
    } catch (e) {
      debugPrint('Error saving processed image: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('╫⌐╫ע╫ש╫נ╫פ ╫ס╫⌐╫₧╫ש╫¿╫¬ ╫פ╫¬╫₧╫ץ╫á╫פ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('╫ó╫¿╫ש╫¢╫פ ╫ץ╫á╫ש╫º╫ץ╫ש ╫¿╫º╫ó ╫פ╫ק╫¬╫ש╫₧╫פ'),
        centerTitle: true,
        actions: [
          if (!_isLoading && !_isSaving)
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green, size: 28),
              onPressed: _onSave,
              tooltip: '╫נ╫⌐╫¿ ╫ץ╫⌐╫₧╫ץ╫¿',
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Column(
                    children: [
                      // Top: Image Crop Editor
                      Expanded(
                        flex: 4,
                        child: Container(
                          color: const Color(0xFF121212),
                          width: double.infinity,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double viewW = constraints.maxWidth;
                              final double viewH = constraints.maxHeight;
                              final double imgW = _previewImage!.width.toDouble();
                              final double imgH = _previewImage!.height.toDouble();

                              final double scale = min(viewW / imgW, viewH / imgH);
                              final double renderedW = imgW * scale;
                              final double renderedH = imgH * scale;

                              final double leftMargin = (viewW - renderedW) / 2;
                              final double topMargin = (viewH - renderedH) / 2;

                              final double screenLeft = leftMargin + cropLeft * renderedW;
                              final double screenTop = topMargin + cropTop * renderedH;
                              final double screenRight = leftMargin + cropRight * renderedW;
                              final double screenBottom = topMargin + cropBottom * renderedH;

                              return GestureDetector(
                                onPanStart: (details) {
                                  final localPos = details.localPosition;
                                  final d0 = (localPos - Offset(screenLeft, screenTop)).distance;
                                  final d1 = (localPos - Offset(screenRight, screenTop)).distance;
                                  final d2 = (localPos - Offset(screenLeft, screenBottom)).distance;
                                  final d3 = (localPos - Offset(screenRight, screenBottom)).distance;

                                  double minDist = 30.0;
                                  int selected = -1;
                                  if (d0 < minDist) { minDist = d0; selected = 0; }
                                  if (d1 < minDist) { minDist = d1; selected = 1; }
                                  if (d2 < minDist) { minDist = d2; selected = 2; }
                                  if (d3 < minDist) { minDist = d3; selected = 3; }

                                  _activeCorner = selected;
                                  _isPanningBox = false;

                                  if (_activeCorner == -1) {
                                    // Check if the touch is inside the crop rect
                                    double normX = (localPos.dx - leftMargin) / renderedW;
                                    double normY = (localPos.dy - topMargin) / renderedH;
                                    if (normX > cropLeft && normX < cropRight && normY > cropTop && normY < cropBottom) {
                                      _isPanningBox = true;
                                      _panStartNormalizedOffset = Offset(normX - cropLeft, normY - cropTop);
                                    }
                                  }
                                },
                                onPanUpdate: (details) {
                                  final localPos = details.localPosition;
                                  if (_activeCorner != -1) {
                                    double normX = (localPos.dx - leftMargin) / renderedW;
                                    double normY = (localPos.dy - topMargin) / renderedH;
                                    normX = normX.clamp(0.0, 1.0);
                                    normY = normY.clamp(0.0, 1.0);

                                    setState(() {
                                      if (_activeCorner == 0) {
                                        cropLeft = min(normX, cropRight - 0.1);
                                        cropTop = min(normY, cropBottom - 0.1);
                                      } else if (_activeCorner == 1) {
                                        cropRight = max(normX, cropLeft + 0.1);
                                        cropTop = min(normY, cropBottom - 0.1);
                                      } else if (_activeCorner == 2) {
                                        cropLeft = min(normX, cropRight - 0.1);
                                        cropBottom = max(normY, cropTop + 0.1);
                                      } else if (_activeCorner == 3) {
                                        cropRight = max(normX, cropLeft + 0.1);
                                        cropBottom = max(normY, cropTop + 0.1);
                                      }
                                    });
                                    _triggerPreviewUpdate();
                                  } else if (_isPanningBox) {
                                    double normX = (localPos.dx - leftMargin) / renderedW;
                                    double normY = (localPos.dy - topMargin) / renderedH;

                                    double width = cropRight - cropLeft;
                                    double height = cropBottom - cropTop;

                                    double newLeft = (normX - _panStartNormalizedOffset.dx).clamp(0.0, 1.0 - width);
                                    double newTop = (normY - _panStartNormalizedOffset.dy).clamp(0.0, 1.0 - height);

                                    setState(() {
                                      cropLeft = newLeft;
                                      cropTop = newTop;
                                      cropRight = newLeft + width;
                                      cropBottom = newTop + height;
                                    });
                                    _triggerPreviewUpdate();
                                  }
                                },
                                child: Stack(
                                  children: [
                                    Center(
                                      child: RawImage(
                                        image: _previewImage,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: CropOverlayPainter(
                                          cropLeft: cropLeft,
                                          cropTop: cropTop,
                                          cropRight: cropRight,
                                          cropBottom: cropBottom,
                                          leftMargin: leftMargin,
                                          topMargin: topMargin,
                                          renderedW: renderedW,
                                          renderedH: renderedH,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Bottom: Controls & Preview
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Ink color picker
                              const Text(
                                '╫ס╫ק╫¿ ╫ª╫ס╫ó ╫ף╫ש╫ץ:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _inkColorButton('╫₧╫º╫ץ╫¿╫ש', 'original'),
                                  const SizedBox(width: 8),
                                  _inkColorButton('╫⌐╫ק╫ץ╫¿', 'black'),
                                  const SizedBox(width: 8),
                                  _inkColorButton('╫¢╫ק╫ץ╫£', 'blue'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // 2. Sensitivity Slider
                              const Text(
                                '╫¿╫ע╫ש╫⌐╫ץ╫¬ ╫á╫ש╫º╫ץ╫ש ╫¿╫º╫ó:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textDirection: TextDirection.rtl,
                              ),
                              Slider(
                                value: _thresholdValue,
                                min: 50.0,
                                max: 250.0,
                                onChanged: (val) {
                                  setState(() {
                                    _thresholdValue = val;
                                  });
                                  _triggerPreviewUpdate();
                                },
                              ),
                              const SizedBox(height: 8),
                              // 3. Live Preview
                              const Text(
                                '╫¬╫ª╫ץ╫ע╫פ ╫₧╫º╫ף╫ש╫₧╫פ (╫⌐╫º╫ץ╫ú):',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CustomPaint(
                                    painter: CheckerboardPainter(),
                                    child: Container(
                                      width: double.infinity,
                                      alignment: Alignment.center,
                                      child: _processedPreviewImage != null
                                          ? RawImage(
                                              image: _processedPreviewImage,
                                              fit: BoxFit.contain,
                                            )
                                          : const CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isSaving)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              '╫⌐╫ץ╫₧╫¿ ╫ץ╫₧╫á╫º╫פ ╫ק╫¬╫ש╫₧╫פ...',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _inkColorButton(String text, String value) {
    final isSelected = _inkColor == value;
    return Expanded(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          foregroundColor: isSelected ? Colors.white : Colors.black87,
          elevation: isSelected ? 3 : 0,
        ),
        onPressed: () {
          setState(() {
            _inkColor = value;
          });
          _triggerPreviewUpdate();
        },
        child: Text(text),
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final double cropLeft;
  final double cropTop;
  final double cropRight;
  final double cropBottom;
  final double leftMargin;
  final double topMargin;
  final double renderedW;
  final double renderedH;

  CropOverlayPainter({
    required this.cropLeft,
    required this.cropTop,
    required this.cropRight,
    required this.cropBottom,
    required this.leftMargin,
    required this.topMargin,
    required this.renderedW,
    required this.renderedH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double screenLeft = leftMargin + cropLeft * renderedW;
    final double screenTop = topMargin + cropTop * renderedH;
    final double screenRight = leftMargin + cropRight * renderedW;
    final double screenBottom = topMargin + cropBottom * renderedH;

    final Paint dimPaint = Paint()..color = Colors.black54;

    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, screenTop), dimPaint);
    canvas.drawRect(Rect.fromLTRB(0, screenBottom, size.width, size.height), dimPaint);
    canvas.drawRect(Rect.fromLTRB(0, screenTop, screenLeft, screenBottom), dimPaint);
    canvas.drawRect(Rect.fromLTRB(screenRight, screenTop, size.width, screenBottom), dimPaint);

    final Paint borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(Rect.fromLTRB(screenLeft, screenTop, screenRight, screenBottom), borderPaint);

    final Paint cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final Paint cornerOutlinePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double radius = 8.0;
    final List<Offset> corners = [
      Offset(screenLeft, screenTop),
      Offset(screenRight, screenTop),
      Offset(screenLeft, screenBottom),
      Offset(screenRight, screenBottom),
    ];

    for (var corner in corners) {
      canvas.drawCircle(corner, radius, cornerPaint);
      canvas.drawCircle(corner, radius, cornerOutlinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.cropLeft != cropLeft ||
        oldDelegate.cropTop != cropTop ||
        oldDelegate.cropRight != cropRight ||
        oldDelegate.cropBottom != cropBottom ||
        oldDelegate.leftMargin != leftMargin ||
        oldDelegate.topMargin != topMargin ||
        oldDelegate.renderedW != renderedW ||
        oldDelegate.renderedH != renderedH;
  }
}

class CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = const Color(0xFFE0E0E0);
    final paint2 = Paint()..color = const Color(0xFFF5F5F5);
    const double squareSize = 10.0;

    for (double y = 0; y < size.height; y += squareSize) {
      for (double x = 0; x < size.width; x += squareSize) {
        final paint = ((x / squareSize).floor() + (y / squareSize).floor()) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(Rect.fromLTWH(x, y, squareSize, squareSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<File> _archivedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchiveFiles();
  }

  Future<void> _loadArchiveFiles() async {
    setState(() => _isLoading = true);
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final archiveDir = Directory('${docDir.path}/archive');
      if (await archiveDir.exists()) {
        final list = archiveDir.listSync();
        final List<File> files = [];
        for (var item in list) {
          if (item is File && item.path.endsWith('.pdf')) {
            files.add(item);
          }
        }
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        setState(() {
          _archivedFiles = files;
        });
      }
    } catch (e) {
      debugPrint('Error loading archive: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Directionality(
        textDirection: appLanguage.value == 'he' ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          title: Text(getStr('delete_confirm_title')),
          content: Text(getStr('delete_confirm_desc')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(getStr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(getStr('delete')),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
        _loadArchiveFiles();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('╫⌐╫ע╫ש╫נ╫פ ╫ס╫₧╫ק╫ש╫º╫פ: $e')),
        );
      }
    }
  }

  // Extracted formatSize, formatDateTime and getDisplayName to global functions

  @override
  Widget build(BuildContext context) {
    final isRtl = appLanguage.value == 'he';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(getStr('archive_title')),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _archivedFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.archive_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          getStr('no_archived_files'),
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _archivedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _archivedFiles[index];
                      final name = getPdfDisplayName(file);
                      final sizeStr = formatFileSize(file.lengthSync());
                      final dateStr = formatDateTime(file.lastModifiedSync());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE0E7FF),
                            child: Icon(Icons.picture_as_pdf, color: Color(0xFF4F46E5)),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Text('${getStr('file_size')} $sizeStr'),
                                const SizedBox(width: 16),
                                Text('${getStr('file_date')} $dateStr'),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share, color: Color(0xFF4F46E5)),
                                onPressed: () {
                                  Share.shareXFiles([XFile(file.path)]);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteFile(file),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PdfReaderScreen(file: file, displayName: name),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class PdfReaderScreen extends StatelessWidget {
  final File file;
  final String displayName;

  const PdfReaderScreen({super.key, required this.file, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final isRtl = appLanguage.value == 'he';
    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(displayName),
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Share.shareXFiles([XFile(file.path)]);
              },
            ),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.ltr,
          child: SfPdfViewer.file(
            file,
            canShowScrollHead: false,
            enableTextSelection: false,
            enableDocumentLinkAnnotation: false,
          ),
        ),
      ),
    );
  }
}
