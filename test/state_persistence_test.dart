import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simplestore/app_storage.dart';
import 'package:simplestore/main.dart';
import 'package:simplestore/product_data.dart';

void main() {
  test('guarda y restaura el estado completo desde un único JSON', () async {
    final storage = MemoryStateStorage();
    final original = AppState(storage: storage);

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
    await original.persistState();

    final decoded = jsonDecode(storage.value!) as Map<String, dynamic>;
    expect(decoded['version'], 1);
    expect(decoded['screens'], isA<Map<String, dynamic>>());

    final restored = AppState(storage: storage);
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
}
