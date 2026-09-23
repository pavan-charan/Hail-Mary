import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/theme.dart';
import '../../../shared/models/facility_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/state/auth_notifier.dart';
import '../state/citizen_map_notifier.dart';
import 'screens/qr_scanner_screen.dart';
import 'widgets/facility_details_bottom_sheet.dart';
import 'widgets/facility_filter_sheet.dart';
import 'widgets/raise_ticket_modal.dart';
import 'widgets/rate_facility_dialog.dart';
import 'widgets/notifications_sheet.dart';

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(citizenMapProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Smart Civic Sanitation', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.surfaceDark)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text('Live GPS Active • Kochi KMC', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Switch Demo Role',
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 16, color: AppTheme.primaryTeal),
                  const SizedBox(width: 4),
                  Text('Citizen', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal)),
                ],
              ),
            ),
            onSelected: (role) {
              if (role == 'worker') {
                ref.read(authProvider.notifier).switchRoleForDemo(UserRole.WORKER);
                context.go('/worker');
              } else if (role == 'admin') {
                ref.read(authProvider.notifier).switchRoleForDemo(UserRole.ADMIN);
                context.go('/admin');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'worker',
                child: Row(
                  children: [
                    Icon(Icons.engineering_rounded, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Text('Switch to Worker (Ramesh)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'admin',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7C3AED), size: 18),
                    SizedBox(width: 8),
                    Text('Switch to Admin (KMC Officer)'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.primaryTeal),
            tooltip: 'Notifications',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const NotificationsSheet(),
              );
            },
          ),
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
      body: mapState.isFullScreenMap
          ? _buildFullScreenMapView(context, mapState)
          : _buildStandardDashboardView(context, mapState),
    );
  }

  // -------------------------------------------------------------
  // MODE 1: Standard Dashboard View with Nearest Facility on Top
  // -------------------------------------------------------------
  Widget _buildStandardDashboardView(BuildContext context, CitizenMapState mapState) {
    final nearest = mapState.nearestFacility;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Prominent Live Nearest Facility Spotlight Card (Above the Map)
          if (nearest != null)
            _buildNearestFacilityCard(context, mapState, nearest)
          else
            _buildNearestLoadingCard(),

          const SizedBox(height: 16),

          // 2. Category Quick Filters
          _buildFilterChipsRow(context, mapState),

          const SizedBox(height: 16),

          // 3. Interactive Map Preview Box (Clicking in the middle opens Full Map)
          _buildMapPreviewBox(context, mapState),

          const SizedBox(height: 20),

          // 4. Other Nearby Facilities List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Nearby Public Facilities (${mapState.filteredFacilities.length})',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.surfaceDark),
              ),
              TextButton.icon(
                icon: const Icon(Icons.fullscreen_rounded, size: 18),
                label: const Text('View Full Map'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryTeal),
                onPressed: () => ref.read(citizenMapProvider.notifier).setFullScreenMap(true),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...mapState.filteredFacilities.map((f) => _buildFacilityListTile(context, f, isNearest: f.id == nearest?.id)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Nearest Facility Spotlight Card Widget
  // -------------------------------------------------------------
  Widget _buildNearestFacilityCard(BuildContext context, CitizenMapState mapState, FacilityModel facility) {
    final confidenceColor = AppTheme.getConfidenceColor(facility.confidenceScore);
    final isToilet = facility.facilityType == FacilityType.TOILET;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF042F2E), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Live Pulse Badge + Distance
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15 + (_pulseController.value * 0.1)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF4ADE80), width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.radar_rounded, size: 14, color: Color(0xFF4ADE80)),
                        SizedBox(width: 5),
                        Text(
                          'NEAREST FACILITY • LIVE GPS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${facility.distanceMeters?.toInt() ?? 0}m away (~${facility.walkingTimeMinutes ?? 1} min)',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Facility Name & Type
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isToilet ? Icons.wc_rounded : Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.name,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      facility.address,
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Facility Badges
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMetricBadge(
                icon: Icons.verified_rounded,
                label: '${facility.confidenceScore.toInt()}% Confidence',
                color: confidenceColor,
                bgColor: Colors.black.withOpacity(0.3),
              ),
              _buildMetricBadge(
                icon: Icons.access_time_rounded,
                label: '${facility.openingTime} - ${facility.closingTime}',
                color: Colors.white,
                bgColor: Colors.white.withOpacity(0.15),
              ),
              if (facility.wheelchairAccessible)
                _buildMetricBadge(
                  icon: Icons.accessible_forward_rounded,
                  label: 'Wheelchair Friendly',
                  color: const Color(0xFF67E8F9),
                  bgColor: Colors.white.withOpacity(0.15),
                ),
              if (facility.waterAvailability)
                _buildMetricBadge(
                  icon: Icons.water_drop_rounded,
                  label: 'Water Available',
                  color: const Color(0xFF93C5FD),
                  bgColor: Colors.white.withOpacity(0.15),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons: Navigate (opens map route), Details, Rate (30m), Report Issue
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: Text('Walk Route', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13)),
                  onPressed: () {
                    ref.read(citizenMapProvider.notifier).startNavigation(facility);
                    _mapController.move(LatLng(facility.latitude, facility.longitude), 16.5);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Details', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                  onPressed: () {
                    ref.read(citizenMapProvider.notifier).selectFacility(facility);
                    _showFacilityDetailsSheet(context, facility);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Rate Facility (Geo-fenced 30m)',
                icon: const Icon(Icons.star_rate_rounded, size: 20),
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => RateFacilityDialog(facility: facility),
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                ),
                tooltip: 'Report Issue',
                icon: const Icon(Icons.report_problem_outlined, size: 20),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => RaiseTicketModal(facility: facility),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearestLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: AppTheme.primaryTeal, strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(
            child: Text('Acquiring live GPS position & locating nearest facility...', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Map Preview Box (Middle Section - Tap anywhere to expand)
  // -------------------------------------------------------------
  Widget _buildMapPreviewBox(BuildContext context, CitizenMapState mapState) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // FlutterMap Tile & Marker Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapState.userLocation,
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none), // Let card tap handle expansion
              onTap: (_, __) {
                ref.read(citizenMapProvider.notifier).setFullScreenMap(true);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'in.gov.civic.frontend',
              ),
              if (mapState.navigationRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: mapState.navigationRoute,
                      strokeWidth: 4.5,
                      color: AppTheme.primaryTeal,
                      isDotted: true,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  _buildUserMarker(mapState.userLocation),
                  ...mapState.filteredFacilities.map((f) => _buildCustomMarker(f, isCompact: true)),
                ],
              ),
            ],
          ),

          // Central Clickable Overlay to Open Fullscreen Map
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ref.read(citizenMapProvider.notifier).setFullScreenMap(true);
                },
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white38),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Tap Map to Open Fullscreen',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MODE 2: FullScreen Interactive Map View
  // -------------------------------------------------------------
  Widget _buildFullScreenMapView(BuildContext context, CitizenMapState mapState) {
    return Stack(
      children: [
        // Fullscreen OpenStreetMap Tile Layer
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
            if (mapState.navigationRoute.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: mapState.navigationRoute,
                    strokeWidth: 5.0,
                    color: AppTheme.primaryTeal,
                    isDotted: true,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                _buildUserMarker(mapState.userLocation),
                ...mapState.filteredFacilities.map((f) => _buildCustomMarker(f)),
              ],
            ),
          ],
        ),

        // Floating Back / Collapse Button
        Positioned(
          top: 16,
          left: 16,
          child: FloatingActionButton.extended(
            heroTag: 'collapse_map_btn',
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.surfaceDark,
            elevation: 4,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text('Overview', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
            onPressed: () {
              ref.read(citizenMapProvider.notifier).setFullScreenMap(false);
            },
          ),
        ),

        // Floating Filter Chips at the top
        Positioned(
          top: 16,
          left: 140,
          right: 16,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                  label: Text('Filters (${mapState.filteredFacilities.length})', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  backgroundColor: AppTheme.primaryTeal,
                  elevation: 4,
                  onPressed: () => _openFilterSheet(context, mapState),
                ),
                const SizedBox(width: 6),
                _buildQuickFilterPill(
                  label: 'Restrooms',
                  icon: Icons.wc_outlined,
                  isSelected: mapState.filter.category == 'TOILET',
                  onTap: () {
                    final cur = mapState.filter.category;
                    ref.read(citizenMapProvider.notifier).updateFilter(mapState.filter.copyWith(category: cur == 'TOILET' ? 'ALL' : 'TOILET'));
                  },
                ),
                const SizedBox(width: 6),
                _buildQuickFilterPill(
                  label: 'Drinking Water',
                  icon: Icons.water_drop_outlined,
                  isSelected: mapState.filter.category == 'WATER',
                  onTap: () {
                    final cur = mapState.filter.category;
                    ref.read(citizenMapProvider.notifier).updateFilter(mapState.filter.copyWith(category: cur == 'WATER' ? 'ALL' : 'WATER'));
                  },
                ),
              ],
            ),
          ),
        ),

        // Re-Center on Live GPS Pin
        Positioned(
          right: 16,
          bottom: mapState.selectedFacility != null ? 360 : 32,
          child: FloatingActionButton.small(
            heroTag: 'recenter_gps_btn',
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryTeal,
            elevation: 4,
            onPressed: () {
              _mapController.move(mapState.userLocation, 16.0);
            },
            child: const Icon(Icons.my_location_rounded),
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
                ref.read(citizenMapProvider.notifier).startNavigation(mapState.selectedFacility!);
                _mapController.move(LatLng(mapState.selectedFacility!.latitude, mapState.selectedFacility!.longitude), 16.5);
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
                showDialog(
                  context: context,
                  builder: (ctx) => RateFacilityDialog(facility: mapState.selectedFacility!),
                );
              },
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Filter Chips Row
  // -------------------------------------------------------------
  Widget _buildFilterChipsRow(BuildContext context, CitizenMapState mapState) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
            label: Text(
              'Filters (${mapState.filteredFacilities.length})',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppTheme.primaryTeal,
            elevation: 3,
            onPressed: () => _openFilterSheet(context, mapState),
          ),
          const SizedBox(width: 8),
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
          _buildQuickFilterPill(
            label: 'Wheelchair Friendly',
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
    );
  }

  // -------------------------------------------------------------
  // Facility List Item
  // -------------------------------------------------------------
  Widget _buildFacilityListTile(BuildContext context, FacilityModel facility, {bool isNearest = false}) {
    final confidenceColor = AppTheme.getConfidenceColor(facility.confidenceScore);
    final isToilet = facility.facilityType == FacilityType.TOILET;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNearest ? AppTheme.primaryTeal : Colors.grey.shade200, width: isNearest ? 2 : 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isToilet ? AppTheme.primaryTeal : AppTheme.accentCyan).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isToilet ? Icons.wc_rounded : Icons.water_drop_rounded,
            color: isToilet ? AppTheme.primaryTeal : AppTheme.accentCyan,
            size: 22,
          ),
        ),
        title: Text(facility.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(facility.address, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${facility.distanceMeters?.toInt() ?? 0}m', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 11, color: AppTheme.primaryTeal)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: confidenceColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('${facility.confidenceScore.toInt()}% Verified', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: confidenceColor)),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          onPressed: () {
            ref.read(citizenMapProvider.notifier).selectFacility(facility);
            _showFacilityDetailsSheet(context, facility);
          },
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Map Markers (User Pin & Facility Custom Pins)
  // -------------------------------------------------------------
  Marker _buildUserMarker(LatLng userPos) {
    return Marker(
      point: userPos,
      width: 42,
      height: 42,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 32 + (_pulseController.value * 10),
                height: 32 + (_pulseController.value * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2563EB).withOpacity(0.3 - (_pulseController.value * 0.2)),
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white, size: 14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Marker _buildCustomMarker(FacilityModel facility, {bool isCompact = false}) {
    final confidenceColor = AppTheme.getConfidenceColor(facility.confidenceScore);
    Color markerBg = AppTheme.primaryTeal;
    IconData markerIcon = Icons.wc_rounded;

    if (facility.facilityType == FacilityType.DRINKING_WATER) {
      markerBg = AppTheme.accentCyan;
      markerIcon = Icons.water_drop_rounded;
    } else {
      if (facility.genderAccess == GenderAccess.MALE) {
        markerBg = const Color(0xFF2563EB);
        markerIcon = Icons.man_rounded;
      } else if (facility.genderAccess == GenderAccess.FEMALE) {
        markerBg = const Color(0xFFDB2777);
        markerIcon = Icons.woman_rounded;
      }
    }

    final size = isCompact ? 38.0 : 48.0;

    return Marker(
      point: LatLng(facility.latitude, facility.longitude),
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () {
          ref.read(citizenMapProvider.notifier).selectFacility(facility);
          _mapController.move(LatLng(facility.latitude, facility.longitude), 16.0);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size - 4,
              height: size - 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: confidenceColor, width: 3),
                color: markerBg,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(markerIcon, color: Colors.white, size: isCompact ? 18 : 24),
            ),
            if (facility.wheelchairAccessible && !isCompact)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.accessible_forward_rounded, size: 12, color: AppTheme.primaryTeal),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBadge({required IconData icon, required String label, required Color color, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
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
      elevation: 2,
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

  void _showFacilityDetailsSheet(BuildContext context, FacilityModel facility) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FacilityDetailsBottomSheet(
        facility: facility,
        onNavigate: () {
          Navigator.pop(ctx);
          ref.read(citizenMapProvider.notifier).startNavigation(facility);
          _mapController.move(LatLng(facility.latitude, facility.longitude), 16.5);
        },
        onRaiseTicket: () {
          Navigator.pop(ctx);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (c) => RaiseTicketModal(facility: facility),
          );
        },
        onRateFacility: () {
          Navigator.pop(ctx);
          showDialog(
            context: context,
            builder: (c) => RateFacilityDialog(facility: facility),
          );
        },
      ),
    );
  }
}
