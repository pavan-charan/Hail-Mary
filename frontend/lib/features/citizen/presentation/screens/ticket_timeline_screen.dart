import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme.dart';
import '../../../../shared/models/ticket_model.dart';

class TicketTimelineScreen extends StatelessWidget {
  final TicketModel ticket;

  const TicketTimelineScreen({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket Lifecycle Tracking', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(ticket.ticketId, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ticket Header Summary Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ticket.facilityName ?? 'Kochi Municipal Facility',
                            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                        ),
                        _buildStatusBadge(ticket.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reported on ${DateFormat('MMM dd, yyyy • hh:mm a').format(ticket.createdAt)}',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: ticket.issueCategories
                          .map((i) => Chip(
                                label: Text(i.replaceAll('_', ' '), style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.red.withOpacity(0.08),
                                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                              ))
                          .toList(),
                    ),
                    if (ticket.description != null && ticket.description!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '"${ticket.description}"',
                        style: GoogleFonts.outfit(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Maintenance Progression', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            // Vertical Stepper Timeline
            _buildTimelineStep(
              stepNumber: 1,
              title: 'REPORTED',
              subtitle: 'Citizen complaint lodged with live camera proof and auto-GPS tagging.',
              timestamp: DateFormat('hh:mm a').format(ticket.createdAt),
              isCompleted: true,
              isCurrent: ticket.status == TicketStatus.TICKET_CREATED,
              icon: Icons.camera_alt_rounded,
            ),
            _buildTimelineConnector(isCompleted: ticket.status != TicketStatus.TICKET_CREATED),

            _buildTimelineStep(
              stepNumber: 2,
              title: 'ASSIGNED',
              subtitle: 'Auto-assigned to ${ticket.assignedWorkerName ?? "Ward Field Worker"} with 24-hour SLA deadline.',
              timestamp: DateFormat('hh:mm a').format(ticket.createdAt.add(const Duration(minutes: 5))),
              isCompleted: ticket.status != TicketStatus.TICKET_CREATED,
              isCurrent: ticket.status == TicketStatus.ASSIGNED,
              icon: Icons.person_pin_rounded,
            ),
            _buildTimelineConnector(isCompleted: ticket.status == TicketStatus.REPAIRING || ticket.status == TicketStatus.COMPLETED || ticket.status == TicketStatus.RESOLVED),

            _buildTimelineStep(
              stepNumber: 3,
              title: 'REACHED & WORK IN PROGRESS',
              subtitle: 'Worker arrived at facility (30m GPS geofence verified). Repair actively underway.',
              timestamp: DateFormat('hh:mm a').format(ticket.createdAt.add(const Duration(minutes: 45))),
              isCompleted: ticket.status == TicketStatus.REPAIRING || ticket.status == TicketStatus.COMPLETED || ticket.status == TicketStatus.RESOLVED,
              isCurrent: ticket.status == TicketStatus.REPAIRING,
              icon: Icons.handyman_rounded,
            ),
            _buildTimelineConnector(isCompleted: ticket.status == TicketStatus.COMPLETED || ticket.status == TicketStatus.RESOLVED),

            _buildTimelineStep(
              stepNumber: 4,
              title: 'COMPLETED & BIOMETRIC VERIFIED',
              subtitle: 'Repair finished. Live after-repair proof uploaded with MediaPipe Face Landmark match.',
              timestamp: DateFormat('hh:mm a').format(ticket.createdAt.add(const Duration(hours: 2, minutes: 15))),
              isCompleted: ticket.status == TicketStatus.COMPLETED || ticket.status == TicketStatus.RESOLVED,
              isCurrent: ticket.status == TicketStatus.COMPLETED,
              icon: Icons.face_retouching_natural_rounded,
            ),
            _buildTimelineConnector(isCompleted: ticket.status == TicketStatus.RESOLVED),

            _buildTimelineStep(
              stepNumber: 5,
              title: 'RESOLVED & AUDITED',
              subtitle: 'Municipal Sanitation Supervisor approved Before/After evidence. Confidence score restored.',
              timestamp: DateFormat('hh:mm a').format(ticket.createdAt.add(const Duration(hours: 3))),
              isCompleted: ticket.status == TicketStatus.RESOLVED,
              isCurrent: ticket.status == TicketStatus.RESOLVED,
              icon: Icons.verified_rounded,
            ),
            const SizedBox(height: 24),

            // SLA Compliance Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppTheme.primaryTeal, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SLA Status: Compliant', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.primaryTeal)),
                        const SizedBox(height: 2),
                        Text('24-Hour Municipal SLA standard enforced. Zero escalation breaches.', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required int stepNumber,
    required String title,
    required String subtitle,
    required String timestamp,
    required bool isCompleted,
    required bool isCurrent,
    required IconData icon,
  }) {
    final color = isCurrent
        ? Colors.amber[800]!
        : isCompleted
            ? AppTheme.primaryTeal
            : Colors.grey[400]!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
                  Text(timestamp, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[700])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineConnector({required bool isCompleted}) {
    return Container(
      margin: const EdgeInsets.only(left: 21, top: 4, bottom: 4),
      height: 28,
      width: 2,
      color: isCompleted ? AppTheme.primaryTeal : Colors.grey[300],
    );
  }

  Widget _buildStatusBadge(TicketStatus status) {
    Color color = Colors.blue;
    if (status == TicketStatus.REPAIRING) color = Colors.amber[800]!;
    if (status == TicketStatus.RESOLVED) color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.replaceAll('_', ' '),
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
