import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../shared/models/facility_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/routing_service.dart';

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
  final FacilityModel? nearestFacility;
  final CitizenMapFilter filter;
  final bool isLoading;
  final String? error;
  final bool isFullScreenMap;
  final bool isLiveTrackingActive;
  final List<LatLng> navigationRoute;
  final FacilityModel? navigatingFacility;
  final NavigationRouteResult? navigationResult;
  final bool isArrived;

  CitizenMapState({
    this.allFacilities = const [],
    this.filteredFacilities = const [],
    required this.userLocation,
    this.selectedFacility,
    this.nearestFacility,
    required this.filter,
    this.isLoading = false,
    this.error,
    this.isFullScreenMap = false,
    this.isLiveTrackingActive = true,
    this.navigationRoute = const [],
    this.navigatingFacility,
    this.navigationResult,
    this.isArrived = false,
  });

  CitizenMapState copyWith({
    List<FacilityModel>? allFacilities,
    List<FacilityModel>? filteredFacilities,
    LatLng? userLocation,
    FacilityModel? selectedFacility,
    FacilityModel? nearestFacility,
    CitizenMapFilter? filter,
    bool? isLoading,
    String? error,
    bool? isFullScreenMap,
    bool? isLiveTrackingActive,
    List<LatLng>? navigationRoute,
    FacilityModel? navigatingFacility,
    NavigationRouteResult? navigationResult,
    bool? isArrived,
    bool clearSelected = false,
    bool clearNavigating = false,
  }) {
    return CitizenMapState(
      allFacilities: allFacilities ?? this.allFacilities,
      filteredFacilities: filteredFacilities ?? this.filteredFacilities,
      userLocation: userLocation ?? this.userLocation,
      selectedFacility: clearSelected ? null : (selectedFacility ?? this.selectedFacility),
      nearestFacility: nearestFacility ?? this.nearestFacility,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isFullScreenMap: isFullScreenMap ?? this.isFullScreenMap,
      isLiveTrackingActive: isLiveTrackingActive ?? this.isLiveTrackingActive,
      navigationRoute: clearNavigating ? const [] : (navigationRoute ?? this.navigationRoute),
      navigatingFacility: clearNavigating ? null : (navigatingFacility ?? this.navigatingFacility),
      navigationResult: clearNavigating ? null : (navigationResult ?? this.navigationResult),
      isArrived: clearNavigating ? false : (isArrived ?? this.isArrived),
    );
  }
}

class CitizenMapNotifier extends StateNotifier<CitizenMapState> {
  final ApiClient _apiClient;
  Timer? _liveSimulationTimer;
  StreamSubscription<LatLng>? _gpsSubscription;
  int _simulationStep = 0;

  CitizenMapNotifier(this._apiClient)
      : super(CitizenMapState(
          userLocation: const LatLng(AppConfig.defaultLat, AppConfig.defaultLon),
          filter: CitizenMapFilter(),
        )) {
    fetchNearbyFacilities();
    initRealGpsTracking();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _liveSimulationTimer?.cancel();
    super.dispose();
  }

  Future<void> initRealGpsTracking() async {
    try {
      final currentPos = await LocationService.getCurrentPosition();
      updateUserLocation(currentPos);

      _gpsSubscription = LocationService.getPositionStream().listen(
        (realPos) {
          updateUserLocation(realPos);
        },
        onError: (err) {
          startLiveWalkSimulation();
        },
      );
    } catch (_) {
      startLiveWalkSimulation();
    }
  }

  Future<void> requestDeviceLocation() async {
    final currentPos = await LocationService.getCurrentPosition();
    updateUserLocation(currentPos);
    fetchNearbyFacilities();
  }

  Future<void> fetchFacilities() async {
    await fetchNearbyFacilities();
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
      final rawFacilities = data.map((json) => FacilityModel.fromJson(json)).toList();
      _recalculateAndSetState(rawFacilities, state.userLocation);
    } catch (e) {
      final samples = _generateSampleFacilities();
      _recalculateAndSetState(samples, state.userLocation);
    }
  }

  void _recalculateAndSetState(List<FacilityModel> rawList, LatLng userPos) {
    const distanceCalculator = Distance();
    final updatedList = rawList.map((f) {
      final meters = distanceCalculator.as(LengthUnit.Meter, userPos, LatLng(f.latitude, f.longitude));
      final walkingMin = (meters / 80.0).ceil();
      return f.copyWith(
        distanceMeters: meters.roundToDouble(),
        walkingTimeMinutes: walkingMin,
      );
    }).toList();

    updatedList.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));

    final filtered = _applyFilters(updatedList, state.filter);
    final nearest = updatedList.isNotEmpty ? updatedList.first : null;

    bool arrived = false;
    if (state.navigatingFacility != null) {
      final remaining = distanceCalculator.as(
        LengthUnit.Meter,
        userPos,
        LatLng(state.navigatingFacility!.latitude, state.navigatingFacility!.longitude),
      );
      if (remaining <= 25) {
        arrived = true;
      }
    }

    state = state.copyWith(
      allFacilities: updatedList,
      filteredFacilities: filtered,
      nearestFacility: nearest,
      isArrived: arrived,
      isLoading: false,
    );
  }

  void updateUserLocation(LatLng newLocation) {
    _recalculateAndSetState(state.allFacilities, newLocation);
    state = state.copyWith(userLocation: newLocation);
  }

  void updateFilter(CitizenMapFilter newFilter) {
    final filtered = _applyFilters(state.allFacilities, newFilter);
    state = state.copyWith(
      filter: newFilter,
      filteredFacilities: filtered,
    );
  }

  void selectFacility(FacilityModel? facility) {
    state = state.copyWith(
      selectedFacility: facility,
      clearSelected: facility == null,
    );
  }

  void setFullScreenMap(bool isFullScreen) {
    state = state.copyWith(isFullScreenMap: isFullScreen);
  }

  void toggleFullScreenMap() {
    state = state.copyWith(isFullScreenMap: !state.isFullScreenMap);
  }

  Future<void> startNavigation(FacilityModel facility) async {
    state = state.copyWith(
      navigatingFacility: facility,
      selectedFacility: facility,
      isFullScreenMap: true,
      isArrived: false,
      isLoading: true,
    );

    // Call RoutingService for real Google-Maps-grade street walking polyline & turn steps
    final result = await RoutingService.calculateWalkingRoute(
      origin: state.userLocation,
      destination: LatLng(facility.latitude, facility.longitude),
    );

    state = state.copyWith(
      navigationResult: result,
      navigationRoute: result.polylinePoints,
      isLoading: false,
    );
  }

  void clearNavigation() {
    state = state.copyWith(clearNavigating: true);
  }

  void startLiveWalkSimulation() {
    _liveSimulationTimer?.cancel();
    // Simulate gentle realistic movement along Marine Drive / MG Road to demonstrate live GPS distance updates
    final List<LatLng> walkPath = [
      const LatLng(9.9723, 76.2831), // MG Road Central
      const LatLng(9.9735, 76.2815),
      const LatLng(9.9750, 76.2795),
      const LatLng(9.9770, 76.2770),
      const LatLng(9.9784, 76.2755), // Marine Drive Walkway Restroom
      const LatLng(9.9775, 76.2760),
      const LatLng(9.9755, 76.2785),
      const LatLng(9.9740, 76.2810),
    ];

    _liveSimulationTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!state.isLiveTrackingActive) return;
      _simulationStep = (_simulationStep + 1) % walkPath.length;
      final nextPos = walkPath[_simulationStep];
      updateUserLocation(nextPos);
    });
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
