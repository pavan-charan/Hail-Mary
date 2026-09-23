import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/models/facility_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';

class CitizenMapFilter {
  final String category; // 'ALL', 'TOILET', 'WATER'
  final String gender; // 'ALL', 'MALE', 'FEMALE', 'UNISEX'
  final bool wheelchairOnly;
  final double? maxDistanceMeters; // null, 500, 1000, 3000
  final bool activeOnly;

  CitizenMapFilter({
    this.category = 'ALL',
    this.gender = 'ALL',
    this.wheelchairOnly = false,
    this.maxDistanceMeters,
    this.activeOnly = false,
  });

  CitizenMapFilter copyWith({
    String? category,
    String? gender,
    bool? wheelchairOnly,
    double? maxDistanceMeters,
    bool? activeOnly,
    bool clearDistance = false,
  }) {
    return CitizenMapFilter(
      category: category ?? this.category,
      gender: gender ?? this.gender,
      wheelchairOnly: wheelchairOnly ?? this.wheelchairOnly,
      maxDistanceMeters: clearDistance ? null : (maxDistanceMeters ?? this.maxDistanceMeters),
      activeOnly: activeOnly ?? this.activeOnly,
    );
  }
}

class CitizenMapState {
  final List<FacilityModel> allFacilities;
  final List<FacilityModel> filteredFacilities;
  final LatLng userLocation;
  final FacilityModel? selectedFacility;
  final CitizenMapFilter filter;
  final bool isLoading;
  final String? error;

  CitizenMapState({
    this.allFacilities = const [],
    this.filteredFacilities = const [],
    required this.userLocation,
    this.selectedFacility,
    required this.filter,
    this.isLoading = false,
    this.error,
  });

  CitizenMapState copyWith({
    List<FacilityModel>? allFacilities,
    List<FacilityModel>? filteredFacilities,
    LatLng? userLocation,
    FacilityModel? selectedFacility,
    CitizenMapFilter? filter,
    bool? isLoading,
    String? error,
    bool clearSelected = false,
  }) {
    return CitizenMapState(
      allFacilities: allFacilities ?? this.allFacilities,
      filteredFacilities: filteredFacilities ?? this.filteredFacilities,
      userLocation: userLocation ?? this.userLocation,
      selectedFacility: clearSelected ? null : (selectedFacility ?? this.selectedFacility),
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CitizenMapNotifier extends StateNotifier<CitizenMapState> {
  final ApiClient _apiClient;

  CitizenMapNotifier(this._apiClient)
      : super(CitizenMapState(
          userLocation: const LatLng(AppConfig.defaultLat, AppConfig.defaultLon),
          filter: CitizenMapFilter(),
        )) {
    fetchNearbyFacilities();
  }

  Future<void> fetchNearbyFacilities() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _apiClient.dio.get(
        '/facilities',
        queryParameters: {
          'user_lat': state.userLocation.latitude,
          'user_lon': state.userLocation.longitude,
          'include_demolished': false,
        },
      );
      final List data = response.data;
      final facilities = data.map((json) => FacilityModel.fromJson(json)).toList();
      state = state.copyWith(
        allFacilities: facilities,
        filteredFacilities: _applyFilters(facilities, state.filter),
        isLoading: false,
      );
    } catch (e) {
      // Fallback sample data with diverse categories and markers
      final samples = _generateSampleFacilities();
      state = state.copyWith(
        allFacilities: samples,
        filteredFacilities: _applyFilters(samples, state.filter),
        isLoading: false,
      );
    }
  }

  void updateFilter(CitizenMapFilter newFilter) {
    state = state.copyWith(
      filter: newFilter,
      filteredFacilities: _applyFilters(state.allFacilities, newFilter),
    );
  }

  void selectFacility(FacilityModel? facility) {
    state = state.copyWith(
      selectedFacility: facility,
      clearSelected: facility == null,
    );
  }

  List<FacilityModel> _applyFilters(List<FacilityModel> list, CitizenMapFilter filter) {
    return list.where((f) {
      if (filter.category == 'TOILET' && f.facilityType != FacilityType.TOILET) return false;
      if (filter.category == 'WATER' && f.facilityType != FacilityType.DRINKING_WATER) return false;

      if (filter.gender == 'MALE' && f.genderAccess != GenderAccess.MALE) return false;
      if (filter.gender == 'FEMALE' && f.genderAccess != GenderAccess.FEMALE) return false;
      if (filter.gender == 'UNISEX' && f.genderAccess != GenderAccess.UNISEX) return false;

      if (filter.wheelchairOnly && !f.wheelchairAccessible) return false;
      if (filter.activeOnly && f.status != FacilityStatus.ACTIVE) return false;

      if (filter.maxDistanceMeters != null && f.distanceMeters != null) {
        if (f.distanceMeters! > filter.maxDistanceMeters!) return false;
      }

      return true;
    }).toList();
  }

  List<FacilityModel> _generateSampleFacilities() {
    return [
      FacilityModel(
        id: 1,
        facilityId: 'FAC-KOC-MD-TLT1',
        name: 'Marine Drive Walkway Public Restroom',
        facilityType: FacilityType.TOILET,
        latitude: 9.9784,
        longitude: 76.2755,
        address: 'Rainbow Bridge Walkway, Marine Drive, Kochi',
        ward: 'Ward-01 Marine Drive',
        genderAccess: GenderAccess.UNISEX,
        wheelchairAccessible: true,
        waterAvailability: true,
        openingTime: '05:30',
        closingTime: '23:00',
        status: FacilityStatus.ACTIVE,
        confidenceScore: 96.0,
        distanceMeters: 120,
        walkingTimeMinutes: 2,
        lastVerifiedFormatted: 'Today, 10:30 AM',
      ),
      FacilityModel(
        id: 2,
        facilityId: 'FAC-KOC-MG-TLT2',
        name: 'MG Road Metro Station Sanitation Point',
        facilityType: FacilityType.TOILET,
        latitude: 9.9723,
        longitude: 76.2831,
        address: 'MG Road South Entry, Ernakulam, Kochi',
        ward: 'Ward-05 Ernakulam Central',
        genderAccess: GenderAccess.UNISEX,
        wheelchairAccessible: true,
        waterAvailability: true,
        openingTime: '06:00',
        closingTime: '22:30',
        status: FacilityStatus.ACTIVE,
        confidenceScore: 92.0,
        distanceMeters: 350,
        walkingTimeMinutes: 4,
        lastVerifiedFormatted: 'Today, 08:15 AM',
      ),
      FacilityModel(
        id: 3,
        facilityId: 'FAC-KOC-FK-WTR3',
        name: 'Fort Kochi Beach Drinking Water ATM',
        facilityType: FacilityType.DRINKING_WATER,
        latitude: 9.9658,
        longitude: 76.2421,
        address: 'Vasco da Gama Square, Fort Kochi',
        ward: 'Ward-02 Heritage Fort Kochi',
        genderAccess: GenderAccess.UNISEX,
        wheelchairAccessible: true,
        waterAvailability: true,
        openingTime: '05:00',
        closingTime: '22:00',
        status: FacilityStatus.ACTIVE,
        confidenceScore: 88.0,
        distanceMeters: 580,
        walkingTimeMinutes: 7,
        lastVerifiedFormatted: 'Yesterday, 04:00 PM',
      ),
      FacilityModel(
        id: 4,
        facilityId: 'FAC-KOC-VY-TLT4',
        name: 'Vyttila Mobility Hub Public Facility',
        facilityType: FacilityType.TOILET,
        latitude: 9.9680,
        longitude: 76.3180,
        address: 'Kaniampuzha Road, Vyttila, Kochi',
        ward: 'Ward-12 Vyttila Terminal',
        genderAccess: GenderAccess.UNISEX,
        wheelchairAccessible: true,
        waterAvailability: true,
        openingTime: '24 Hours',
        closingTime: '24 Hours',
        status: FacilityStatus.ACTIVE,
        confidenceScore: 84.0,
        distanceMeters: 890,
        walkingTimeMinutes: 11,
        lastVerifiedFormatted: 'Today, 06:00 AM',
      ),
    ];
  }
}

final citizenMapProvider = StateNotifierProvider<CitizenMapNotifier, CitizenMapState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CitizenMapNotifier(apiClient);
});
