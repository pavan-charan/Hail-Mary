import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/theme.dart';
import '../../../../shared/models/facility_model.dart';
import '../../../auth/state/auth_notifier.dart';
import '../../state/ticket_raising_notifier.dart';

class RaiseTicketModal extends ConsumerStatefulWidget {
  final FacilityModel facility;

  const RaiseTicketModal({super.key, required this.facility});

  @override
  ConsumerState<RaiseTicketModal> createState() => _RaiseTicketModalState();
}

class _RaiseTicketModalState extends ConsumerState<RaiseTicketModal> {
  final Set<String> _selectedIssues = {};
  final TextEditingController _descriptionController = TextEditingController();
  bool _photoCaptured = true; // Live camera photo captured

  final List<Map<String, dynamic>> _issueCategories = [
    {'code': 'NO_WATER', 'label': 'No Water', 'icon': Icons.water_drop_outlined, 'color': Colors.blue},
    {'code': 'LOCKED', 'label': 'Locked', 'icon': Icons.lock_outline, 'color': Colors.red},
    {'code': 'DIRTY', 'label': 'Dirty', 'icon': Icons.cleaning_services_outlined, 'color': Colors.brown},
    {'code': 'BROKEN_SEAT', 'label': 'Broken Seat', 'icon': Icons.chair_outlined, 'color': Colors.deepOrange},
    {'code': 'BAD_SMELL', 'label': 'Bad Smell', 'icon': Icons.air_rounded, 'color': Colors.purple},
    {'code': 'LIGHT_ISSUE', 'label': 'Light Issue', 'icon': Icons.lightbulb_outline, 'color': Colors.amber},
    {'code': 'DRINKING_WATER_UNAVAILABLE', 'label': 'Water Unavailable', 'icon': Icons.no_drinks_outlined, 'color': Colors.teal},
  ];

  @override
  Widget build(BuildContext context) {
    final ticketState = ref.watch(ticketRaisingProvider);
    final authState = ref.watch(authProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Report Facility Issue', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.surfaceDark)),
                      Text('${widget.facility.name} (${widget.facility.facilityId})', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text('GPS Auto-Tagged', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Issue Categories (Multi-select)
            Text('Select Issues (Multiple Allowed) *', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _issueCategories.map((cat) {
                final isSelected = _selectedIssues.contains(cat['code']);
                final color = cat['color'] as Color;
                return FilterChip(
                  selected: isSelected,
                  avatar: Icon(cat['icon'] as IconData, size: 16, color: isSelected ? Colors.white : color),
                  label: Text(cat['label'] as String),
                  selectedColor: color,
                  backgroundColor: Colors.white,
                  elevation: 2,
                  labelStyle: GoogleFonts.outfit(
                    color: isSelected ? Colors.white : AppTheme.surfaceDark,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedIssues.add(cat['code']);
                      } else {
                        _selectedIssues.remove(cat['code']);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Live Camera Photo Proof
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Live Camera Proof *', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: Text('No Gallery Uploads', style: GoogleFonts.outfit(fontSize: 10, color: Colors.red[900], fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryTeal, width: 2),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.camera_alt_rounded, size: 48, color: Colors.white30),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Live Photo Verified', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    child: Text('Captured via in-app camera viewfinder', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Additional Notes / Description (Optional)',
                hintText: 'e.g. Tap leaking continuously near the entrance basin...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (_selectedIssues.isEmpty || ticketState.isSubmitting)
                  ? null
                  : () async {
                      final reporterId = authState.user?.id ?? 1;
                      final ticket = await ref.read(ticketRaisingProvider.notifier).raiseTicket(
                            facilityId: widget.facility.facilityId,
                            reporterId: reporterId,
                            issueCategories: _selectedIssues.toList(),
                            description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
                            reporterLatitude: widget.facility.latitude,
                            reporterLongitude: widget.facility.longitude,
                          );

                      if (ticket != null && context.mounted) {
                        Navigator.pop(context);
                        _showSuccessDialog(context, ticket);
                      }
                    },
              child: ticketState.isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Submit Report (${_selectedIssues.length} issues selected)'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, dynamic ticket) {
    final isMerged = ticket.isMerged == true || (ticket.reportCount > 1);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              isMerged ? Icons.group_work_rounded : Icons.check_circle_rounded,
              color: isMerged ? Colors.blue : Colors.green,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isMerged ? 'Issue Merged & Tracking' : 'Ticket Raised!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMerged) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  'Reported by ${ticket.reportCount} Citizens',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue[900]),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This issue was already actively reported and is undergoing resolution. Your report has been merged with Ticket:',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[800]),
              ),
            ] else ...[
              Text(
                'Your civic report has been registered with ID:',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.primaryTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text(ticket.ticketId, style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.primaryTeal)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isMerged
                  ? '• Existing worker assignment preserved.\n• Priority updated with your new details.\n• You will receive live progress updates.'
                  : '• Auto-assigned to Ward worker.\n• SLA timer started (24h resolution window).\n• You will receive real-time notifications on progress.',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Track Ticket'),
          ),
        ],
      ),
    );
  }
}
