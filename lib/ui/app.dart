import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/job_repository.dart';
import '../state/job_controller.dart';
import 'home_page.dart';

class MeadowRepairsApp extends StatefulWidget {
  const MeadowRepairsApp({super.key});

  @override
  State<MeadowRepairsApp> createState() => _MeadowRepairsAppState();
}

class _MeadowRepairsAppState extends State<MeadowRepairsApp> {
  late Future<JobController> _controller;

  @override
  void initState() {
    super.initState();
    _controller = _loadController();
  }

  Future<JobController> _loadController() async {
    // const apiUrl = String.fromEnvironment('MEADOW_API_URL');
    const apiUrl = "https://hack.danieldb.uk";
    const apiToken = String.fromEnvironment('MEADOW_API_TOKEN');
    if (apiUrl.isEmpty) {
      throw StateError(
        'Backend URL is not configured. Set MEADOW_API_URL when running or building the app.',
      );
    }
    final uri = Uri.tryParse(apiUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        !uri.hasScheme ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw StateError(
        'MEADOW_API_URL must be an absolute http:// or https:// URL.',
      );
    }
    final controller = JobController(
      ApiJobRepository(baseUri: uri, token: apiToken),
    );
    try {
      await controller.load();
      return controller;
    } catch (_) {
      controller.dispose();
      rethrow;
    }
  }

  void _retryLoad() {
    setState(() => _controller = _loadController());
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF477548),
      brightness: brightness,
      primary: const Color(0xFF35633B),
      secondary: const Color(0xFF786000),
      surface: brightness == Brightness.light
          ? const Color(0xFFF7F8F0)
          : const Color(0xFF151A15),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: GoogleFonts.lexendTextTheme().copyWith(
        headlineLarge: GoogleFonts.lexend(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        headlineMedium: GoogleFonts.lexend(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        titleLarge: GoogleFonts.lexend(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: GoogleFonts.lexend(fontSize: 16),
        bodyMedium: GoogleFonts.lexend(fontSize: 14),
        bodySmall: GoogleFonts.lexend(fontSize: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        margin: EdgeInsets.zero,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.lexend(fontWeight: FontWeight.w600),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Meadow House Repairs',
    debugShowCheckedModeBanner: false,
    theme: _theme(Brightness.light),
    darkTheme: _theme(Brightness.dark),
    themeMode: ThemeMode.system,
    home: FutureBuilder<JobController>(
      future: _controller,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 42,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Can’t connect to the repairs server',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _retryLoad,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry connection'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading repair jobs',
              ),
            ),
          );
        }
        return HomePage(controller: snapshot.data!);
      },
    ),
  );
}
