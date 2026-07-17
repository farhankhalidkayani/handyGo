/// Mirrors the `service_categories` collection (§5.4, seeded from §16.3).
class ServiceCategory {
  final String id;
  final String name;
  final String? icon;
  final double basePriceMin;
  final double basePriceMax;
  final int avgDurationMins;

  const ServiceCategory({
    required this.id,
    required this.name,
    this.icon,
    required this.basePriceMin,
    required this.basePriceMax,
    required this.avgDurationMins,
  });

  factory ServiceCategory.fromMap(Map<String, dynamic> map) => ServiceCategory(
        id: map['\$id'] as String,
        name: map['name'] as String,
        icon: map['icon'] as String?,
        basePriceMin: (map['basePriceMin'] as num).toDouble(),
        basePriceMax: (map['basePriceMax'] as num).toDouble(),
        avgDurationMins: (map['avgDurationMins'] as num?)?.toInt() ?? 60,
      );
}
