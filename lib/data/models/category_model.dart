class CategoryModel {
  final int id;
  final String name;
  final String iconName;
  final int count;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.iconName,
    this.count = 0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int,
      name: map['name'] as String,
      iconName: map['icon_name'] as String? ?? 'place',
      count: map['count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon_name': iconName,
      'count': count,
    };
  }
}
