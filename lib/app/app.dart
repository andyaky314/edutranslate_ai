import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/app_strings.dart';
import '../core/languages.dart';
import '../core/learning_level.dart';
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
  String _appLanguageCode = 'system';
  ThemeMode _themeMode = ThemeMode.system;
  LearningLevel _learningLevel = LearningLevel.standard;
  bool _preferencesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

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

  Future<void> _loadPreferences() async {
    try {
      final repository = await _repository;
      var languageCode = await repository.getSetting('appLanguage');
      languageCode ??= await repository.getSetting('preferredLanguage') ?? 'system';
      if (languageCode != 'system') AppLanguage.fromCode(languageCode);

      final savedTheme = await repository.getSetting('themeMode') ?? 'system';
      final themeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

      var savedLevel = await repository.getSetting('learningLevel');
      if (savedLevel == null) {
        final oldYear = await repository.getSetting('preferredYearLevel');
        final year = int.tryParse(oldYear ?? '');
        savedLevel = year != null && year <= 3
            ? LearningLevel.lowerPrimary.code
            : year != null && year >= 4 && year <= 6
            ? LearningLevel.upperPrimary.code
            : LearningLevel.standard.code;
      }
      final learningLevel = LearningLevel.fromCode(savedLevel);

      if (mounted) {
        setState(() {
          _appLanguageCode = languageCode!;
          _themeMode = themeMode;
          _learningLevel = learningLevel;
          _preferencesLoaded = true;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Could not load settings: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _preferencesLoaded = true);
    }
  }

  void _setAppLanguage(String code) => setState(() => _appLanguageCode = code);

  void _setThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);

  void _setLearningLevel(LearningLevel level) =>
      setState(() => _learningLevel = level);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduTranslate',
      debugShowCheckedModeBanner: false,
      locale: _appLanguageCode == 'system' ? null : Locale(_appLanguageCode),
      supportedLocales: const [Locale('en'), Locale('ms'), Locale('zh')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: _themeMode,
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
          if (!_preferencesLoaded) {
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
            appLanguageCode: _appLanguageCode,
            learningLevel: _learningLevel,
            themeMode: _themeMode,
            onAppLanguageChanged: _setAppLanguage,
            onLearningLevelChanged: _setLearningLevel,
            onThemeModeChanged: _setThemeMode,
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
    required this.appLanguageCode,
    required this.learningLevel,
    required this.themeMode,
    required this.onAppLanguageChanged,
    required this.onLearningLevelChanged,
    required this.onThemeModeChanged,
    super.key,
  });

  final LearningRepository repository;
  final TranslatorService translatorService;
  final String appLanguageCode;
  final LearningLevel learningLevel;
  final ThemeMode themeMode;
  final ValueChanged<String> onAppLanguageChanged;
  final ValueChanged<LearningLevel> onLearningLevelChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<LearningShell> createState() => _LearningShellState();
}

class _LearningShellState extends State<LearningShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final localeLanguage = Localizations.localeOf(context).languageCode;
    final preferredLanguage = AppLanguage.fromCode(
      AppLanguage.all.any((language) => language.code == localeLanguage)
          ? localeLanguage
          : AppLanguage.english.code,
    );
    final strings = AppStrings.of(context);
    final pages = [
      TranslatorScreen(
        service: widget.translatorService,
        repository: widget.repository,
        preferredLanguage: preferredLanguage,
        learningLevel: widget.learningLevel,
        key: ValueKey(
          'translate-${preferredLanguage.code}-${widget.learningLevel.code}',
        ),
      ),
      VocabularyScreen(repository: widget.repository),
      FlashcardsScreen(repository: widget.repository),
      HistoryScreen(repository: widget.repository),
      SettingsScreen(
        repository: widget.repository,
        appLanguageCode: widget.appLanguageCode,
        learningLevel: widget.learningLevel,
        themeMode: widget.themeMode,
        onAppLanguageChanged: widget.onAppLanguageChanged,
        onLearningLevelChanged: widget.onLearningLevelChanged,
        onThemeModeChanged: widget.onThemeModeChanged,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          [
            strings.text('translate'),
            strings.text('words'),
            strings.text('cards'),
            strings.text('history'),
            strings.text('settings'),
          ][_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.translate_outlined),
            selectedIcon: Icon(Icons.translate),
            label: strings.text('translate'),
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: strings.text('words'),
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: strings.text('cards'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: strings.text('history'),
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: strings.text('settings'),
          ),
        ],
      ),
    );
  }
}
