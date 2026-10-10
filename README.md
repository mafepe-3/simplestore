# SimpleStore

Primera versión funcional de la app de comparación inteligente de productos. Está pensada para escritorio, se adapta a pantallas angostas y funciona completamente con datos simulados locales.

## Ejecutar

```powershell
flutter pub get
flutter run -d chrome
```

## Organización simple

```text
lib/
├── main.dart          # Interfaz completa, tema, estado y navegación
├── product_data.dart  # Modelos y catálogo simulado
├── app_services.dart  # Búsqueda y normalización comparativa
└── app_storage.dart   # Lectura y escritura del JSON persistente
```

Dentro de `main.dart`, los bloques principales se reconocen con títulos `BLOQUE 01`, `BLOQUE 02`, etc. Dentro de cada bloque hay separadores secundarios para estado, controladores, ciclo de vida, acciones, funciones auxiliares y construcción visual. La lógica específica de búsqueda, comparación y favoritos está ubicada junto a su pantalla mediante extensiones de `AppState`.

`SearchService` encapsula la fuente de resultados y puede reemplazarse por integraciones reales. `ComparisonService` alinea exclusivamente datos presentes en cada producto: cualquier dato desconocido se muestra como `-`.

## Estado y subaplicaciones

`AppShell` monta una sola subaplicación a la vez: `HomeSubApp`, `SearchSubApp`, `ComparisonSubApp`, `FavoritesSubApp` o `HistorySubApp`. Al navegar, la pantalla anterior sale del árbol y libera sus controladores mediante `dispose`. Al salir de Buscar también se libera la lista de resultados; al volver se reconstruye desde la consulta y los filtros guardados.

El estado funcional no depende de esos widgets. Se guarda como un único JSON versionado mediante `shared_preferences`, incluyendo última pantalla, tema, borradores, búsqueda, filtros, ordenamiento, selección para comparar, favoritos e historial. Al abrir nuevamente la aplicación, el JSON se restaura antes de mostrar la interfaz.
