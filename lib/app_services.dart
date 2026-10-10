import 'product_data.dart';

// Toda la lógica reemplazable queda fuera de la interfaz.
class SearchService {
  const SearchService();

  List<Product> search(String query, SearchFilters filters) {
    final terms = query
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);

    final results = mockProducts.where((product) {
      final searchable = [
        product.name,
        product.category,
        ...product.specifications.values.whereType<String>(),
      ].join(' ').toLowerCase();
      final offer = product.offer;

      return (terms.isEmpty || terms.every(searchable.contains)) &&
          (filters.storeIds.isEmpty ||
              filters.storeIds.contains(offer.store.id)) &&
          (filters.minPrice == null || offer.price >= filters.minPrice!) &&
          (filters.maxPrice == null || offer.price <= filters.maxPrice!) &&
          (filters.maxTotal == null || offer.totalCost <= filters.maxTotal!) &&
          filters.features.entries.every((entry) {
            if (entry.value.isEmpty) return true;
            return product.specifications[entry.key]?.toLowerCase() ==
                entry.value.toLowerCase();
          });
    }).toList();

    results.sort(
      (a, b) => switch (filters.sortOrder) {
        SortOrder.lowestPrice => a.offer.price.compareTo(b.offer.price),
        SortOrder.highestPrice => b.offer.price.compareTo(a.offer.price),
        SortOrder.lowestTotal => a.offer.totalCost.compareTo(b.offer.totalCost),
        SortOrder.highestTotal => b.offer.totalCost.compareTo(
          a.offer.totalCost,
        ),
      },
    );
    return results;
  }
}

class ComparisonService {
  const ComparisonService();

  static const featureLabels = <String, String>{
    'marca': 'Marca',
    'modelo': 'Modelo',
    'almacenamiento': 'Almacenamiento',
    'ram': 'Memoria RAM',
    'pantalla': 'Pantalla',
    'color': 'Color',
    'red': 'Conectividad',
  };

  List<ComparisonFeature> build(List<Product> products) {
    final rows = <ComparisonFeature>[
      _row('producto', 'Producto', products, (p) => p.name),
      _row('tienda', 'Tienda', products, (p) => p.offer.store.name),
      _row(
        'coincidencia',
        'Coincidencia',
        products,
        (p) => '${p.matchPercent}%',
      ),
      _row('precio', 'Precio', products, (p) => formatMoney(p.offer.price)),
      _row(
        'envio',
        'Envío',
        products,
        (p) => p.offer.shippingCost == 0
            ? 'Gratis'
            : formatMoney(p.offer.shippingCost),
      ),
      _row(
        'costo_total',
        'Costo total',
        products,
        (p) => formatMoney(p.offer.totalCost),
      ),
      _row('entrega', 'Entrega', products, (p) => p.offer.deliveryLabel),
      _row(
        'cuotas',
        'Financiación',
        products,
        (p) => p.offer.installments ?? '-',
      ),
    ];

    for (final feature in featureLabels.entries) {
      rows.add(
        _row(
          feature.key,
          feature.value,
          products,
          (product) => safeValue(product.specifications[feature.key]),
        ),
      );
    }
    return rows;
  }

  ComparisonFeature _row(
    String key,
    String label,
    List<Product> products,
    String Function(Product) value,
  ) {
    return ComparisonFeature(
      key: key,
      label: label,
      values: {for (final product in products) product.id: value(product)},
    );
  }

  // Regla crítica: nunca inferimos ni completamos un dato faltante.
  String safeValue(String? value) {
    return value == null || value.trim().isEmpty ? '-' : value;
  }
}

String formatMoney(double value) {
  final digits = value.round().toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return '\$$formatted';
}
