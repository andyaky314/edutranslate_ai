import 'package:flutter/material.dart';

import '../core/languages.dart';
import '../data/local/app_database.dart';
import '../data/repositories/learning_repository.dart';
import '../data/repositories/sqlite_learning_repository.dart';
import '../features/flashcards/screens/flashcards_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/translator/screens/translator_screen.dart';
import '../features/translator/services/translator_service.dart';
import '../features/vocabulary/screens/vocabulary_screen.dart';

class EduTranslateApp extends StatefulWidget {
  const EduTranslateApp({super.key});

  @override
  State<EduTranslateApp> createState() => _EduTranslateAppState();
}

class _EduTranslateAppState extends State<EduTranslateApp> {
  late final Future<LearningRepository> _repository = _openRepository();

  Future<LearningRepository> _openRepository() async {
    try {
      final appDatabase = await AppDatabase.open();
      return SqliteLearningRepository(appDatabase.database);
    } catch (error, stackTrace) {
      debugPrint('Could not initialize EduTranslate storage: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduTranslate',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: FutureBuilder<LearningRepository>(
        future: _repository,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _StartupError();
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final repository = snapshot.data!;
          final service = TranslatorService(
            provider: GeminiTranslationProvider(),
            repository: repository,
          );
          return LearningShell(
            repository: repository,
            translatorService: service,
          );
        },
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff6048d8),
    brightness: brightness,
    surface: isDark ? const Color(0xff171629) : const Color(0xfffffbff),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xff12111f)
        : const Color(0xfffff8ef),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: isDark ? scheme.surface : const Color(0xfffff1dc),
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage_rounded, size: 44),
              const SizedBox(height: 16),
              const Text(
                'EduTranslate could not open its local learning database.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Restart the app. If the problem continues, ask an adult for help.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LearningShell extends StatefulWidget {
  const LearningShell({
    required this.repository,
    required this.translatorService,
    super.key,
  });

  final LearningRepository repository;
  final TranslatorService translatorService;

  @override
  State<LearningShell> createState() => _LearningShellState();
}

class _LearningShellState extends State<LearningShell> {
  static const _titles = [
    'Translate',
    'My words',
    'Flashcards',
    'History',
    'Settings',
  ];

  int _selectedIndex = 0;
  String _preferredLanguageCode = 'en';
  int? _preferredYearLevel;

  @override
  void initState() {
    super.initState();
    _loadPreferredLanguage();
  }

  Future<void> _loadPreferredLanguage() async {
    try {
      final saved = await widget.repository.getSetting('preferredLanguage');
      if (saved != null) {
        AppLanguage.fromCode(saved);
        if (mounted) setState(() => _preferredLanguageCode = saved);
      }
      final savedYear = await widget.repository.getSetting(
        'preferredYearLevel',
      );
      final parsedYear = savedYear == null || savedYear == 'all'
          ? null
          : int.tryParse(savedYear);
      if (savedYear != null &&
          savedYear != 'all' &&
          (parsedYear == null || parsedYear < 1 || parsedYear > 6)) {
        throw FormatException('Unsupported preferred year level: $savedYear');
      }
      if (mounted) setState(() => _preferredYearLevel = parsedYear);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load learning preferences: $error'),
          ),
        );
      }
    }
  }

  void _setPreferredLanguage(AppLanguage language) {
    setState(() => _preferredLanguageCode = language.code);
  }

  void _setPreferredYearLevel(int? yearLevel) {
    setState(() => _preferredYearLevel = yearLevel);
  }

  @override
  Widget build(BuildContext context) {
    final preferredLanguage = AppLanguage.fromCode(_preferredLanguageCode);
    final pages = [
      TranslatorScreen(
        service: widget.translatorService,
        repository: widget.repository,
        preferredLanguage: preferredLanguage,
        preferredYearLevel: _preferredYearLevel,
        key: ValueKey(
          'translate-${preferredLanguage.code}-${_preferredYearLevel ?? 'all'}',
        ),
      ),
      VocabularyScreen(repository: widget.repository),
      FlashcardsScreen(repository: widget.repository),
      HistoryScreen(repository: widget.repository),
      SettingsScreen(
        repository: widget.repository,
        preferredLanguage: preferredLanguage,
        preferredYearLevel: _preferredYearLevel,
        onLanguageChanged: _setPreferredLanguage,
        onYearLevelChanged: _setPreferredYearLevel,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.translate_outlined),
            selectedIcon: Icon(Icons.translate),
            label: 'Translate',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Words',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Cards',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
