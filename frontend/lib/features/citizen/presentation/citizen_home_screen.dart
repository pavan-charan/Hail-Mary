import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/theme.dart';
import '../../../shared/models/facility_model.dart';
import '../../auth/state/auth_notifier.dart';
import '../state/citizen_map_notifier.dart';
import 'screens/qr_scanner_screen.dart';
import 'widgets/facility_details_bottom_sheet.dart';
import 'widgets/facility_filter_sheet.dart';
import 'widgets/raise_ticket_modal.dart';

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final mapState = ref.watch(citizenMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Smart Civic Sanitation', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
            Text('Welcome, ${authState.user?.fullName ?? "Citizen"}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.primaryTeal),
            tooltip: 'Scan Facility QR',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // OpenStreetMap Tile Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapState.userLocation,
              initialZoom: 15.0,
              onTap: (_, __) {
                ref.read(citizenMapProvider.notifier).selectFacility(null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'in.gov.civic.frontend',
              ),
              MarkerLayer(
                markers: [
                  // User Location Pin
                  Marker(
                    point: mapState.userLocation,
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 10, spreadRadius: 2),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.my_location, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                  // Categorized Facility Markers
                  ...mapState.filteredFacilities.map((f) => _buildCustomMarker(f)),
                ],
              ),
            ],
          ),

          // Top Floating Search & Filter Chips Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Filter Sheet Launcher Button
                  ActionChip(
                    avatar: const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'Filters (${mapState.filteredFacilities.length})',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    backgroundColor: AppTheme.primaryTeal,
                    elevation: 4,
                    onPressed: () => _openFilterSheet(context, mapState),
                  ),
                  const SizedBox(width: 8),

                  // Quick Pill 1: Restrooms
                  _buildQuickFilterPill(
                    label: 'Restrooms',
                    icon: Icons.wc_outlined,
                    isSelected: mapState.filter.category == 'TOILET',
                    onTap: () {
                      final current = mapState.filter.category;
                      ref.read(citizenMapProvider.notifier).updateFilter(
                            mapState.filter.copyWith(category: current == 'TOILET' ? 'ALL' : 'TOILET'),
                          );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Quick Pill 2: Drinking Water
                  _buildQuickFilterPill(
                    label: 'Drinking Water',
                    icon: Icons.water_drop_outlined,
                    isSelected: mapState.filter.category == 'WATER',
                    onTap: () {
                      final current = mapState.filter.category;
                      ref.read(citizenMapProvider.notifier).updateFilter(
                            mapState.filter.copyWith(category: current == 'WATER' ? 'ALL' : 'WATER'),
                          );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Quick Pill 3: Wheelchair Access
                  _buildQuickFilterPill(
                    label: 'Wheelchair Access',
                    icon: Icons.accessible_forward_rounded,
                    isSelected: mapState.filter.wheelchairOnly,
                    onTap: () {
                      ref.read(citizenMapProvider.notifier).updateFilter(
                            mapState.filter.copyWith(wheelchairOnly: !mapState.filter.wheelchairOnly),
                          );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Floating Re-Center Button
          Positioned(
            right: 16,
            bottom: mapState.selectedFacility != null ? 360 : 32,
            child: FloatingActionButton.small(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryTeal,
              elevation: 4,
              onPressed: () {
                _mapController.move(mapState.userLocation, 15.0);
              },
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bottom Facility Details Sheet / Card
          if (mapState.selectedFacility != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FacilityDetailsBottomSheet(
                facility: mapState.selectedFacility!,
                onNavigate: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening Navigation Route to ${mapState.selectedFacility!.name}...')),
                  );
                },
                onRaiseTicket: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => RaiseTicketModal(facility: mapState.selectedFacility!),
                  );
                },
                onRateFacility: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening 4-Factor Rating Sheet for ${mapState.selectedFacility!.facilityId}...')),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Marker _buildCustomMarker(FacilityModel facility) {
    final confidenceColor = AppTheme.getConfidenceColor(facility.confidenceScore);

    // Marker styling based on Category and Gender
    Color markerBg = AppTheme.primaryTeal;
    IconData markerIcon = Icons.wc_rounded;

    if (facility.facilityType == FacilityType.DRINKING_WATER) {
      markerBg = AppTheme.accentCyan;
      markerIcon = Icons.water_drop_rounded;
    } else {
      if (facility.genderAccess == GenderAccess.MALE) {
        markerBg = const Color(0xFF2563EB); // Royal Blue
        markerIcon = Icons.man_rounded;
      } else if (facility.genderAccess == GenderAccess.FEMALE) {
        markerBg = const Color(0xFFDB2777); // Deep Pink
        markerIcon = Icons.woman_rounded;
      }
    }

    return Marker(
      point: LatLng(facility.latitude, facility.longitude),
      width: 54,
      height: 54,
      child: GestureDetector(
        onTap: () {
          ref.read(citizenMapProvider.notifier).selectFacility(facility);
          _mapController.move(LatLng(facility.latitude, facility.longitude), 16.0);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Confidence Glow Ring
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: confidenceColor, width: 3.5),
                color: markerBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(markerIcon, color: Colors.white, size: 26),
            ),
            // Wheelchair Badge if applicable
            if (facility.wheelchairAccessible)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.accessible_forward_rounded, size: 13, color: AppTheme.primaryTeal),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterPill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      selected: isSelected,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryTeal),
      label: Text(label),
      selectedColor: AppTheme.primaryTeal,
      backgroundColor: Colors.white,
      elevation: 3,
      labelStyle: GoogleFonts.outfit(
        color: isSelected ? Colors.white : AppTheme.surfaceDark,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) => onTap(),
    );
  }

  void _openFilterSheet(BuildContext context, CitizenMapState mapState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FacilityFilterSheet(
        initialFilter: mapState.filter,
        matchCount: mapState.filteredFacilities.length,
        onApply: (newFilter) {
          ref.read(citizenMapProvider.notifier).updateFilter(newFilter);
        },
      ),
    );
  }

  void _showQrScannerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        height: 350,
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Text('Scan Facility QR Code', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Point your camera at the QR code mounted on any public facility.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              height: 140,
              width: 140,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryTeal, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.qr_code_2_rounded, size: 80, color: AppTheme.primaryTeal),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Simulate Scan'),
            )
          ],
        ),
      ),
    );
  }
}
