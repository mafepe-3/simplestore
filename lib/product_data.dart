// Modelos y datos locales. Este archivo concentra lo que luego puede venir
// de una API o base de datos, sin mezclarlo con la interfaz.

class Store {
  const Store({
    required this.id,
    required this.name,
    required this.initials,
    required this.rating,
  });

  final String id;
  final String name;
  final String initials;
  final double rating;
}

class ProductOffer {
  const ProductOffer({
    required this.store,
    required this.price,
    required this.shippingCost,
    required this.deliveryLabel,
    this.installments,
  });

  final Store store;
  final double price;
  final double shippingCost;
  final String deliveryLabel;
  final String? installments;

  double get totalCost => price + shippingCost;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.matchPercent,
    required this.offer,
    required this.specifications,
    this.badge,
  });

  final String id;
  final String name;
  final String category;
  final int matchPercent;
  final ProductOffer offer;
  final Map<String, String?> specifications;
  final String? badge;
}

class ComparisonFeature {
  const ComparisonFeature({
    required this.key,
    required this.label,
    required this.values,
  });

  final String key;
  final String label;
  final Map<String, String> values;
}

class SearchRecord {
  const SearchRecord({
    required this.query,
    required this.resultCount,
    required this.createdAt,
  });

  final String query;
  final int resultCount;
  final DateTime createdAt;
}

enum SortOrder { lowestPrice, highestPrice, lowestTotal, highestTotal }

class SearchFilters {
  const SearchFilters({
    this.minPrice,
    this.maxPrice,
    this.maxTotal,
    this.storeIds = const <String>{},
    this.features = const <String, String>{},
    this.sortOrder = SortOrder.lowestTotal,
  });

  final double? minPrice;
  final double? maxPrice;
  final double? maxTotal;
  final Set<String> storeIds;
  final Map<String, String> features;
  final SortOrder sortOrder;

  SearchFilters copyWith({
    double? minPrice,
    double? maxPrice,
    double? maxTotal,
    Set<String>? storeIds,
    Map<String, String>? features,
    SortOrder? sortOrder,
    bool clearMin = false,
    bool clearMax = false,
    bool clearTotal = false,
  }) {
    return SearchFilters(
      minPrice: clearMin ? null : minPrice ?? this.minPrice,
      maxPrice: clearMax ? null : maxPrice ?? this.maxPrice,
      maxTotal: clearTotal ? null : maxTotal ?? this.maxTotal,
      storeIds: storeIds ?? this.storeIds,
      features: features ?? this.features,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

const mercadoLibre = Store(
  id: 'ml',
  name: 'Mercado Libre',
  initials: 'ML',
  rating: 4.8,
);
const fravega = Store(
  id: 'fravega',
  name: 'Frávega',
  initials: 'F',
  rating: 4.6,
);
const samsung = Store(
  id: 'samsung',
  name: 'Samsung',
  initials: 'S',
  rating: 4.9,
);
const musimundo = Store(
  id: 'musimundo',
  name: 'Musimundo',
  initials: 'M',
  rating: 4.5,
);

const mockStores = [mercadoLibre, fravega, samsung, musimundo];

const mockProducts = <Product>[
  Product(
    id: 'a55-ml',
    name: 'Samsung Galaxy A55 5G 256 GB Azul',
    category: 'Celulares',
    matchPercent: 98,
    badge: 'Mejor costo total',
    offer: ProductOffer(
      store: mercadoLibre,
      price: 739999,
      shippingCost: 0,
      deliveryLabel: 'Llega mañana',
      installments: '6 cuotas sin interés',
    ),
    specifications: {
      'marca': 'Samsung',
      'modelo': 'Galaxy A55 5G',
      'almacenamiento': '256 GB',
      'ram': '8 GB',
      'pantalla': '6,6"',
      'color': 'Azul',
      'red': '5G',
    },
  ),
  Product(
    id: 'a55-fravega',
    name: 'Celular Samsung Galaxy A55 5G 256GB',
    category: 'Celulares',
    matchPercent: 97,
    offer: ProductOffer(
      store: fravega,
      price: 724999,
      shippingCost: 12999,
      deliveryLabel: 'Llega en 2 días',
      installments: '9 cuotas fijas',
    ),
    specifications: {
      'marca': 'Samsung',
      'modelo': 'A55 5G',
      'almacenamiento': '256 GB',
      'ram': '8 GB',
      'pantalla': '6,6"',
      'color': null,
      'red': '5G',
    },
  ),
  Product(
    id: 'a55-samsung',
    name: 'Galaxy A55 5G 256 GB Awesome Navy',
    category: 'Celulares',
    matchPercent: 99,
    badge: 'Coincidencia exacta',
    offer: ProductOffer(
      store: samsung,
      price: 779999,
      shippingCost: 0,
      deliveryLabel: 'Llega en 3 días',
      installments: '12 cuotas sin interés',
    ),
    specifications: {
      'marca': 'Samsung',
      'modelo': 'Galaxy A55 5G',
      'almacenamiento': '256 GB',
      'ram': '8 GB',
      'pantalla': '6,6"',
      'color': 'Azul oscuro',
      'red': '5G',
    },
  ),
  Product(
    id: 'a55-musimundo',
    name: 'Smartphone Samsung A55 128 GB 5G',
    category: 'Celulares',
    matchPercent: 84,
    offer: ProductOffer(
      store: musimundo,
      price: 689999,
      shippingCost: 18500,
      deliveryLabel: 'Llega en 4 días',
      installments: '6 cuotas fijas',
    ),
    specifications: {
      'marca': 'Samsung',
      'modelo': 'A55',
      'almacenamiento': '128 GB',
      'ram': null,
      'pantalla': '6,6"',
      'color': 'Negro',
      'red': '5G',
    },
  ),
  Product(
    id: 's23fe-ml',
    name: 'Samsung Galaxy S23 FE 256 GB Graphite',
    category: 'Celulares',
    matchPercent: 61,
    offer: ProductOffer(
      store: mercadoLibre,
      price: 899999,
      shippingCost: 0,
      deliveryLabel: 'Llega mañana',
      installments: '6 cuotas sin interés',
    ),
    specifications: {
      'marca': 'Samsung',
      'modelo': 'Galaxy S23 FE',
      'almacenamiento': '256 GB',
      'ram': '8 GB',
      'pantalla': '6,4"',
      'color': 'Grafito',
      'red': '5G',
    },
  ),
  Product(
    id: 'a35-fravega',
    name: 'Samsung Galaxy A35 5G 256 GB',
    category: 'Celulares',
    matchPercent: 73,
    offer: ProductOffer(
      store: fravega,
      price: 599999,
      shippingCost: 9900,
      deliveryLabel: 'Llega en 2 días',
      installments: '9 cuotas fijas',
    ),
    specifications: {
      'marca': 'Samsung',
      'modelo': 'Galaxy A35 5G',
      'almacenamiento': '256 GB',
      'ram': '8 GB',
      'pantalla': '6,6"',
      'color': null,
      'red': '5G',
    },
  ),
];
