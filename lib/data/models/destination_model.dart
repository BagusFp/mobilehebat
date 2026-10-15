class DestinationModel {
  final int id;
  final String name;
  final String description;
  final int categoryId;
  final String categoryName;
  final double latitude;
  final double longitude;
  final int elevationMdpl;
  final double ticketPrice;
  final String ticketPriceLabel;
  final String openingHours;
  final String estimatedDuration;
  final String temperatureRange;
  final String address;
  final String? imageUrl;
  final bool isSavedOffline;
  final double rating;
  final int reviewCount;
  final List<String> facilities;
  final double distanceKm;
  final String? bestVisitingTime;

  const DestinationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.latitude,
    required this.longitude,
    required this.elevationMdpl,
    required this.ticketPrice,
    this.ticketPriceLabel = '',
    this.openingHours = '06.00 - 17.00 WIB',
    this.estimatedDuration = '45 - 60 Menit',
    this.temperatureRange = '18°C - 24°C',
    required this.address,
    this.imageUrl,
    this.isSavedOffline = true,
    this.rating = 4.8,
    this.reviewCount = 500,
    this.facilities = const [],
    this.distanceKm = 0.0,
    this.bestVisitingTime = 'Pukul 05.30 - 08.00 WIB untuk langit jernih',
  });

  DestinationModel copyWith({
    int? id,
    String? name,
    String? description,
    int? categoryId,
    String? categoryName,
    double? latitude,
    double? longitude,
    int? elevationMdpl,
    double? ticketPrice,
    String? ticketPriceLabel,
    String? openingHours,
    String? estimatedDuration,
    String? temperatureRange,
    String? address,
    String? imageUrl,
    bool? isSavedOffline,
    double? rating,
    int? reviewCount,
    List<String>? facilities,
    double? distanceKm,
    String? bestVisitingTime,
  }) {
    return DestinationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevationMdpl: elevationMdpl ?? this.elevationMdpl,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      ticketPriceLabel: ticketPriceLabel ?? this.ticketPriceLabel,
      openingHours: openingHours ?? this.openingHours,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      temperatureRange: temperatureRange ?? this.temperatureRange,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
      isSavedOffline: isSavedOffline ?? this.isSavedOffline,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      facilities: facilities ?? this.facilities,
      distanceKm: distanceKm ?? this.distanceKm,
      bestVisitingTime: bestVisitingTime ?? this.bestVisitingTime,
    );
  }

  factory DestinationModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedFacilities = [];
    if (map['facilities'] != null) {
      final facStr = map['facilities'] as String;
      if (facStr.isNotEmpty) {
        parsedFacilities = facStr.split(',').map((e) => e.trim()).toList();
      }
    }

    return DestinationModel(
      id: map['id'] as int,
      name: map['name'] as String,
      description: map['description'] as String,
      categoryId: map['category_id'] as int? ?? 1,
      categoryName: map['category_name'] as String? ?? 'Alam',
      latitude: (map['latitude'] as num?)?.toDouble() ?? -7.5833,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 110.4422,
      elevationMdpl: map['elevation_mdpl'] as int? ?? 800,
      ticketPrice: (map['ticket_price'] as num?)?.toDouble() ?? 0.0,
      ticketPriceLabel: map['ticket_price_label'] as String? ?? '',
      openingHours: map['opening_hours'] as String? ?? '06.00 - 17.00 WIB',
      estimatedDuration: map['estimated_duration'] as String? ?? '45 - 60 Menit',
      temperatureRange: map['temperature_range'] as String? ?? '18°C - 24°C',
      address: map['address'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      isSavedOffline: (map['is_saved_offline'] as int? ?? 1) == 1,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: map['review_count'] as int? ?? 100,
      facilities: parsedFacilities,
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 4.2,
      bestVisitingTime: map['best_visiting_time'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'category_name': categoryName,
      'latitude': latitude,
      'longitude': longitude,
      'elevation_mdpl': elevationMdpl,
      'ticket_price': ticketPrice,
      'ticket_price_label': ticketPriceLabel,
      'opening_hours': openingHours,
      'estimated_duration': estimatedDuration,
      'temperature_range': temperatureRange,
      'address': address,
      'image_url': imageUrl,
      'is_saved_offline': isSavedOffline ? 1 : 0,
      'rating': rating,
      'review_count': reviewCount,
      'facilities': facilities.join(', '),
      'distance_km': distanceKm,
      'best_visiting_time': bestVisitingTime,
    };
  }
}
