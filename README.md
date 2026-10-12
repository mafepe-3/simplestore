# SimpleStore

Primera versión funcional de la app de comparación inteligente de productos. Está pensada para escritorio, se adapta a pantallas angostas y utiliza datos simulados para el catálogo. El estado está dividido entre almacenamiento local y Firebase.

## Ejecutar

```powershell
flutter pub get
flutter run -d chrome --dart-define-from-file=firebase.env.json
```

## Organización simple

```text
lib/
├── main.dart          # Interfaz completa, tema, estado y navegación
├── product_data.dart  # Modelos y catálogo simulado
├── app_services.dart  # Búsqueda y normalización comparativa
├── app_storage.dart   # JSON local del dispositivo
└── cloud_storage.dart # Cuenta, Firebase Auth y JSON remoto de Firestore
```

Dentro de `main.dart`, los bloques principales se reconocen con títulos `BLOQUE 01`, `BLOQUE 02`, etc. Dentro de cada bloque hay separadores secundarios para estado, controladores, ciclo de vida, acciones, funciones auxiliares y construcción visual. La lógica específica de búsqueda, comparación y favoritos está ubicada junto a su pantalla mediante extensiones de `AppState`.

`SearchService` encapsula la fuente de resultados y puede reemplazarse por integraciones reales. `ComparisonService` alinea exclusivamente datos presentes en cada producto: cualquier dato desconocido se muestra como `-`.

## Estado y subaplicaciones

`AppShell` monta una sola subaplicación a la vez: `HomeSubApp`, `SearchSubApp`, `ComparisonSubApp`, `FavoritesSubApp` o `HistorySubApp`. Al navegar, la pantalla anterior sale del árbol y libera sus controladores mediante `dispose`. Al salir de Buscar también se libera la lista de resultados; al volver se reconstruye desde la consulta y los filtros guardados.

El estado funcional no depende de esos widgets. Al abrir nuevamente la aplicación se restauran dos documentos distintos antes de mostrar la interfaz:

- **Local (`shared_preferences`)**: pantalla actual, tema, borradores, última búsqueda, filtros, ordenamiento y selección comparativa en curso.
- **Nube (`users/{uid}` en Cloud Firestore)**: perfil de la cuenta autenticada, favoritos e historial de hasta 50 búsquedas.

Los favoritos y el historial no se duplican en el JSON local. Si existe el antiguo JSON v1, se migra una vez a Firestore y luego se reemplaza por el formato local v2.

## Configurar Firebase

1. Creá un proyecto en Firebase y registrá la aplicación.
2. Activá **Authentication > Anonymous** y creá una base de **Cloud Firestore**.
3. Copiá `firebase.env.example.json` como `firebase.env.json` y completá los valores de configuración de tu aplicación. El archivo real está ignorado por Git.
4. Instalá Firebase CLI y publicá las reglas incluidas con `firebase deploy --only firestore:rules`.
5. Ejecutá Flutter con `--dart-define-from-file=firebase.env.json`.

Mientras esos valores no estén configurados, la interfaz muestra `Firebase pendiente`. En ese estado la aplicación sigue funcionando, pero no guarda localmente los datos que pertenecen a la nube.

La cuenta inicial usa autenticación anónima para no bloquear el prototipo. El documento queda aislado por UID y preparado para vincular esa identidad a correo, Google u otro proveedor cuando se implemente el acceso definitivo.
