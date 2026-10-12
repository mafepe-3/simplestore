import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplestore/app_storage.dart';
import 'package:simplestore/cloud_storage.dart';
import 'package:simplestore/main.dart';
import 'package:simplestore/product_data.dart';

void main() {
  test('separa el estado local del estado guardado en la nube', () async {
    final localStorage = MemoryLocalStateStorage();
    final cloudStorage = MemoryCloudStateStorage();
    final original = AppState(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
    );

    original.updateHomeSearchDraft('notebook para estudiar');
    original.updateHomeUrlDraft('https://ejemplo.com/producto');
    original.search(
      'Samsung A55 256 GB',
      newFilters: const SearchFilters(
        minPrice: 500000,
        storeIds: {'ml', 'fravega'},
        sortOrder: SortOrder.lowestPrice,
      ),
    );
    original.toggleFavorite('a55-ml');
    original.toggleComparison('a55-ml');
    original.toggleComparison('a55-fravega');
    original.toggleTheme();
    original.navigate(AppSection.history);
    await original.persistLocalState();
    await original.persistCloudState();

    final localJson = jsonDecode(localStorage.value!) as Map<String, dynamic>;
    final localScreens = localJson['screens'] as Map<String, dynamic>;
    expect(localJson['version'], 2);
    expect(localJson['storage'], 'local');
    expect(localScreens, isA<Map<String, dynamic>>());
    expect(localScreens.containsKey('favorites'), isFalse);
    expect(localScreens.containsKey('history'), isFalse);

    final cloudJson = cloudStorage.value!;
    expect(cloudJson['storage'], 'cloud');
    expect(cloudJson.containsKey('favorites'), isTrue);
    expect(cloudJson.containsKey('history'), isTrue);
    expect(cloudJson.containsKey('app'), isFalse);
    expect(cloudJson.containsKey('screens'), isFalse);

    final restored = AppState(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
    );
    await restored.restoreState();

    expect(restored.section, AppSection.history);
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.homeSearchDraft, 'notebook para estudiar');
    expect(restored.homeUrlDraft, 'https://ejemplo.com/producto');
    expect(restored.query, 'Samsung A55 256 GB');
    expect(restored.filters.minPrice, 500000);
    expect(restored.filters.storeIds, {'ml', 'fravega'});
    expect(restored.favoriteIds, {'a55-ml'});
    expect(restored.comparisonIds, {'a55-ml', 'a55-fravega'});
    expect(restored.history.first.query, 'Samsung A55 256 GB');

    original.dispose();
    restored.dispose();
  });

  test('migra favoritos e historial del JSON local v1 a la nube', () async {
    final localStorage = MemoryLocalStateStorage()
      ..value = jsonEncode({
        'version': 1,
        'app': {'section': 'home', 'themeMode': 'light'},
        'screens': {
          'home': {'searchDraft': 'celular', 'urlDraft': ''},
          'search': {
            'query': 'celular',
            'draft': 'celular',
            'filters': <String, dynamic>{},
          },
          'comparison': {'productIds': <String>[]},
          'favorites': {
            'productIds': ['a55-ml'],
          },
          'history': {
            'items': [
              {
                'query': 'celular',
                'resultCount': 3,
                'createdAt': '2026-10-10T10:00:00.000',
              },
            ],
          },
        },
      });
    final cloudStorage = MemoryCloudStateStorage();
    final state = AppState(
      localStorage: localStorage,
      cloudStorage: cloudStorage,
    );

    await state.restoreState();

    expect(state.favoriteIds, {'a55-ml'});
    expect(state.history.single.query, 'celular');
    expect(cloudStorage.value?['favorites'], isNotNull);

    final rewrittenLocal =
        jsonDecode(localStorage.value!) as Map<String, dynamic>;
    final screens = rewrittenLocal['screens'] as Map<String, dynamic>;
    expect(rewrittenLocal['version'], 2);
    expect(screens.containsKey('favorites'), isFalse);
    expect(screens.containsKey('history'), isFalse);

    state.dispose();
  });
}
