enum FacilityType { TOILET, DRINKING_WATER }
enum GenderAccess { MALE, FEMALE, UNISEX }
enum FacilityStatus { ACTIVE, UNDER_MAINTENANCE, CLOSED, DEMOLISHED }

class FacilityModel {
  final int id;
  final String facilityId;
  final String name;
  final FacilityType facilityType;
  final double latitude;
  final double longitude;
  final String address;
  final String ward;
  final GenderAccess genderAccess;
  final bool wheelchairAccessible;
  final bool waterAvailability;
  final String openingTime;
  final String closingTime;
  final FacilityStatus status;
  final double confidenceScore;
  final double? distanceMeters;
  final int? walkingTimeMinutes;
  final String? lastVerifiedFormatted;

  FacilityModel({
    required this.id,
    required this.facilityId,
    required this.name,
    required this.facilityType,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.ward,
    required this.genderAccess,
    required this.wheelchairAccessible,
    required this.waterAvailability,
    required this.openingTime,
    required this.closingTime,
    required this.status,
    required this.confidenceScore,
    this.distanceMeters,
    this.walkingTimeMinutes,
    this.lastVerifiedFormatted,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    FacilityType fType = json['facility_type'] == 'DRINKING_WATER' 
        ? FacilityType.DRINKING_WATER 
        : FacilityType.TOILET;

    GenderAccess gAccess = GenderAccess.UNISEX;
    if (json['gender_access'] == 'MALE') gAccess = GenderAccess.MALE;
    if (json['gender_access'] == 'FEMALE') gAccess = GenderAccess.FEMALE;

    FacilityStatus fStatus = FacilityStatus.ACTIVE;
    final s = json['status']?.toString();
    if (s == 'UNDER_MAINTENANCE') fStatus = FacilityStatus.UNDER_MAINTENANCE;
    if (s == 'CLOSED') fStatus = FacilityStatus.CLOSED;
    if (s == 'DEMOLISHED') fStatus = FacilityStatus.DEMOLISHED;

    return FacilityModel(
      id: json['id'] ?? 0,
      facilityId: json['facility_id'] ?? '',
      name: json['name'] ?? '',
      facilityType: fType,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] ?? '',
      ward: json['ward'] ?? '',
      genderAccess: gAccess,
      wheelchairAccessible: json['wheelchair_accessible'] ?? false,
      waterAvailability: json['water_availability'] ?? true,
      openingTime: json['opening_time'] ?? '06:00',
      closingTime: json['closing_time'] ?? '22:00',
      status: fStatus,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 100.0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      walkingTimeMinutes: json['walking_time_minutes'],
      lastVerifiedFormatted: json['last_verified_formatted'] ?? 'Verified Today',
    );
  }

  FacilityModel copyWith({
    int? id,
    String? facilityId,
    String? name,
    FacilityType? facilityType,
    double? latitude,
    double? longitude,
    String? address,
    String? ward,
    GenderAccess? genderAccess,
    bool? wheelchairAccessible,
    bool? waterAvailability,
    String? openingTime,
    String? closingTime,
    FacilityStatus? status,
    double? confidenceScore,
    double? distanceMeters,
    int? walkingTimeMinutes,
    String? lastVerifiedFormatted,
  }) {
    return FacilityModel(
      id: id ?? this.id,
      facilityId: facilityId ?? this.facilityId,
      name: name ?? this.name,
      facilityType: facilityType ?? this.facilityType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      ward: ward ?? this.ward,
      genderAccess: genderAccess ?? this.genderAccess,
      wheelchairAccessible: wheelchairAccessible ?? this.wheelchairAccessible,
      waterAvailability: waterAvailability ?? this.waterAvailability,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      status: status ?? this.status,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      walkingTimeMinutes: walkingTimeMinutes ?? this.walkingTimeMinutes,
      lastVerifiedFormatted: lastVerifiedFormatted ?? this.lastVerifiedFormatted,
    );
  }
}
