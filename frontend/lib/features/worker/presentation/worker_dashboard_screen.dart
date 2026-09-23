import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/theme.dart';
import '../../../shared/models/ticket_model.dart';
import '../../auth/state/auth_notifier.dart';

class WorkerDashboardScreen extends ConsumerStatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  ConsumerState<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends ConsumerState<WorkerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<TicketModel> _workerTickets = [
    TicketModel(
      id: 101,
      ticketId: 'TCK-20260923-A48F',
      facilityId: 1,
      facilityCustomId: 'FAC-KOC-MD-TLT1',
      facilityName: 'Marine Drive Walkway Restroom',
      reporterId: 1,
      assignedWorkerId: 42,
      assignedWorkerName: 'Worker Ramesh',
      issueCategories: ['NO_WATER', 'DIRTY'],
      description: 'Water tap dry near Rainbow Bridge and floor needs sanitation',
      status: TicketStatus.ASSIGNED,
      reportCount: 3,
      reporterLatitude: 9.9784,
      reporterLongitude: 76.2755,
      faceVerified: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    TicketModel(
      id: 102,
      ticketId: 'TCK-20260923-B92C',
      facilityId: 2,
      facilityCustomId: 'FAC-KOC-MG-TLT2',
      facilityName: 'MG Road Metro Station Sanitation Point',
      reporterId: 3,
      assignedWorkerId: 42,
      assignedWorkerName: 'Worker Ramesh',
      issueCategories: ['DRINKING_WATER_UNAVAILABLE'],
      description: 'Chilled drinking water point button jammed',
      status: TicketStatus.REPAIRING,
      reportCount: 1,
      reporterLatitude: 9.9723,
      reporterLongitude: 76.2831,
      faceVerified: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Worker Task Station', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
            Text('Ward-12 • ${authState.user?.fullName ?? "Ramesh Kumar"}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppTheme.primaryTeal,
          tabs: const [
            Tab(text: 'Assigned (1)'),
            Tab(text: 'In Progress (1)'),
            Tab(text: 'Completed (0)'),
            Tab(text: 'Penalties (0)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sign Out',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTicketList([_workerTickets[0]]),
          _buildTicketList([_workerTickets[1]]),
          _buildEmptyState('No completed tickets for this shift yet'),
          _buildEmptyState('Zero penalties! Perfect SLA compliance record'),
        ],
      ),
    );
  }

  Widget _buildTicketList(List<TicketModel> tickets) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final t = tickets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.primaryTeal)),
                    _buildStatusChip(t.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(t.facilityName ?? 'Facility Asset', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Reports: ${t.reportCount} merged reports', style: GoogleFonts.outfit(fontSize: 12, color: Colors.amber[800], fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: t.issueCategories.map((issue) => Chip(
                    label: Text(issue.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.red.withOpacity(0.1),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  )).toList(),
                ),
                const SizedBox(height: 14),
                // 4-Stage Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.navigation_outlined, size: 18),
                        label: const Text('Navigate'),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(t.status == TicketStatus.ASSIGNED ? 'Mark Reached' : 'Complete & Face Proof'),
                        onPressed: () => _showStageActionModal(context, t),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(TicketStatus status) {
    Color bg = Colors.blue.withOpacity(0.15);
    Color fg = Colors.blue;
    if (status == TicketStatus.REPAIRING) {
      bg = Colors.amber.withOpacity(0.15);
      fg = Colors.amber[900]!;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status.name.replaceAll('_', ' '),
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(msg, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _showStageActionModal(BuildContext context, TicketModel ticket) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('4-Stage Maintenance Workflow', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Current Step: ${ticket.status.name}', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.gps_fixed, color: AppTheme.primaryTeal),
              title: Text('GPS Verification (30m Geo-Fence)'),
              subtitle: Text('Current Distance: 12 meters (Passed)'),
            ),
            const ListTile(
              leading: Icon(Icons.face_retouching_natural, color: AppTheme.primaryTeal),
              title: Text('MediaPipe Face Verification'),
              subtitle: Text('Worker selfie proof matches profile (98.4%)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stage updated successfully!')),
                );
              },
              child: const Text('Confirm & Proceed Stage'),
            )
          ],
        ),
      ),
    );
  }
}
