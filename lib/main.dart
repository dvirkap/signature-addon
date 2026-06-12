import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:mime/mime.dart';

// Global server instance to handle lifecycle and PDF sharing
late LocalServer localServer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  localServer = LocalServer();
  await localServer.start();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'פשוט לחתום',
      debugShowCheckedModeBanner: false,
      locale: const Locale('he', 'IL'),
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Assistant',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5), // Premium Indigo
          primary: const Color(0xFF4F46E5),
          secondary: const Color(0xFF10B981), // Emerald
          background: const Color(0xFFF8FAFC),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          bodyLarge: TextStyle(fontSize: 16),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Assistant',
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8), // Sky Blue for Dark Theme
          primary: const Color(0xFF38BDF8),
          secondary: const Color(0xFF10B981),
          background: const Color(0xFF0F172A),
          brightness: Brightness.dark,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.system, // Dark/Light adaptively
      home: const DashboardScreen(),
    );
  }
}

/// A lightweight local HTTP server using shelf to bypass CORS and file-access limitations in WebView.
class LocalServer {
  HttpServer? _server;
  int? get port => _server?.port;
  Uint8List? currentPdfBytes;
  String currentPdfName = 'document.pdf';

  Future<void> start() async {
    final router = shelf_router.Router();

    // Serves the active PDF document bytes
    router.get('/pdf', (Request request) {
      if (currentPdfBytes == null) {
        return Response.notFound('No PDF loaded');
      }
      return Response.ok(
        currentPdfBytes,
        headers: {
          'Content-Type': 'application/pdf',
          'Content-Disposition': 'inline; filename="$currentPdfName"',
          'Access-Control-Allow-Origin': '*',
        },
      );
    });

    // Serves static assets from assets/www directory
    router.all('/<path|.*>', (Request request, String path) async {
      var file = path;
      if (file.isEmpty || file == '/') {
        file = 'editor.html';
      }

      final assetPath = 'assets/www/$file';
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List();
        final mimeType = lookupMimeType(file) ?? 'application/octet-stream';
        
        return Response.ok(
          bytes,
          headers: {
            'Content-Type': mimeType,
            'Access-Control-Allow-Origin': '*',
          },
        );
      } catch (e) {
        return Response.notFound('Asset not found: $file');
      }
    });

    _server = await shelf_io.serve(router, '127.0.0.1', 0);
    print('Shelf server running on http://127.0.0.1:${_server!.port}');
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}

/// Premium main dashboard screen with elegant glassmorphic cards and micro-animations.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleIncomingIntent();
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

  // Hook to handle PDF files opened directly from WhatsApp, file managers, or external intents
  Future<void> _handleIncomingIntent() async {
    // Note: Intent filters are processed by the native MainActivity and passed to Dart.
    // In Dart, we can use MethodChannels to retrieve intent details.
    const channel = MethodChannel('com.example.signature_addon/intent');
    try {
      final Map? intentData = await channel.invokeMethod('getIncomingIntent');
      if (intentData != null && intentData['filePath'] != null) {
        final String path = intentData['filePath'];
        final String name = intentData['fileName'] ?? 'document.pdf';
        final file = File(path);
        if (await file.exists()) {
          setState(() {
            _isLoading = true;
          });
          final bytes = await file.readAsBytes();
          _openEditor(bytes, name);
        }
      }
    } catch (e) {
      print('Error handling incoming intent: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickPdfFile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final name = result.files.single.name;
        _openEditor(bytes, name);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בבחירת הקובץ: $e', textDirection: TextDirection.rtl),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openEditor(Uint8List bytes, String name) {
    localServer.currentPdfBytes = bytes;
    localServer.currentPdfName = name;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const EditorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF1E1E38)]
                    : [const Color(0xFFEEF2F6), const Color(0xFFE2E8F0)],
              ),
            ),
          ),
          // Decorative Glowing Orb
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(isDark ? 0.12 : 0.08),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  // Logo and Title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '✒️',
                            style: TextStyle(fontSize: 48, color: theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'פשוט לחתום',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 32,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'עריכה וחתימה על מסמכים ללא הגבלה',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Feature Cards
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildFeatureItem(
                            context,
                            icon: '📂',
                            title: 'חתימה מהירה על PDF',
                            subtitle: 'טען מסמך PDF מהמכשיר והוסף חתימות וחותמות בקלות.',
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureItem(
                            context,
                            icon: '📷',
                            title: 'סרוק חתימה פיזית',
                            subtitle: 'צלם חתימה מנייר והפוך אותה לחותמת דיגיטלית שקופה בשניות.',
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureItem(
                            context,
                            icon: '⚡',
                            title: 'פתיחה ישירה מכל אפליקציה',
                            subtitle: 'הגדר כמציג PDF ברירת מחדל ופתח קבצים ישירות מהוואטסאפ או המייל.',
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Loading or Buttons Area
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickPdfFile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text(
                            'טען קובץ PDF לחתימה',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              textDirection: TextDirection.rtl,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The main hybrid editor view containing the WebView and Javascript channel listener.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    final url = 'http://127.0.0.1:${localServer.port}/editor.html?file=http://127.0.0.1:${localServer.port}/pdf';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterJustSign',
        onMessageReceived: _handleJsMessage,
      )
      ..loadRequest(Uri.parse(url));
  }

  void _handleJsMessage(JavaScriptMessage message) async {
    try {
      final data = jsonDecode(message.message);
      final action = data['action'];
      if (action == 'share') {
        final fileName = data['fileName'] ?? 'signed_document.pdf';
        final base64Data = data['data'] as String;
        final bytes = base64Decode(base64Data);

        // Save bytes to temp directory
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        // Launch native share sheet
        await Share.shareXFiles(
          [XFile(file.path, name: fileName)],
          text: 'הנה המסמך החתום שלך מ-"פשוט לחתום"',
        );
      }
    } catch (e) {
      print('Error handling message from WebView: $e');
    }
  }

  Future<void> _scanSignatureFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final mimeType = lookupMimeType(image.path) ?? 'image/jpeg';
        final dataUrl = 'data:$mimeType;base64,$base64String';

        // Inject image directly into the signature creator tab inside WebView
        await _controller.runJavaScript('if (window.handleScannedSignatureImage) { window.handleScannedSignatureImage("$dataUrl"); }');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('שגיאה בצילום חתימה: $e', textDirection: TextDirection.rtl),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('לצאת מהעריכה?', textDirection: TextDirection.rtl),
        content: const Text(
          'כל השינויים והחתימות שביצעת על גבי המסמך הנוכחי יימחקו.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ביטול'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('צא ללא שמירה'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(localServer.currentPdfName, style: const TextStyle(fontSize: 16)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined),
              tooltip: 'סרוק חתימה/חותמת',
              onPressed: _scanSignatureFromCamera,
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
