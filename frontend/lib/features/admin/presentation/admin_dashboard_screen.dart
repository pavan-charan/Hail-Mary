import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config/theme.dart';
import '../../../shared/models/facility_model.dart';
import '../../auth/state/auth_notifier.dart';
import '../state/facility_admin_notifier.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedNavIndex = 0;
  String _facilitySearch = '';
  String _facilityFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryTeal),
            const SizedBox(width: 8),
            Text('Municipal Admin Portal', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Side Navigation Rail for Desktop / Web
          NavigationRail(
            selectedIndex: _selectedNavIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedNavIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primaryTeal),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.location_city_outlined),
                selectedIcon: Icon(Icons.location_city_rounded, color: AppTheme.primaryTeal),
                label: Text('Facilities'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_outlined),
                selectedIcon: Icon(Icons.verified_rounded, color: AppTheme.primaryTeal),
                label: Text('Verification'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.engineering_outlined),
                selectedIcon: Icon(Icons.engineering_rounded, color: AppTheme.primaryTeal),
                label: Text('Workers & SLA'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Body Content
          Expanded(
            child: _buildSelectedTab(),
          )
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedNavIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildFacilitiesManagementTab();
      case 2:
        return _buildVerificationTab();
      case 3:
        return _buildWorkersAndSlaTab();
      default:
        return _buildOverviewTab();
    }
  }

  // TAB 2: VERIFICATION QUEUE (PHASE 12)
  Widget _buildVerificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Work Order Verification Queue', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('Review Before & After photographic evidence, MediaPipe Face Match scores, and GPS completion proximity.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 24),
          _buildVerificationCard(
            ticketId: 'TCK-20260923-A48F',
            facility: 'MG Road Metro Restroom (Ward-12)',
            worker: 'Worker Ramesh Kumar (WRK-WARD12-004)',
            faceScore: 98.4,
            gpsStatus: 'Within 8m of Asset (Passed)',
          ),
          const SizedBox(height: 16),
          _buildVerificationCard(
            ticketId: 'TCK-20260923-C109',
            facility: 'Kanteerava Drinking Fountain (Ward-04)',
            worker: 'Worker Suresh Patel (WRK-WARD04-009)',
            faceScore: 96.1,
            gpsStatus: 'Within 14m of Asset (Passed)',
          ),
        ],
      ),
    );
  }

  // TAB 3: WORKERS & SLA ESCALATION (PHASE 9 & PHASE 16)
  Widget _buildWorkersAndSlaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Local Body Workers & SLA Monitoring', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Active ward assignments, real-time workload balancing, SLA compliance metrics, and penalty records.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.bolt_rounded),
                label: const Text('Run SLA Escalation Scan'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SLA scan complete: All active tickets on-track. Automated Twilio voice alerts armed.')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildKpiCard('Enrolled Workers', '14', '100% Face Verified', Icons.engineering_rounded, AppTheme.primaryTeal),
              _buildKpiCard('On-Track Tickets', '16', 'Within 24h SLA', Icons.check_circle_outline_rounded, Colors.green),
              _buildKpiCard('At-Risk (>20h)', '2', 'SMS Reminders Sent', Icons.alarm_rounded, Colors.orange),
              _buildKpiCard('Penalties Applied', '2', '-20 Pts Total Deducted', Icons.gavel_rounded, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  // TAB 0: OVERVIEW
  Widget _buildOverviewTab() {
    final facilityState = ref.watch(facilityAdminProvider);
    final totalFacilities = facilityState.facilities.length;
    final activeCount = facilityState.facilities.where((f) => f.status == FacilityStatus.ACTIVE).length;
    final demolishedCount = facilityState.facilities.where((f) => f.status == FacilityStatus.DEMOLISHED).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildKpiCard('Total Facilities', '$totalFacilities', '$activeCount Active, $demolishedCount Demolished', Icons.place_rounded, AppTheme.primaryTeal),
              _buildKpiCard('Open Tickets', '18', '3 Pending Verification', Icons.warning_amber_rounded, Colors.orange),
              _buildKpiCard('Avg SLA Turnaround', '3.4 hrs', '-45 mins vs target', Icons.timer_outlined, Colors.blue),
              _buildKpiCard('SLA Compliance', '96.5%', '2 Penalties Recorded', Icons.shield_outlined, Colors.green),
            ],
          ),
          const SizedBox(height: 32),
          Text('Live Maintenance Verification Queue', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildVerificationCard(
            ticketId: 'TCK-20260923-A48F',
            facility: 'MG Road Metro Restroom (Ward-12)',
            worker: 'Worker Ramesh Kumar',
            faceScore: 98.4,
            gpsStatus: 'Within 8m of Asset',
          ),
          const SizedBox(height: 16),
          _buildVerificationCard(
            ticketId: 'TCK-20260923-C109',
            facility: 'Kanteerava Drinking Fountain (Ward-04)',
            worker: 'Worker Suresh Patel',
            faceScore: 96.1,
            gpsStatus: 'Within 14m of Asset',
          ),
        ],
      ),
    );
  }

  // TAB 1: FACILITIES MANAGEMENT (PHASE 3)
  Widget _buildFacilitiesManagementTab() {
    final facilityState = ref.watch(facilityAdminProvider);

    final filtered = facilityState.facilities.where((f) {
      if (_facilityFilter == 'TOILET' && f.facilityType != FacilityType.TOILET) return false;
      if (_facilityFilter == 'WATER' && f.facilityType != FacilityType.DRINKING_WATER) return false;
      if (_facilityFilter == 'ACTIVE' && f.status != FacilityStatus.ACTIVE) return false;
      if (_facilityFilter == 'DEMOLISHED' && f.status != FacilityStatus.DEMOLISHED) return false;

      if (_facilitySearch.isNotEmpty) {
        final query = _facilitySearch.toLowerCase();
        final match = f.name.toLowerCase().contains(query) ||
            f.facilityId.toLowerCase().contains(query) ||
            f.address.toLowerCase().contains(query) ||
            f.ward.toLowerCase().contains(query);
        if (!match) return false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Municipal Facility Asset Registry', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Create, edit, generate QR codes, soft-demolish, and audit public sanitation & water assets.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Facility'),
                onPressed: () => _showAddFacilityDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search and Filters Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by facility name, ID, ward, or address...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _facilitySearch = val),
                ),
              ),
              const SizedBox(width: 16),
              _buildFilterChoiceChip('ALL', 'All (${facilityState.facilities.length})'),
              _buildFilterChoiceChip('TOILET', 'Restrooms'),
              _buildFilterChoiceChip('WATER', 'Drinking Water'),
              _buildFilterChoiceChip('ACTIVE', 'Active'),
              _buildFilterChoiceChip('DEMOLISHED', 'Demolished'),
            ],
          ),
          const SizedBox(height: 20),

          // Facilities List Cards
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text('No facilities found matching your criteria', style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[700])),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((facility) => _buildFacilityInventoryCard(facility)),
        ],
      ),
    );
  }

  Widget _buildFilterChoiceChip(String key, String label) {
    final isSelected = _facilityFilter == key;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppTheme.primaryTeal,
        labelStyle: GoogleFonts.outfit(
          color: isSelected ? Colors.white : AppTheme.surfaceDark,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        onSelected: (selected) {
          if (selected) setState(() => _facilityFilter = key);
        },
      ),
    );
  }

  Widget _buildFacilityInventoryCard(FacilityModel facility) {
    final isDemolished = facility.status == FacilityStatus.DEMOLISHED;
    final statusColor = _getStatusColor(facility.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDemolished ? Colors.red.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
        ),
      ),
      color: isDemolished ? const Color(0xFFFEF2F2) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDemolished ? Colors.red.withOpacity(0.1) : AppTheme.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                facility.facilityType == FacilityType.TOILET ? Icons.wc_rounded : Icons.water_drop_rounded,
                color: isDemolished ? Colors.red : AppTheme.primaryTeal,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(facility.facilityId, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.primaryTeal, fontSize: 13)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          facility.status.name.replaceAll('_', ' '),
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•  ${facility.ward}', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(facility.name, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: isDemolished ? Colors.grey[700] : AppTheme.surfaceDark)),
                  const SizedBox(height: 4),
                  Text(facility.address, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 10),

                  // Amenities & Timings
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildMiniBadge(Icons.access_time_rounded, '${facility.openingTime} - ${facility.closingTime}'),
                      _buildMiniBadge(Icons.people_outline, 'Gender: ${facility.genderAccess.name}'),
                      _buildMiniBadge(
                        Icons.accessible_rounded,
                        facility.wheelchairAccessible ? 'Wheelchair: Yes' : 'Wheelchair: No',
                        color: facility.wheelchairAccessible ? Colors.green : Colors.grey,
                      ),
                      _buildMiniBadge(
                        Icons.water_drop_outlined,
                        facility.waterAvailability ? 'Water: Available' : 'Water: Dry',
                        color: facility.waterAvailability ? Colors.blue : Colors.red,
                      ),
                      _buildMiniBadge(Icons.verified_outlined, 'Confidence: ${facility.confidenceScore.toInt()}%'),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                      label: const Text('View QR'),
                      onPressed: () => _showQrModal(context, facility),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit Facility',
                      onPressed: () => _showEditFacilityDialog(context, facility),
                    ),
                    IconButton(
                      icon: const Icon(Icons.history_rounded, size: 20),
                      tooltip: 'Audit History',
                      onPressed: () => _showAuditHistoryDialog(context, facility),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isDemolished)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.restore_from_trash_rounded, size: 16),
                    label: const Text('Restore Facility'),
                    onPressed: () => _showRestoreDialog(context, facility),
                  )
                else
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Demolish Asset'),
                    onPressed: () => _showDemolishDialog(context, facility),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey[700]),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.outfit(fontSize: 12, color: color ?? Colors.grey[800], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Color _getStatusColor(FacilityStatus status) {
    switch (status) {
      case FacilityStatus.ACTIVE:
        return Colors.green;
      case FacilityStatus.UNDER_MAINTENANCE:
        return Colors.orange[800]!;
      case FacilityStatus.CLOSED:
        return Colors.brown;
      case FacilityStatus.DEMOLISHED:
        return Colors.red;
    }
  }

  // DIALOGS & MODALS

  void _showAddFacilityDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final wardCtrl = TextEditingController(text: 'Ward-12');
    final latCtrl = TextEditingController(text: '12.9716');
    final lonCtrl = TextEditingController(text: '77.5946');
    final openCtrl = TextEditingController(text: '06:00');
    final closeCtrl = TextEditingController(text: '22:00');

    FacilityType type = FacilityType.TOILET;
    GenderAccess gender = GenderAccess.UNISEX;
    bool wheelchair = true;
    bool water = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Register New Municipal Facility', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Facility Name *', hintText: 'e.g. MG Road Metro Restroom'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<FacilityType>(
                          value: type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(value: FacilityType.TOILET, child: Text('Public Restroom (Toilet)')),
                            DropdownMenuItem(value: FacilityType.DRINKING_WATER, child: Text('Drinking Water Point')),
                          ],
                          onChanged: (val) => setDialogState(() => type = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: wardCtrl,
                          decoration: const InputDecoration(labelText: 'Ward *', hintText: 'Ward-12'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Address Description *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Latitude *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lonCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Longitude *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: openCtrl,
                          decoration: const InputDecoration(labelText: 'Opening Time (HH:MM)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: closeCtrl,
                          decoration: const InputDecoration(labelText: 'Closing Time (HH:MM)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<GenderAccess>(
                    value: gender,
                    decoration: const InputDecoration(labelText: 'Gender Access'),
                    items: const [
                      DropdownMenuItem(value: GenderAccess.UNISEX, child: Text('Unisex / All')),
                      DropdownMenuItem(value: GenderAccess.MALE, child: Text('Male Only')),
                      DropdownMenuItem(value: GenderAccess.FEMALE, child: Text('Female Only')),
                    ],
                    onChanged: (val) => setDialogState(() => gender = val!),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Wheelchair Accessible'),
                    value: wheelchair,
                    onChanged: (val) => setDialogState(() => wheelchair = val ?? true),
                  ),
                  CheckboxListTile(
                    title: const Text('Water Availability Guaranteed'),
                    value: water,
                    onChanged: (val) => setDialogState(() => water = val ?? true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) return;
                ref.read(facilityAdminProvider.notifier).createFacility(
                      name: nameCtrl.text.trim(),
                      type: type,
                      latitude: double.tryParse(latCtrl.text.trim()) ?? 12.9716,
                      longitude: double.tryParse(lonCtrl.text.trim()) ?? 77.5946,
                      address: addressCtrl.text.trim(),
                      ward: wardCtrl.text.trim(),
                      genderAccess: gender,
                      wheelchairAccessible: wheelchair,
                      waterAvailability: water,
                      openingTime: openCtrl.text.trim(),
                      closingTime: closeCtrl.text.trim(),
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Facility registered and QR Code generated automatically!')),
                );
              },
              child: const Text('Register & Generate QR'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditFacilityDialog(BuildContext context, FacilityModel facility) {
    final openCtrl = TextEditingController(text: facility.openingTime);
    final closeCtrl = TextEditingController(text: facility.closingTime);
    GenderAccess gender = facility.genderAccess;
    bool wheelchair = facility.wheelchairAccessible;
    bool water = facility.waterAvailability;
    FacilityStatus status = facility.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Facility: ${facility.facilityId}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: openCtrl,
                        decoration: const InputDecoration(labelText: 'Opening Time'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: closeCtrl,
                        decoration: const InputDecoration(labelText: 'Closing Time'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<GenderAccess>(
                  value: gender,
                  decoration: const InputDecoration(labelText: 'Gender Access'),
                  items: const [
                    DropdownMenuItem(value: GenderAccess.UNISEX, child: Text('Unisex')),
                    DropdownMenuItem(value: GenderAccess.MALE, child: Text('Male Only')),
                    DropdownMenuItem(value: GenderAccess.FEMALE, child: Text('Female Only')),
                  ],
                  onChanged: (val) => setDialogState(() => gender = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FacilityStatus>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Operational Status'),
                  items: const [
                    DropdownMenuItem(value: FacilityStatus.ACTIVE, child: Text('Active')),
                    DropdownMenuItem(value: FacilityStatus.UNDER_MAINTENANCE, child: Text('Under Maintenance')),
                    DropdownMenuItem(value: FacilityStatus.CLOSED, child: Text('Closed')),
                    DropdownMenuItem(value: FacilityStatus.DEMOLISHED, child: Text('Demolished')),
                  ],
                  onChanged: (val) => setDialogState(() => status = val!),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Wheelchair Accessible'),
                  value: wheelchair,
                  onChanged: (val) => setDialogState(() => wheelchair = val ?? true),
                ),
                CheckboxListTile(
                  title: const Text('Water Availability'),
                  value: water,
                  onChanged: (val) => setDialogState(() => water = val ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                ref.read(facilityAdminProvider.notifier).editFacility(
                      facilityId: facility.facilityId,
                      genderAccess: gender,
                      wheelchairAccessible: wheelchair,
                      waterAvailability: water,
                      openingTime: openCtrl.text.trim(),
                      closingTime: closeCtrl.text.trim(),
                      status: status,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Facility details updated with audit log!')),
                );
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrModal(BuildContext context, FacilityModel facility) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Facility QR Code', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(facility.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
            Text(facility.facilityId, style: GoogleFonts.outfit(color: AppTheme.primaryTeal, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: QrImageView(
                data: facility.facilityId, // Strictly contains Facility ID
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Payload: "${facility.facilityId}"\nMounted at on-site asset entry for Citizen & Worker scanning.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  void _showDemolishDialog(BuildContext context, FacilityModel facility) {
    final reasonCtrl = TextEditingController(text: 'Decommissioned for municipal infrastructure overhaul');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Demolish Facility Asset', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Marking "${facility.name}" as Demolished will:\n'
              '• Hide this asset from citizen maps.\n'
              '• Invalidate its QR code (scanners will suggest nearest alternatives).\n'
              '• Preserve complete audit history (database record is never deleted).',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Reason for Demolition *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(facilityAdminProvider.notifier).demolishFacility(facility.facilityId, reasonCtrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Facility demolished. Hidden from map with audit preserved.')),
              );
            },
            child: const Text('Demolish Asset'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, FacilityModel facility) {
    final reasonCtrl = TextEditingController(text: 'Facility restored and reopened to public');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restore_from_trash_rounded, color: Colors.green),
            const SizedBox(width: 8),
            Text('Restore Demolished Facility', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restoring "${facility.name}" will make it Active again on Citizen maps and reactivate its QR code.',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[800]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: 'Restoration Audit Reason *'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              ref.read(facilityAdminProvider.notifier).restoreFacility(facility.facilityId, reasonCtrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Facility restored to active status on maps!')),
              );
            },
            child: const Text('Restore Facility'),
          ),
        ],
      ),
    );
  }

  void _showAuditHistoryDialog(BuildContext context, FacilityModel facility) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Audit History: ${facility.facilityId}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.fiber_new_rounded, color: Colors.green),
                title: const Text('Asset Created'),
                subtitle: const Text('Initial registration with QR Code generated'),
                trailing: Text('Created', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded, color: Colors.blue),
                title: const Text('Timings & Amenities Updated'),
                subtitle: const Text('Verified by Municipal Sanitation Supervisor'),
                trailing: Text('Updated', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  Icon(icon, color: color, size: 24),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.surfaceDark)),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard({
    required String ticketId,
    required String facility,
    required String worker,
    required double faceScore,
    required String gpsStatus,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.primaryTeal)),
                  const SizedBox(height: 4),
                  Text(facility, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Completed by $worker', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text('Face Match: $faceScore%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: Text('GPS: $gpsStatus', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  )
                ],
              ),
            ),
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () {},
                  child: const Text('Reject (Require Reason)'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Approve & Resolve'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
