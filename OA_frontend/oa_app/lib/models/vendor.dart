class Vendor {
  final int id;
  final String name;
  final String? logoPath;
  final String templateVariant;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Vendor({
    required this.id,
    required this.name,
    this.logoPath,
    this.templateVariant = 'default',
    this.isActive = true,
    this.displayOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(
        id: j['id'] as int,
        name: j['name'] as String,
        logoPath: j['logo_path'] as String?,
        templateVariant: (j['template_variant'] as String?) ?? 'default',
        isActive: j['is_active'] as bool? ?? true,
        displayOrder: j['display_order'] as int? ?? 0,
        createdAt: j['created_at'] != null
            ? DateTime.parse(j['created_at'] as String).toLocal()
            : null,
        updatedAt: j['updated_at'] != null
            ? DateTime.parse(j['updated_at'] as String).toLocal()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'logo_path': logoPath,
        'template_variant': templateVariant,
        'is_active': isActive,
        'display_order': displayOrder,
      };
}
