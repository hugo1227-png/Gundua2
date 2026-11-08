class Place {
  final String id;
  final String name;
  final String address;
  final String category;
  final List<String> categories;
  final String? country;
  final String? locality;
  final double latitude;
  final double longitude;
  final double? distanceMeters;
  final String? imageUrl;
  final double? rating;
  final int? reviewCount;
  final int? visitCount;
  final String? phone;
  final String? cuisine;
  final String? description;
  final String? admission;
  final String? priceRange;
  final dynamic openingHours;
  final String? website;
  final String? bookingUrl;
  final List<dynamic>? reviews;
  final String? googleMapsUri;

  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    this.categories = const [],
    this.country,
    this.locality,
    required this.latitude,
    required this.longitude,
    this.distanceMeters,
    this.imageUrl,
    this.rating,
    this.reviewCount,
    this.visitCount,
    this.phone,
    this.cuisine,
    this.description,
    this.admission,
    this.priceRange,
    this.openingHours,
    this.website,
    this.bookingUrl,
    this.reviews,
    this.googleMapsUri,
  });

  factory Place.fromMap(Map<String, dynamic> data) {
    final latitude = data['latitude'] ?? data['lat'];
    final longitude = data['longitude'] ?? data['lon'];

    return Place(
      id: (data['placeId'] ??
              data['place_id'] ??
              '${data['name']}_${latitude}_$longitude')
          .toString(),
      name: (data['name'] ?? 'Lugar sem nome').toString(),
      address: (data['location'] ?? data['formatted'] ?? '').toString(),
      category: (data['categoryLabel'] ?? data['category'] ?? 'Ponto de interesse')
          .toString(),
      categories: data['categories'] is List
          ? (data['categories'] as List).map((item) => item.toString()).toList()
          : const [],
      country: data['country']?.toString(),
      locality: (data['locality'] ??
              data['city'] ??
              data['town'] ??
              data['village'] ??
              data['suburb'] ??
              data['county'])
          ?.toString(),
      latitude: latitude is num ? latitude.toDouble() : 0,
      longitude: longitude is num ? longitude.toDouble() : 0,
      distanceMeters: (data['distance'] as num?)?.toDouble(),
      imageUrl: (data['image'] ?? data['image_url'])?.toString(),
      rating: (data['rating'] as num?)?.toDouble(),
      reviewCount: (data['userRatingCount'] as num?)?.toInt() ??
          (data['reviewCount'] as num?)?.toInt() ??
          (data['user_ratings_total'] as num?)?.toInt(),
      visitCount: (data['visit_count'] as num?)?.toInt() ??
          (data['visitCount'] as num?)?.toInt() ??
          (data['visits'] as num?)?.toInt(),
      phone: (data['phone'] ?? data['contact:phone'])?.toString(),
      cuisine: (data['cuisine'] is List
          ? (data['cuisine'] as List).join(', ')
          : data['cuisine'])?.toString(),
      description: data['description']?.toString(),
      admission: (data['admission_fee'] ?? data['fee'])?.toString(),
      priceRange: (data['priceRange'] ?? data['price_range'])?.toString(),
      openingHours: data['opening_hours'] ?? data['openingHours'] ?? data['hours'],
      website: (data['website'] ?? data['contact:website'])?.toString(),
      bookingUrl: (data['booking_url'] ?? data['bookingUrl'])?.toString(),
      reviews: data['reviews'] is List ? List<dynamic>.from(data['reviews']) : null,
      googleMapsUri: data['googleMapsUri']?.toString(),
    );
  }

  Place copyWith({double? distanceMeters, String? imageUrl}) {
    return Place(
      id: id,
      name: name,
      address: address,
      category: category,
      categories: categories,
      country: country,
      locality: locality,
      latitude: latitude,
      longitude: longitude,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating,
      reviewCount: reviewCount,
      visitCount: visitCount,
      phone: phone,
      cuisine: cuisine,
      description: description,
      admission: admission,
      priceRange: priceRange,
      openingHours: openingHours,
      website: website,
      bookingUrl: bookingUrl,
      reviews: reviews,
      googleMapsUri: googleMapsUri,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'location': address,
        'category': category,
        'categories': categories,
        'country': country,
        'locality': locality,
        'latitude': latitude,
        'longitude': longitude,
        'lat': latitude,
        'lon': longitude,
        'placeId': id,
        'distance': distanceMeters,
        'image': imageUrl,
        'rating': rating,
        'reviewCount': reviewCount,
        'visit_count': visitCount,
        'phone': phone,
        'cuisine': cuisine,
        'description': description,
        'admission_fee': admission,
        'priceRange': priceRange,
        'opening_hours': openingHours,
        'website': website,
        'booking_url': bookingUrl,
        'reviews': reviews,
        'googleMapsUri': googleMapsUri,
      };
}
