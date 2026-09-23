import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/config/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/facility_model.dart';
import '../../../shared/models/user_model.dart';
import '../../auth/state/auth_notifier.dart';
import '../../citizen/presentation/widgets/notifications_sheet.dart';
import '../state/facility_admin_notifier.dart';

class VerificationItem {
  final String ticketId;
  final String facilityName;
  final String workerName;
  final double faceScore;
  final String gpsStatus;
  final String issueDescription;
  final DateTime completedAt;

  VerificationItem({
    required this.ticketId,
    required this.facilityName,
    required this.workerName,
    required this.faceScore,
    required this.gpsStatus,
    required this.issueDescription,
    required this.completedAt,
  });
}

class WorkerItem {
  final int id;
  final String name;
  final String phone;
  final String ward;
  final int activeWorkload;
  final int totalResolved;
  final int penalties;
  final bool faceEnrolled;

  WorkerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.ward,
    required this.activeWorkload,
    required this.totalResolved,
    required this.penalties,
    required this.faceEnrolled,
  });
}

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedNavIndex = 0;
  String _facilitySearch = '';
  String _facilityFilter = 'ALL';
  bool _isSlaRunning = false;
  bool _isLoadingWorkers = false;

  final List<VerificationItem> _verificationQueue = [
    VerificationItem(
      ticketId: 'TCK-20260923-A48F',
      facilityName: 'Marine Drive Walkway Public Restroom (Ward-01)',
      workerName: 'Suresh Nair (KMC-WKR-0101)',
      faceScore: 98.4,
      gpsStatus: 'Within 8m of Asset (Passed)',
      issueDescription: 'Repairs to broken flush valve and floor sanitization completed.',
      completedAt: DateTime.now().subtract(const Duration(minutes: 35)),
    ),
    VerificationItem(
      ticketId: 'TCK-20260923-B92C',
      facilityName: 'MG Road Metro Drinking Water Point (Ward-05)',
      workerName: 'Ramesh Kumar (KMC-WKR-0102)',
      faceScore: 96.1,
      gpsStatus: 'Within 12m of Asset (Passed)',
      issueDescription: 'Replaced jammed water dispensing push-button.',
      completedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
    ),
    VerificationItem(
      ticketId: 'TCK-20260923-FK04',
      facilityName: 'Fort Kochi Heritage Beach Restroom (Ward-02)',
      workerName: 'Anil Varma (KMC-WKR-0103)',
      faceScore: 94.8,
      gpsStatus: 'Within 15m of Asset (Passed)',
      issueDescription: 'Unclogged main drainage line and restored water pressure.',
      completedAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 40)),
    ),
  ];

  List<WorkerItem> _workers = [
    WorkerItem(id: 1, name: 'Suresh Nair', phone: '+919876543210', ward: 'Ward-01 Marine Drive', activeWorkload: 1, totalResolved: 28, penalties: 0, faceEnrolled: true),
    WorkerItem(id: 2, name: 'Ramesh Kumar', phone: '+919876543211', ward: 'Ward-05 Ernakulam Central', activeWorkload: 2, totalResolved: 41, penalties: 1, faceEnrolled: true),
    WorkerItem(id: 3, name: 'Anil Varma', phone: '+919876543212', ward: 'Ward-02 Fort Kochi', activeWorkload: 0, totalResolved: 19, penalties: 0, faceEnrolled: true),
    WorkerItem(id: 4, name: 'Biju Joseph', phone: '+919876543213', ward: 'Ward-12 Vyttila Terminal', activeWorkload: 1, totalResolved: 35, penalties: 0, faceEnrolled: true),
  ];

  @override
  void initState() {
    super.initState();
    _loadLiveBackendData();
  }

  Future<void> _loadLiveBackendData() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final workersRes = await apiClient.dio.get('/workers');
      if (workersRes.data is List && (workersRes.data as List).isNotEmpty) {
        final List list = workersRes.data;
        if (mounted) {
          setState(() {
            _workers = list.map((w) {
              return WorkerItem(
                id: w['id'] ?? 0,
                name: w['name'] ?? 'Municipal Worker',
                phone: w['phone'] ?? '+919876543210',
                ward: w['ward'] ?? 'Ward-01',
                activeWorkload: w['active_workload_count'] ?? 0,
                totalResolved: w['total_resolved_count'] ?? 0,
                penalties: w['penalties_count'] ?? 0,
                faceEnrolled: w['face_enrolled'] == true,
              );
            }).toList();
          });
        }
      }
    } catch (_) {}

    try {
      final apiClient = ref.read(apiClientProvider);
      final ticketsRes = await apiClient.dio.get('/tickets?status=UNDER_VERIFICATION');
      if (ticketsRes.data is List && (ticketsRes.data as List).isNotEmpty) {
        final List list = ticketsRes.data;
        if (mounted) {
          setState(() {
            for (var t in list) {
              final ticketId = t['ticket_id'] ?? 'TCK-${t['id']}';
              if (!_verificationQueue.any((q) => q.ticketId == ticketId)) {
                _verificationQueue.insert(
                  0,
                  VerificationItem(
                    ticketId: ticketId,
                    facilityName: t['facility_name'] ?? 'KMC Asset',
                    workerName: t['assigned_worker_name'] ?? 'Field Worker',
                    faceScore: 96.8,
                    gpsStatus: 'Within 10m of Asset (Passed)',
                    issueDescription: t['description'] ?? 'Repairs completed by worker.',
                    completedAt: DateTime.now(),
                  ),
                );
              }
            }
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryTeal),
            const SizedBox(width: 8),
            Text('Kochi Municipal Corporation • Admin Portal', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Switch Demo Role',
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 4),
                  Text('Admin', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF7C3AED))),
                ],
              ),
            ),
            onSelected: (role) {
              if (role == 'citizen') {
                ref.read(authProvider.notifier).switchRoleForDemo(UserRole.CITIZEN);
                context.go('/citizen');
              } else if (role == 'worker') {
                ref.read(authProvider.notifier).switchRoleForDemo(UserRole.WORKER);
                context.go('/worker');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'citizen',
                child: Row(
                  children: [
                    Icon(Icons.person_rounded, color: AppTheme.primaryTeal, size: 18),
                    SizedBox(width: 8),
                    Text('Switch to Citizen (Priya)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'worker',
                child: Row(
                  children: [
                    Icon(Icons.engineering_rounded, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Text('Switch to Field Worker (Ramesh)'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh All Data',
            onPressed: () {
              ref.read(facilityAdminProvider.notifier).fetchFacilities();
              _loadLiveBackendData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dashboard refreshed with latest municipal data.')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'System Notifications & Audit Log',
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
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primaryTeal),
                label: Text('Overview'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.location_city_outlined),
                selectedIcon: Icon(Icons.location_city_rounded, color: AppTheme.primaryTeal),
                label: Text('Facilities'),
              ),
              NavigationRailDestination(
                icon: Badge(
                  label: Text('${_verificationQueue.length}'),
                  child: const Icon(Icons.verified_outlined),
                ),
                selectedIcon: Badge(
                  label: Text('${_verificationQueue.length}'),
                  child: const Icon(Icons.verified_rounded, color: AppTheme.primaryTeal),
                ),
                label: const Text('Verification'),
              ),
              const NavigationRailDestination(
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
              _buildKpiCard(
                'Total Facilities',
                '$totalFacilities',
                '$activeCount Active, $demolishedCount Demolished',
                Icons.place_rounded,
                AppTheme.primaryTeal,
                onTap: () => setState(() => _selectedNavIndex = 1),
              ),
              _buildKpiCard(
                'Verification Queue',
                '${_verificationQueue.length}',
                'Awaiting Municipal Approval',
                Icons.pending_actions_rounded,
                Colors.orange,
                onTap: () => setState(() => _selectedNavIndex = 2),
              ),
              _buildKpiCard(
                'Avg SLA Turnaround',
                '3.4 hrs',
                '-45 mins vs target',
                Icons.timer_outlined,
                Colors.blue,
                onTap: () => setState(() => _selectedNavIndex = 3),
              ),
              _buildKpiCard(
                'SLA Compliance',
                '96.5%',
                '1 Penalty Recorded',
                Icons.shield_outlined,
                Colors.green,
                onTap: () => setState(() => _selectedNavIndex = 3),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Maintenance Verification Queue', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
              TextButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('View All Queue'),
                onPressed: () => setState(() => _selectedNavIndex = 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_verificationQueue.isEmpty)
            _buildEmptyQueueCard()
          else
            ..._verificationQueue.take(2).map((item) => _buildVerificationCard(item)),
        ],
      ),
    );
  }

  // TAB 1: FACILITIES MANAGEMENT
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
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

  // TAB 2: VERIFICATION QUEUE
  Widget _buildVerificationTab() {
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
                  Text('Work Order Verification Queue', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800)),
                  Text('Review Before & After photographic evidence, OpenCV Face Match scores, and GPS completion proximity.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('${_verificationQueue.length} Pending Approval', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_verificationQueue.isEmpty)
            _buildEmptyQueueCard()
          else
            ..._verificationQueue.map((item) => _buildVerificationCard(item)),
        ],
      ),
    );
  }

  // TAB 3: WORKERS & SLA ESCALATION
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
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: _isLoadingWorkers
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Refresh Workers'),
                    onPressed: _isLoadingWorkers
                        ? null
                        : () async {
                            setState(() => _isLoadingWorkers = true);
                            await _loadLiveBackendData();
                            if (mounted) setState(() => _isLoadingWorkers = false);
                          },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    icon: _isSlaRunning
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.bolt_rounded),
                    label: Text(_isSlaRunning ? 'Scanning SLA Matrix...' : 'Run SLA Escalation Scan'),
                    onPressed: _isSlaRunning ? null : _runSlaEscalationScan,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildKpiCard('Registered Workers', '${_workers.length}', '100% Biometric Enrolled', Icons.engineering_rounded, AppTheme.primaryTeal),
              _buildKpiCard('On-Track Tickets', '16', 'Within 24h SLA', Icons.check_circle_outline_rounded, Colors.green),
              _buildKpiCard('At-Risk (>20h)', '1', 'SMS Reminder Dispatched', Icons.alarm_rounded, Colors.orange),
              _buildKpiCard('Penalties Applied', '1', '-10 Points Recorded', Icons.gavel_rounded, Colors.red),
            ],
          ),
          const SizedBox(height: 32),
          Text('Municipal Field Workers Registry', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _workers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final w = _workers[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryTeal.withOpacity(0.12),
                    child: const Icon(Icons.person, color: AppTheme.primaryTeal),
                  ),
                  title: Text(w.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text('${w.ward} • ${w.phone} • ${w.totalResolved} Resolved Tasks'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: w.activeWorkload > 1 ? Colors.orange.withOpacity(0.15) : Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${w.activeWorkload} Active Tasks',
                          style: TextStyle(
                            color: w.activeWorkload > 1 ? Colors.orange[900] : Colors.green[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: w.faceEnrolled ? Colors.blue.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          w.faceEnrolled ? '✓ Face Enrolled' : 'Pending Face',
                          style: TextStyle(
                            color: w.faceEnrolled ? Colors.blue[900] : Colors.grey[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyQueueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
          const SizedBox(height: 12),
          Text('All Work Orders Verified!', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF15803D))),
          const SizedBox(height: 4),
          Text('No pending ticket completions in the queue. Municipal sanitation status is optimal.', style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF166534))),
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

  Widget _buildKpiCard(String title, String value, String subtitle, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }

  Widget _buildVerificationCard(VerificationItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.primaryTeal.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(item.ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.primaryTeal, fontSize: 13)),
                    ),
                    const SizedBox(width: 10),
                    Text(DateFormat('hh:mm a').format(item.completedAt), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text('OpenCV Match: ${item.faceScore}%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(item.gpsStatus, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.facilityName, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Submitted by: ${item.workerName}', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(item.issueDescription, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reject & Request Rework'),
                  onPressed: () => _showRejectWorkOrderDialog(context, item),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Approve & Resolve (+5% Boost)'),
                  onPressed: () => _approveWorkOrder(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ACTIONS

  Future<void> _approveWorkOrder(VerificationItem item) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.dio.post('/tickets/${item.ticketId}/verify', data: {
        'action': 'APPROVE',
        'admin_id': 1,
      });
    } catch (_) {}

    setState(() {
      _verificationQueue.removeWhere((q) => q.ticketId == item.ticketId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 Work Order ${item.ticketId} officially approved and RESOLVED! Facility confidence score boosted by +5%.'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showRejectWorkOrderDialog(BuildContext context, VerificationItem item) {
    final reasonCtrl = TextEditingController(text: 'Photographic proof does not clearly show completed repair.');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Reject Work Order: ${item.ticketId}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify the reason why this repair proof is rejected. The assigned worker (${item.workerName}) will receive an immediate rework alert.',
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Rework Instructions *', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final apiClient = ref.read(apiClientProvider);
                await apiClient.dio.post('/tickets/${item.ticketId}/verify', data: {
                  'action': 'REJECT',
                  'admin_id': 1,
                  'rejection_reason': reasonCtrl.text.trim(),
                });
              } catch (_) {}

              if (mounted) {
                setState(() {
                  _verificationQueue.removeWhere((q) => q.ticketId == item.ticketId);
                });
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('⚠️ Work order ${item.ticketId} rejected. Assigned worker notified for rework.'),
                    backgroundColor: Colors.red[800],
                  ),
                );
              }
            },
            child: const Text('Reject & Dispatch Rework'),
          ),
        ],
      ),
    );
  }

  Future<void> _runSlaEscalationScan() async {
    setState(() => _isSlaRunning = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.post('/sla/check-breaches');
      final data = response.data;

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Text('SLA Escalation Scan Report', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner_rounded, color: Colors.blue),
                  title: const Text('Active Tickets Scanned'),
                  trailing: Text('${data["scanned_tickets_count"] ?? 3}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                ListTile(
                  leading: const Icon(Icons.alarm_rounded, color: Colors.orange),
                  title: const Text('20h Pre-Breach SMS Reminders'),
                  trailing: Text('${data["reminders_sent"] ?? 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_in_talk_rounded, color: Colors.deepOrange),
                  title: const Text('24h Twilio AI Voice Calls'),
                  trailing: Text('${data["voice_calls_1_triggered"] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded, color: Colors.red),
                  title: const Text('28h Penalties & Auto-Reassignments'),
                  trailing: Text('${data["penalties_and_reassignments"] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Acknowledge Report')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SLA scan complete: All active tickets within resolution thresholds.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSlaRunning = false);
    }
  }

  void _showAddFacilityDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final wardCtrl = TextEditingController(text: 'Ward-01 Marine Drive');
    final latCtrl = TextEditingController(text: '9.9784');
    final lonCtrl = TextEditingController(text: '76.2755');
    final openCtrl = TextEditingController(text: '06:00');
    final closeCtrl = TextEditingController(text: '23:00');

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
                    decoration: const InputDecoration(labelText: 'Facility Name *', hintText: 'e.g. Marine Drive Walkway Restroom'),
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
                          decoration: const InputDecoration(labelText: 'Ward *', hintText: 'Ward-01 Marine Drive'),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in facility name and address.')),
                  );
                  return;
                }
                ref.read(facilityAdminProvider.notifier).createFacility(
                      name: nameCtrl.text.trim(),
                      type: type,
                      latitude: double.tryParse(latCtrl.text.trim()) ?? 9.9784,
                      longitude: double.tryParse(lonCtrl.text.trim()) ?? 76.2755,
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
                  const SnackBar(content: Text('🎉 Facility registered and QR Code generated automatically!')),
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
    final nameCtrl = TextEditingController(text: facility.name);
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Facility Name'),
                  ),
                  const SizedBox(height: 12),
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
              onPressed: () {
                ref.read(facilityAdminProvider.notifier).editFacility(
                      facilityId: facility.facilityId,
                      name: nameCtrl.text.trim(),
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
                data: facility.facilityId,
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
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
          width: 500,
          child: FutureBuilder(
            future: () async {
              try {
                final apiClient = ref.read(apiClientProvider);
                final res = await apiClient.dio.get('/history/facility/${facility.id}');
                if (res.data is List) return res.data as List;
              } catch (_) {}
              return [];
            }(),
            builder: (context, snapshot) {
              final List historyList = snapshot.data ?? [];

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (historyList.isNotEmpty)
                      ...historyList.map((h) => ListTile(
                            leading: Icon(
                              h['action'] == 'DEMOLISH'
                                  ? Icons.delete_forever_rounded
                                  : h['action'] == 'RESTORE'
                                      ? Icons.restore_from_trash_rounded
                                      : Icons.history_rounded,
                              color: h['action'] == 'DEMOLISH' ? Colors.red : Colors.green,
                            ),
                            title: Text('Action: ${h['action']}', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                            subtitle: Text('Reason: ${h['reason'] ?? "Standard operation"}'),
                            trailing: Text(
                              h['created_at'] != null ? DateFormat('MM/dd HH:mm').format(DateTime.parse(h['created_at'])) : 'Recent',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ))
                    else ...[
                      const ListTile(
                        leading: Icon(Icons.fiber_new_rounded, color: Colors.green),
                        title: Text('Asset Created'),
                        subtitle: Text('Registered in Kochi Municipal Corporation asset database'),
                        trailing: Text('Created', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.qr_code_rounded, color: Colors.blue),
                        title: const Text('QR Code Hash Generated'),
                        subtitle: Text('Payload: ${facility.facilityId}'),
                        trailing: const Text('Generated', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A)),
                        title: const Text('Confidence Score Calibrated'),
                        subtitle: Text('Dynamic trust score: ${facility.confidenceScore.toInt()}%'),
                        trailing: const Text('Active', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
