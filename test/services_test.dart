import 'package:flutter_test/flutter_test.dart';
import 'package:simplestore/app_services.dart';
import 'package:simplestore/product_data.dart';

void main() {
  test('la búsqueda filtra por tienda y ordena por costo total', () {
    final results = const SearchService().search(
      'Samsung',
      const SearchFilters(
        storeIds: {'fravega'},
        sortOrder: SortOrder.lowestTotal,
      ),
    );

    expect(results, isNotEmpty);
    expect(
      results.every((product) => product.offer.store.id == 'fravega'),
      isTrue,
    );
    for (var index = 1; index < results.length; index++) {
      expect(
        results[index - 1].offer.totalCost <= results[index].offer.totalCost,
        isTrue,
      );
    }
  });

  test('la comparación no inventa características ausentes', () {
    final products = [mockProducts[0], mockProducts[1]];
    final rows = const ComparisonService().build(products);
    final color = rows.singleWhere((row) => row.key == 'color');

    expect(color.values[products.first.id], 'Azul');
    expect(color.values[products.last.id], '-');
  });
}
