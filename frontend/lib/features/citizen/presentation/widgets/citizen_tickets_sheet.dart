import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/ticket_model.dart';
import '../screens/ticket_timeline_screen.dart';

class CitizenTicketsSheet extends ConsumerStatefulWidget {
  const CitizenTicketsSheet({super.key});

  @override
  ConsumerState<CitizenTicketsSheet> createState() => _CitizenTicketsSheetState();
}

class _CitizenTicketsSheetState extends ConsumerState<CitizenTicketsSheet> {
  List<TicketModel> _tickets = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.get('/tickets');
      if (res.data is List) {
        final List list = res.data;
        final List<TicketModel> items = [];
        for (var item in list) {
          final ticketId = item['ticket_id'] ?? 'TCK-${item['id']}';
          final statusStr = item['status']?.toString() ?? 'ASSIGNED';
          TicketStatus status = TicketStatus.ASSIGNED;
          if (statusStr == 'TICKET_CREATED') status = TicketStatus.TICKET_CREATED;
          if (statusStr == 'REPAIRING' || statusStr == 'REACHED') status = TicketStatus.REPAIRING;
          if (statusStr == 'COMPLETED' || statusStr == 'UNDER_VERIFICATION') status = TicketStatus.COMPLETED;
          if (statusStr == 'RESOLVED') status = TicketStatus.RESOLVED;

          items.add(TicketModel(
            id: item['id'] ?? 1,
            ticketId: ticketId,
            facilityId: item['facility_id'] ?? 1,
            facilityCustomId: item['facility_custom_id'] ?? 'FAC-KOC',
            facilityName: item['facility_name'] ?? 'Municipal Civic Asset',
            reporterId: item['reporter_id'] ?? 1,
            assignedWorkerId: item['assigned_worker_id'],
            assignedWorkerName: item['assigned_worker_name'] ?? 'Worker Suresh Nair',
            issueCategories: (item['issue_categories'] is List) ? List<String>.from(item['issue_categories']) : ['DIRTY'],
            description: item['description'],
            status: status,
            reportCount: item['report_count'] ?? 1,
            reporterLatitude: (item['reporter_latitude'] as num?)?.toDouble() ?? 9.9784,
            reporterLongitude: (item['reporter_longitude'] as num?)?.toDouble() ?? 76.2755,
            faceVerified: item['face_verified'] ?? false,
            createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
          ));
        }

        if (mounted) {
          setState(() {
            _tickets = items;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load live tickets. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryTeal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Real-Time Issue Tracker', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18)),
                        Text('${_tickets.length} live municipal work orders', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: TextStyle(color: Colors.red[700])),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _fetchTickets, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _tickets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text('No active tickets found', style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey[600])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _tickets.length,
                            itemBuilder: (context, index) {
                              final t = _tickets[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => TicketTimelineScreen(ticket: t)),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(t.ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppTheme.primaryTeal)),
                                            _buildStatusBadge(t.status),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(t.facilityName ?? 'Facility Asset', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Reported: ${DateFormat('MMM dd, hh:mm a').format(t.createdAt)} • Assigned: ${t.assignedWorkerName ?? "Field Worker"}',
                                          style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          children: t.issueCategories
                                              .map((i) => Chip(
                                                    label: Text(i.replaceAll('_', ' '), style: const TextStyle(fontSize: 10)),
                                                    backgroundColor: Colors.red.withOpacity(0.08),
                                                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                                                  ))
                                              .toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TicketStatus status) {
    Color color = Colors.blue;
    if (status == TicketStatus.REPAIRING) color = Colors.amber[800]!;
    if (status == TicketStatus.COMPLETED) color = Colors.purple;
    if (status == TicketStatus.RESOLVED) color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.name.replaceAll('_', ' '),
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
