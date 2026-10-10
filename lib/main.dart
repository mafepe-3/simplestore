import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_services.dart';
import 'app_storage.dart';
import 'product_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await PersistentStateStorage.create();
  final state = AppState(storage: storage);
  await state.restoreState();
  runApp(SimpleStoreApp(initialState: state));
}

// =============================================================================
// BLOQUE 01 · MARCA Y TEMA
// =============================================================================

class AppColors {
  static const primary = Color(0xFF2563EB);
  static const ink = Color(0xFF111827);
  static const paleBlue = Color(0xFFDBEAFE);
  static const slate = Color(0xFF64748B);
  static const background = Color(0xFFF8FAFC);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF111C2E);
}

// ── Función de configuración del tema ─────────────────────────────────────────
ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final border = dark ? const Color(0xFF2A3A52) : const Color(0xFFE2E8F0);
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
    surface: dark ? AppColors.darkSurface : Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Arial',
    colorScheme: scheme.copyWith(
      primary: AppColors.primary,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: dark
        ? AppColors.darkBackground
        : AppColors.background,
    dividerColor: border,
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? AppColors.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF18253A) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

// =============================================================================
// BLOQUE 02 · ESTADO GENERAL DE LA SESIÓN
// Las acciones específicas se ubican junto a la sección que las utiliza.
// =============================================================================

enum AppSection { home, search, comparison, favorites, history }

class AppState extends ChangeNotifier {
  // ── Servicios compartidos ───────────────────────────────────────────────────
  final SearchService _searchService = const SearchService();
  final StateStorage _storage;
  Timer? _saveTimer;

  // ── Navegación y apariencia ─────────────────────────────────────────────────
  AppSection section = AppSection.home;
  ThemeMode themeMode = ThemeMode.light;

  // ── Estado de búsqueda ──────────────────────────────────────────────────────
  String query = 'Samsung Galaxy A55';
  String searchDraft = 'Samsung Galaxy A55';
  SearchFilters filters = const SearchFilters();
  List<Product> results = const [];

  // ── Borradores de la pantalla de inicio ─────────────────────────────────────
  String homeSearchDraft = 'Samsung Galaxy A55';
  String homeUrlDraft = '';

  // ── Datos guardados durante la sesión ───────────────────────────────────────
  final favoriteIds = <String>{};
  final comparisonIds = <String>{};
  final history = <SearchRecord>[];

  // ── Inicialización ───────────────────────────────────────────────────────────
  AppState({StateStorage? storage})
    : _storage = storage ?? MemoryStateStorage();

  // ── Acciones globales ───────────────────────────────────────────────────────
  void navigate(AppSection next) {
    if (section == AppSection.search && next != AppSection.search) {
      results = const [];
    }

    section = next;

    if (next == AppSection.search && results.isEmpty) {
      results = _searchService.search(query, filters);
    }
    _refresh();
  }

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _refresh();
  }

  // ── Función interna para acciones ubicadas en otros bloques ─────────────────
  void _refresh() {
    notifyListeners();
    _scheduleSave();
  }

  void _saveWithoutRebuild() {
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), persistState);
  }

  Future<void> persistState() async {
    _saveTimer?.cancel();
    await _storage.write(jsonEncode(toStateJson()));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(persistState());
    super.dispose();
  }
}

// =============================================================================
// BLOQUE 03 · PERSISTENCIA DEL ESTADO EN JSON
// =============================================================================

extension StatePersistence on AppState {
  // ── Lectura del JSON al iniciar la aplicación ────────────────────────────────
  Future<void> restoreState() async {
    final savedJson = await _storage.read();
    if (savedJson == null || savedJson.isEmpty) return;

    try {
      final decoded = jsonDecode(savedJson);
      if (decoded is! Map<String, dynamic>) return;
      _restoreAppState(decoded);
      results = section == AppSection.search
          ? _searchService.search(query, filters)
          : const [];
    } catch (_) {
      // Si el JSON está dañado se conservan los valores iniciales seguros.
      await persistState();
    }
  }

  // ── Escritura de todo el estado serializable ────────────────────────────────
  Map<String, dynamic> toStateJson() {
    return {
      'version': 1,
      'app': {'section': section.name, 'themeMode': themeMode.name},
      'screens': {
        'home': {'searchDraft': homeSearchDraft, 'urlDraft': homeUrlDraft},
        'search': {
          'query': query,
          'draft': searchDraft,
          'filters': {
            'minPrice': filters.minPrice,
            'maxPrice': filters.maxPrice,
            'maxTotal': filters.maxTotal,
            'storeIds': filters.storeIds.toList(),
            'features': filters.features,
            'sortOrder': filters.sortOrder.name,
          },
        },
        'comparison': {'productIds': comparisonIds.toList()},
        'favorites': {'productIds': favoriteIds.toList()},
        'history': {
          'items': history
              .take(50)
              .map(
                (item) => {
                  'query': item.query,
                  'resultCount': item.resultCount,
                  'createdAt': item.createdAt.toIso8601String(),
                },
              )
              .toList(),
        },
      },
    };
  }

  // ── Funciones auxiliares de restauración ────────────────────────────────────
  void _restoreAppState(Map<String, dynamic> json) {
    final app = _map(json['app']);
    final screens = _map(json['screens']);
    final home = _map(screens['home']);
    final search = _map(screens['search']);
    final comparison = _map(screens['comparison']);
    final favoritesJson = _map(screens['favorites']);
    final historyJson = _map(screens['history']);

    section = _enumByName(AppSection.values, app['section'], AppSection.home);
    themeMode = _enumByName(
      ThemeMode.values,
      app['themeMode'],
      ThemeMode.light,
    );
    homeSearchDraft = _text(home['searchDraft'], homeSearchDraft);
    homeUrlDraft = _text(home['urlDraft'], homeUrlDraft);
    query = _text(search['query'], query);
    searchDraft = _text(search['draft'], query);
    filters = _restoreFilters(_map(search['filters']));

    final validIds = mockProducts.map((product) => product.id).toSet();
    comparisonIds
      ..clear()
      ..addAll(_stringSet(comparison['productIds']).intersection(validIds));
    favoriteIds
      ..clear()
      ..addAll(_stringSet(favoritesJson['productIds']).intersection(validIds));

    history
      ..clear()
      ..addAll(_restoreHistory(historyJson['items']));
  }

  SearchFilters _restoreFilters(Map<String, dynamic> json) {
    return SearchFilters(
      minPrice: _number(json['minPrice']),
      maxPrice: _number(json['maxPrice']),
      maxTotal: _number(json['maxTotal']),
      storeIds: _stringSet(json['storeIds']),
      features: _stringMap(json['features']),
      sortOrder: _enumByName(
        SortOrder.values,
        json['sortOrder'],
        SortOrder.lowestTotal,
      ),
    );
  }

  List<SearchRecord> _restoreHistory(Object? value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((rawItem) {
          final item = rawItem.map((key, value) => MapEntry('$key', value));
          return SearchRecord(
            query: _text(item['query'], ''),
            resultCount: (item['resultCount'] as num?)?.toInt() ?? 0,
            createdAt:
                DateTime.tryParse('${item['createdAt']}') ?? DateTime.now(),
          );
        })
        .where((item) => item.query.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is! Map) return {};
    return value.map((key, value) => MapEntry('$key', value));
  }

  Map<String, String> _stringMap(Object? value) {
    return _map(value).map((key, value) => MapEntry(key, '$value'));
  }

  Set<String> _stringSet(Object? value) {
    return value is List ? value.map((item) => '$item').toSet() : {};
  }

  double? _number(Object? value) => value is num ? value.toDouble() : null;

  String _text(Object? value, String fallback) {
    return value is String ? value : fallback;
  }

  T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

// =============================================================================
// BLOQUE 04 · APLICACIÓN Y NAVEGACIÓN
// =============================================================================

class SimpleStoreApp extends StatefulWidget {
  const SimpleStoreApp({super.key, this.initialState});

  final AppState? initialState;

  @override
  State<SimpleStoreApp> createState() => _SimpleStoreAppState();
}

class _SimpleStoreAppState extends State<SimpleStoreApp>
    with WidgetsBindingObserver {
  // ── Estado raíz ─────────────────────────────────────────────────────────────
  late final AppState state;

  // ── Ciclo de vida ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    state = widget.initialState ?? AppState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState != AppLifecycleState.resumed) {
      unawaited(state.persistState());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    super.dispose();
  }

  // ── Construcción de la aplicación ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        title: 'SimpleStore',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: state.themeMode,
        home: AppShell(state: state),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.state});
  final AppState state;

  // ── Selección de contenido ──────────────────────────────────────────────────
  Widget activeSubApplication() => switch (state.section) {
    AppSection.home => HomeSubApp(state: state),
    AppSection.search => SearchSubApp(state: state),
    AppSection.comparison => ComparisonSubApp(state: state),
    AppSection.favorites => FavoritesSubApp(state: state),
    AppSection.history => HistorySubApp(state: state),
  };

  String currentTitle() => switch (state.section) {
    AppSection.home => 'Inicio',
    AppSection.search => 'Buscar productos',
    AppSection.comparison => 'Comparaciones',
    AppSection.favorites => 'Favoritos',
    AppSection.history => 'Historial',
  };

  // ── Construcción responsive ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        final page = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
            child: KeyedSubtree(
              key: ValueKey(state.section),
              child: activeSubApplication(),
            ),
          ),
        );
        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                AppSidebar(state: state),
                const VerticalDivider(width: 1),
                Expanded(child: page),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(currentTitle()),
            surfaceTintColor: Colors.transparent,
          ),
          drawer: Drawer(
            child: AppSidebar(
              state: state,
              onSelected: () => Navigator.of(context).pop(),
            ),
          ),
          body: page,
        );
      },
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, required this.state, this.onSelected});
  final AppState state;
  final VoidCallback? onSelected;

  // ── Opciones de navegación ──────────────────────────────────────────────────
  static const items = <(AppSection, IconData, String)>[
    (AppSection.home, Icons.home_rounded, 'Inicio'),
    (AppSection.search, Icons.search_rounded, 'Buscar productos'),
    (AppSection.comparison, Icons.compare_arrows_rounded, 'Comparaciones'),
    (AppSection.favorites, Icons.favorite_outline_rounded, 'Favoritos'),
    (AppSection.history, Icons.history_rounded, 'Historial'),
  ];

  // ── Construcción del menú lateral ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 264,
      child: ColoredBox(
        color: dark ? const Color(0xFF0E192A) : Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: Column(
              children: [
                const Brand(),
                const SizedBox(height: 34),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: NavButton(
                      icon: item.$2,
                      label: item.$3,
                      selected: state.section == item.$1,
                      onTap: () {
                        state.navigate(item.$1);
                        onSelected?.call();
                      },
                    ),
                  ),
                const Spacer(),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 19,
                      backgroundColor: AppColors.paleBlue,
                      child: Text(
                        'LC',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lucía',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Sincronizado',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: dark ? 'Modo claro' : 'Modo oscuro',
                      onPressed: state.toggleTheme,
                      icon: Icon(
                        dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Brand extends StatelessWidget {
  const Brand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'SimpleStore',
            maxLines: 1,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class NavButton extends StatelessWidget {
  const NavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: .12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? AppColors.primary : AppColors.slate,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BLOQUE 05 · INICIO
// =============================================================================

// ── Borradores persistentes de la pantalla de inicio ──────────────────────────
extension HomeDraftActions on AppState {
  void updateHomeSearchDraft(String value) {
    homeSearchDraft = value;
    _saveWithoutRebuild();
  }

  void updateHomeUrlDraft(String value) {
    homeUrlDraft = value;
    _saveWithoutRebuild();
  }
}

class HomeSubApp extends StatefulWidget {
  const HomeSubApp({super.key, required this.state});
  final AppState state;

  @override
  State<HomeSubApp> createState() => _HomeSubAppState();
}

class _HomeSubAppState extends State<HomeSubApp> {
  // ── Controladores de campos ─────────────────────────────────────────────────
  late final TextEditingController searchController;
  late final TextEditingController urlController;

  // ── Ciclo de vida ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(
      text: widget.state.homeSearchDraft,
    );
    urlController = TextEditingController(text: widget.state.homeUrlDraft);
  }

  @override
  void dispose() {
    widget.state.updateHomeSearchDraft(searchController.text);
    widget.state.updateHomeUrlDraft(urlController.text);
    searchController.dispose();
    urlController.dispose();
    super.dispose();
  }

  // ── Acciones del inicio ─────────────────────────────────────────────────────
  void startSearch(String query) {
    widget.state.updateHomeSearchDraft(query);
    widget.state.navigate(AppSection.search);
    widget.state.search(query);
  }

  void showUrlMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URL agregada para análisis simulado.')),
    );
  }

  // ── Construcción de la pantalla ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SmartHeader(),
          const SizedBox(height: 26),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Qué querés encontrar?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Buscá por producto, marca o modelo.',
                  style: TextStyle(color: AppColors.slate),
                ),
                const SizedBox(height: 18),
                SearchRow(
                  controller: searchController,
                  onSearch: startSearch,
                  onChanged: widget.state.updateHomeSearchDraft,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Sugerencias:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    for (final text in const [
                      'Notebook 16 GB RAM',
                      'Auriculares Bluetooth',
                      'Smart TV 50 pulgadas',
                    ])
                      ActionChip(
                        label: Text(text),
                        onPressed: () => startSearch(text),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(),
                ),
                const Text(
                  '¿Ya viste una publicación?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: urlController,
                  onChanged: widget.state.updateHomeUrlDraft,
                  decoration: InputDecoration(
                    hintText: 'Pegá una URL para preparar su comparación',
                    suffixIcon: IconButton(
                      tooltip: 'Analizar URL',
                      onPressed: showUrlMessage,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final activity = ActivityPanel(
                items: widget.state.history,
                onOpen: startSearch,
              );
              const sources = SourcesPanel();
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: activity),
                        const SizedBox(width: 20),
                        const Expanded(flex: 2, child: sources),
                      ],
                    )
                  : Column(
                      children: [activity, const SizedBox(height: 20), sources],
                    );
            },
          ),
        ],
      ),
    );
  }
}

// ── Componente de inicio: encabezado inteligente ──────────────────────────────
class SmartHeader extends StatelessWidget {
  const SmartHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Encontrá la mejor opción con búsqueda inteligente',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Comparamos precio, envío y características para mostrarte el costo real de cada alternativa.',
                style: TextStyle(color: AppColors.slate, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Componente reutilizable: fila de búsqueda ─────────────────────────────────
class SearchRow extends StatelessWidget {
  const SearchRow({
    super.key,
    required this.controller,
    required this.onSearch,
    this.onChanged,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final field = TextField(
          key: const Key('search-field'),
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSearch,
          decoration: const InputDecoration(
            hintText: 'Ej.: Samsung Galaxy A55 256 GB',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        );
        final button = FilledButton.icon(
          onPressed: () => onSearch(controller.text),
          icon: const Icon(Icons.search),
          label: const Text('Buscar'),
        );
        return constraints.maxWidth < 620
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 10), button],
              )
            : Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 10),
                  button,
                ],
              );
      },
    );
  }
}

// ── Componente de inicio: actividad reciente ──────────────────────────────────
class ActivityPanel extends StatelessWidget {
  const ActivityPanel({super.key, required this.items, required this.onOpen});
  final List<SearchRecord> items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(context, 'Actividad reciente'),
          const SizedBox(height: 12),
          for (final item in items.take(4))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.search_rounded, size: 18),
              ),
              title: Text(
                item.query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${item.resultCount} resultados'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onOpen(item.query),
            ),
        ],
      ),
    );
  }
}

// ── Componente de inicio: fuentes conectadas ──────────────────────────────────
class SourcesPanel extends StatelessWidget {
  const SourcesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    const sources = [
      ('ML', 'Mercado Libre'),
      ('G', 'Google Search'),
      ('F', 'Frávega'),
      ('S', 'Samsung Store'),
    ];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: sectionTitle(context, 'Fuentes conectadas')),
              const Icon(
                Icons.sync_rounded,
                color: AppColors.success,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final source in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.paleBlue,
                    child: Text(
                      source.$1,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      source.$2,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Text(
                    'Activa',
                    style: TextStyle(color: AppColors.success, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// BLOQUE 06 · BÚSQUEDA, FILTROS Y RESULTADOS
// =============================================================================

// ── Lógica de búsqueda asociada a este bloque ─────────────────────────────────
extension SearchActions on AppState {
  void search(String value, {SearchFilters? newFilters, bool save = true}) {
    query = value.trim();
    searchDraft = query;
    filters = newFilters ?? filters;
    results = _searchService.search(query, filters);

    if (save && query.isNotEmpty) {
      _saveSearchInHistory();
    }
    _refresh();
  }

  void applyFilters(SearchFilters value) {
    search(query, newFilters: value, save: false);
  }

  void repeatSearch(String value) {
    section = AppSection.search;
    search(value);
  }

  void updateSearchDraft(String value) {
    searchDraft = value;
    _saveWithoutRebuild();
  }

  // ── Función auxiliar: actualización del historial ───────────────────────────
  void _saveSearchInHistory() {
    history.removeWhere(
      (item) => item.query.toLowerCase() == query.toLowerCase(),
    );
    history.insert(
      0,
      SearchRecord(
        query: query,
        resultCount: results.length,
        createdAt: DateTime.now(),
      ),
    );
  }
}

// ── Pantalla principal de búsqueda ────────────────────────────────────────────

class SearchSubApp extends StatefulWidget {
  const SearchSubApp({super.key, required this.state});
  final AppState state;

  @override
  State<SearchSubApp> createState() => _SearchSubAppState();
}

class _SearchSubAppState extends State<SearchSubApp> {
  // ── Controlador del buscador ────────────────────────────────────────────────
  late final TextEditingController queryController;

  // ── Ciclo de vida y sincronización ──────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    queryController = TextEditingController(text: widget.state.searchDraft);
  }

  @override
  void didUpdateWidget(covariant SearchSubApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (queryController.text != widget.state.searchDraft) {
      queryController.text = widget.state.searchDraft;
    }
  }

  @override
  void dispose() {
    widget.state.updateSearchDraft(queryController.text);
    queryController.dispose();
    super.dispose();
  }

  // ── Construcción de la pantalla ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeading(
                  title: 'Buscar productos',
                  subtitle:
                      'Encontrá ofertas equivalentes y compará el costo real.',
                ),
                const SizedBox(height: 20),
                SearchRow(
                  controller: queryController,
                  onSearch: widget.state.search,
                  onChanged: widget.state.updateSearchDraft,
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final filters = FilterPanel(
                      filters: widget.state.filters,
                      onChanged: widget.state.applyFilters,
                    );
                    final results = ResultsList(state: widget.state);
                    return constraints.maxWidth >= 1040
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 286, child: filters),
                              const SizedBox(width: 20),
                              Expanded(child: results),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              filters,
                              const SizedBox(height: 20),
                              results,
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ),
        if (widget.state.comparisonIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 0, 26, 18),
            child: ComparisonBar(state: widget.state),
          ),
      ],
    );
  }
}

// ── Panel de filtros ───────────────────────────────────────────────────────────
class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.filters,
    required this.onChanged,
  });
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  // ── Controladores de precios ────────────────────────────────────────────────
  late final TextEditingController minController;
  late final TextEditingController maxController;
  late final TextEditingController totalController;

  // ── Ciclo de vida ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    minController = textController(widget.filters.minPrice);
    maxController = textController(widget.filters.maxPrice);
    totalController = textController(widget.filters.maxTotal);
  }

  TextEditingController textController(double? value) {
    return TextEditingController(text: value?.round().toString() ?? '');
  }

  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    totalController.dispose();
    super.dispose();
  }

  // ── Funciones auxiliares de conversión ──────────────────────────────────────
  double? parseNumber(String text) {
    return double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));
  }

  // ── Acciones de filtros ─────────────────────────────────────────────────────
  void apply({Set<String>? stores, Map<String, String>? features}) {
    widget.onChanged(
      widget.filters.copyWith(
        minPrice: parseNumber(minController.text),
        maxPrice: parseNumber(maxController.text),
        maxTotal: parseNumber(totalController.text),
        clearMin: minController.text.trim().isEmpty,
        clearMax: maxController.text.trim().isEmpty,
        clearTotal: totalController.text.trim().isEmpty,
        storeIds: stores,
        features: features,
      ),
    );
  }

  void reset() {
    minController.clear();
    maxController.clear();
    totalController.clear();
    widget.onChanged(const SearchFilters());
  }

  void changeFeature(String key, String? value) {
    final next = {...widget.filters.features};
    value == null ? next.remove(key) : next[key] = value;
    apply(features: next);
  }

  // ── Construcción del panel ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Filtros',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(onPressed: reset, child: const Text('Limpiar')),
            ],
          ),
          const FilterLabel('Precio del producto'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mínimo'),
                  onSubmitted: (_) => apply(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: maxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Máximo'),
                  onSubmitted: (_) => apply(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const FilterLabel('Costo total máximo'),
          TextField(
            controller: totalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              prefixText: '\$ ',
              hintText: 'Sin límite',
            ),
            onSubmitted: (_) => apply(),
          ),
          const SizedBox(height: 16),
          const FilterLabel('Tienda'),
          for (final store in mockStores)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: widget.filters.storeIds.contains(store.id),
              title: Text(store.name),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (selected) {
                final stores = {...widget.filters.storeIds};
                selected == true
                    ? stores.add(store.id)
                    : stores.remove(store.id);
                apply(stores: stores);
              },
            ),
          const SizedBox(height: 10),
          const FilterLabel('Características'),
          FeatureDropdown(
            label: 'Almacenamiento',
            value: widget.filters.features['almacenamiento'],
            values: const ['128 GB', '256 GB'],
            onChanged: (value) => changeFeature('almacenamiento', value),
          ),
          const SizedBox(height: 10),
          FeatureDropdown(
            label: 'Memoria RAM',
            value: widget.filters.features['ram'],
            values: const ['8 GB'],
            onChanged: (value) => changeFeature('ram', value),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: apply,
              child: const Text('Aplicar filtros'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Componente de filtros: etiqueta ───────────────────────────────────────────
class FilterLabel extends StatelessWidget {
  const FilterLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ── Componente de filtros: selector de característica ─────────────────────────
class FeatureDropdown extends StatelessWidget {
  const FeatureDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final List<String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        ...values.map(
          (item) => DropdownMenuItem(value: item, child: Text(item)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

// ── Lista de resultados ────────────────────────────────────────────────────────
class ResultsList extends StatelessWidget {
  const ResultsList({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResultsHeader(state: state),
        const SizedBox(height: 16),
        if (state.results.isEmpty)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No encontramos resultados',
            message: 'Probá con menos filtros o con un modelo más general.',
          )
        else
          for (final product in state.results)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: ProductCard(product: product, state: state),
            ),
      ],
    );
  }
}

// ── Encabezado y ordenamiento de resultados ───────────────────────────────────
class ResultsHeader extends StatelessWidget {
  const ResultsHeader({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${state.results.length} resultados',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                state.query.isEmpty
                    ? 'Todos los productos'
                    : 'para “${state.query}”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 230,
          child: DropdownButtonFormField<SortOrder>(
            key: ValueKey(state.filters.sortOrder),
            initialValue: state.filters.sortOrder,
            decoration: const InputDecoration(
              labelText: 'Ordenar por',
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: SortOrder.lowestPrice,
                child: Text('Menor precio'),
              ),
              DropdownMenuItem(
                value: SortOrder.highestPrice,
                child: Text('Mayor precio'),
              ),
              DropdownMenuItem(
                value: SortOrder.lowestTotal,
                child: Text('Menor costo total'),
              ),
              DropdownMenuItem(
                value: SortOrder.highestTotal,
                child: Text('Mayor costo total'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                state.applyFilters(state.filters.copyWith(sortOrder: value));
              }
            },
          ),
        ),
      ],
    );
  }
}

// ── Tarjeta individual de producto ────────────────────────────────────────────
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.state});
  final Product product;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final favorite = state.favoriteIds.contains(product.id);
    final selected = state.comparisonIds.contains(product.id);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Panel(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final visual = Container(
            width: compact ? double.infinity : 132,
            height: compact ? 110 : 132,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF18253A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.smartphone_rounded,
              size: 58,
              color: AppColors.slate,
            ),
          );
          final details = ProductDetails(
            product: product,
            favorite: favorite,
            selected: selected,
            onFavorite: () => state.toggleFavorite(product.id),
            onCompare: () => state.toggleComparison(product.id),
          );
          return compact
              ? Column(children: [visual, const SizedBox(height: 14), details])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    visual,
                    const SizedBox(width: 18),
                    Expanded(child: details),
                  ],
                );
        },
      ),
    );
  }
}

// ── Contenido textual de la tarjeta ───────────────────────────────────────────
class ProductDetails extends StatelessWidget {
  const ProductDetails({
    super.key,
    required this.product,
    required this.favorite,
    required this.selected,
    required this.onFavorite,
    required this.onCompare,
  });
  final Product product;
  final bool favorite;
  final bool selected;
  final VoidCallback onFavorite;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                product.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
            IconButton(
              tooltip: favorite ? 'Quitar de favoritos' : 'Guardar',
              onPressed: onFavorite,
              icon: Icon(
                favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: favorite ? AppColors.danger : AppColors.slate,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            Text(
              product.offer.store.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '★ ${product.offer.store.rating}',
              style: const TextStyle(color: AppColors.slate),
            ),
            Text(
              '${product.matchPercent}% de coincidencia',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        if (product.badge != null)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.paleBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Text(
                  product.badge!,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 18,
          runSpacing: 7,
          children: [
            ProductFact(
              icon: Icons.local_shipping_outlined,
              text: product.offer.shippingCost == 0
                  ? 'Envío gratis'
                  : 'Envío ${formatMoney(product.offer.shippingCost)}',
            ),
            ProductFact(
              icon: Icons.schedule_rounded,
              text: product.offer.deliveryLabel,
            ),
            if (product.offer.installments != null)
              ProductFact(
                icon: Icons.credit_card_rounded,
                text: product.offer.installments!,
              ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatMoney(product.offer.price),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Costo total ${formatMoney(product.offer.totalCost)}',
                    style: const TextStyle(color: AppColors.slate),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onCompare,
              icon: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
              ),
              label: Text(selected ? 'Seleccionado' : 'Comparar'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Dato breve de una oferta ──────────────────────────────────────────────────
class ProductFact extends StatelessWidget {
  const ProductFact({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.slate),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

// ── Barra inferior de selección para comparar ─────────────────────────────────
class ComparisonBar extends StatelessWidget {
  const ComparisonBar({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final count = state.comparisonIds.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF17243A) : const Color(0xFFEFF6FF),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: .35),
          width: 1.4,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          Text(
            count < 2
                ? 'Elegí ${2 - count} producto más para comparar'
                : '$count productos listos para comparar',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: state.clearComparison,
                child: const Text('Limpiar'),
              ),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: count >= 2
                    ? () => state.navigate(AppSection.comparison)
                    : null,
                child: const Text('Ver comparación'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// BLOQUE 07 · COMPARACIÓN
// =============================================================================

// ── Lógica de comparación asociada a este bloque ──────────────────────────────
extension ComparisonActions on AppState {
  List<Product> get comparisonProducts => mockProducts
      .where((product) => comparisonIds.contains(product.id))
      .toList();

  void toggleComparison(String id) {
    if (comparisonIds.contains(id)) {
      comparisonIds.remove(id);
    } else {
      comparisonIds.add(id);
    }
    _refresh();
  }

  void clearComparison() {
    comparisonIds.clear();
    _refresh();
  }
}

// ── Pantalla de comparación ───────────────────────────────────────────────────

class ComparisonSubApp extends StatelessWidget {
  const ComparisonSubApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final products = state.comparisonProducts;
    if (products.length < 2) {
      return Center(
        child: EmptyState(
          icon: Icons.compare_arrows_rounded,
          title: 'Armá tu primera comparación',
          message:
              'Seleccioná al menos dos productos desde la búsqueda para ver sus diferencias.',
          action: FilledButton.icon(
            onPressed: () => state.navigate(AppSection.search),
            icon: const Icon(Icons.search_rounded),
            label: const Text('Buscar productos'),
          ),
        ),
      );
    }

    final features = const ComparisonService().build(products);
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PageHeading(
                  title: 'Comparación de productos',
                  subtitle:
                      'Los datos no informados se muestran con “-”, sin inventar valores.',
                ),
              ),
              TextButton.icon(
                onPressed: state.clearComparison,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ComparisonTable(products: products, features: features),
          ),
        ],
      ),
    );
  }
}

// ── Tabla comparativa con doble desplazamiento ─────────────────────────────────
class ComparisonTable extends StatefulWidget {
  const ComparisonTable({
    super.key,
    required this.products,
    required this.features,
  });
  final List<Product> products;
  final List<ComparisonFeature> features;

  @override
  State<ComparisonTable> createState() => _ComparisonTableState();
}

class _ComparisonTableState extends State<ComparisonTable> {
  // ── Controladores de desplazamiento ─────────────────────────────────────────
  final horizontal = ScrollController();
  final vertical = ScrollController();

  // ── Ciclo de vida ───────────────────────────────────────────────────────────
  @override
  void dispose() {
    horizontal.dispose();
    vertical.dispose();
    super.dispose();
  }

  // ── Construcción de la tabla ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const labelWidth = 205.0;
    const productWidth = 250.0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = dark ? const Color(0xFF3A4A62) : const Color(0xFFCBD5E1);
    final totalWidth = labelWidth + productWidth * widget.products.length;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border, width: 1.8),
      ),
      child: Scrollbar(
        controller: horizontal,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth,
            child: Scrollbar(
              controller: vertical,
              thumbVisibility: true,
              child: ListView.builder(
                controller: vertical,
                itemCount: widget.features.length,
                itemBuilder: (context, rowIndex) {
                  final feature = widget.features[rowIndex];
                  final important = {
                    'producto',
                    'tienda',
                    'coincidencia',
                    'precio',
                    'envio',
                    'costo_total',
                  }.contains(feature.key);
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TableCellBox(
                          width: labelWidth,
                          background: dark
                              ? const Color(0xFF142238)
                              : const Color(0xFFF1F5F9),
                          border: border,
                          child: Text(
                            feature.label,
                            style: TextStyle(
                              fontSize: important ? 16 : 14,
                              fontWeight: important
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: dark ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),
                        for (
                          var column = 0;
                          column < widget.products.length;
                          column++
                        )
                          TableCellBox(
                            width: productWidth,
                            background: column.isOdd
                                ? (dark
                                      ? const Color(0xFF18263A)
                                      : const Color(0xFFF1F5F9))
                                : (dark ? AppColors.darkSurface : Colors.white),
                            border: border,
                            child: Text(
                              feature.values[widget.products[column].id] ?? '-',
                              style: TextStyle(
                                fontSize: important ? 15 : 14,
                                fontWeight: important
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.35,
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
      ),
    );
  }
}

// ── Celda reutilizable de la tabla ─────────────────────────────────────────────
class TableCellBox extends StatelessWidget {
  const TableCellBox({
    super.key,
    required this.width,
    required this.background,
    required this.border,
    required this.child,
  });
  final double width;
  final Color background;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(15),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(color: border, width: 1.4),
          bottom: BorderSide(color: border, width: 1.4),
        ),
      ),
      child: child,
    );
  }
}

// =============================================================================
// BLOQUE 08 · FAVORITOS
// =============================================================================

// ── Lógica de favoritos asociada a este bloque ────────────────────────────────
extension FavoriteActions on AppState {
  List<Product> get favorites => mockProducts
      .where((product) => favoriteIds.contains(product.id))
      .toList();

  void toggleFavorite(String id) {
    favoriteIds.contains(id) ? favoriteIds.remove(id) : favoriteIds.add(id);
    _refresh();
  }
}

// ── Pantalla de favoritos ─────────────────────────────────────────────────────

class FavoritesSubApp extends StatelessWidget {
  const FavoritesSubApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading(
            title: 'Favoritos',
            subtitle: 'Tus productos guardados durante esta sesión.',
          ),
          const SizedBox(height: 20),
          if (state.favorites.isEmpty)
            EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Todavía no guardaste productos',
              message: 'Marcá el corazón de una oferta para encontrarla acá.',
              action: FilledButton(
                onPressed: () => state.navigate(AppSection.search),
                child: const Text('Explorar productos'),
              ),
            )
          else
            for (final product in state.favorites)
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: ProductCard(product: product, state: state),
              ),
        ],
      ),
    );
  }
}

// =============================================================================
// BLOQUE 09 · HISTORIAL
// =============================================================================

class HistorySubApp extends StatelessWidget {
  const HistorySubApp({super.key, required this.state});
  final AppState state;

  // ── Función auxiliar para mostrar la hora ───────────────────────────────────
  String timeLabel(DateTime value) {
    final minutes = DateTime.now().difference(value).inMinutes;
    if (minutes < 1) return 'Recién';
    if (minutes < 60) return 'Hace $minutes min';
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  // ── Construcción de la pantalla ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeading(
            title: 'Historial',
            subtitle: 'Volvé rápidamente a tus búsquedas de esta sesión.',
          ),
          const SizedBox(height: 20),
          Panel(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (var index = 0; index < state.history.length; index++) ...[
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.paleBlue,
                      child: Icon(
                        Icons.history_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      state.history[index].query,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${state.history[index].resultCount} resultados · ${timeLabel(state.history[index].createdAt)}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_rounded),
                    onTap: () => state.repeatSearch(state.history[index].query),
                  ),
                  if (index != state.history.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// BLOQUE 10 · COMPONENTES COMPARTIDOS
// =============================================================================

// ── Encabezado estándar de pantalla ───────────────────────────────────────────
class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(subtitle, style: const TextStyle(color: AppColors.slate)),
      ],
    );
  }
}

// ── Contenedor visual estándar ─────────────────────────────────────────────────
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: padding, child: child),
    );
  }
}

// ── Estado vacío estándar ──────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(38),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate, height: 1.45),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

// ── Función auxiliar: título interno de una sección ────────────────────────────
Widget sectionTitle(BuildContext context, String text) {
  return Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}
