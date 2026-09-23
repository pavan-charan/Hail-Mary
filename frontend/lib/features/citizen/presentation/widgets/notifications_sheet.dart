import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme.dart';

class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String type; // 'TICKET_UPDATE', 'SLA_REMINDER', 'RATING_RECEIVED', 'DUPLICATE_MERGE'
  final DateTime timestamp;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: 1,
      title: 'Ticket Duplicate Merged',
      message: 'Your report for Marine Drive Restroom has been merged with active work order #TCK-20260923-A48F. Priority escalated to HIGH.',
      type: 'DUPLICATE_MERGE',
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      isRead: false,
    ),
    NotificationItem(
      id: 2,
      title: 'Worker Reached Facility',
      message: 'Worker Ramesh Kumar has checked in within 30m of MG Road Metro Sanitation Point and started repairs.',
      type: 'TICKET_UPDATE',
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
      isRead: false,
    ),
    NotificationItem(
      id: 3,
      title: 'Maintenance Completed',
      message: 'Fort Kochi Beach Restroom repairs completed with live photo and biometric face verification.',
      type: 'TICKET_UPDATE',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: true,
    ),
    NotificationItem(
      id: 4,
      title: 'SLA Escalation Alert',
      message: 'Automated 24h SLA compliance check: All Ward-01 tickets operating within resolution thresholds.',
      type: 'SLA_REMINDER',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryTeal),
                  const SizedBox(width: 10),
                  Text('Notification Center', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                      child: Text('$unreadCount NEW', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    for (var n in _notifications) {
                      n.isRead = true;
                    }
                  });
                },
                child: const Text('Mark all read', style: TextStyle(fontSize: 12, color: AppTheme.primaryTeal, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Notifications List
          Expanded(
            child: ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: _getIconColor(n.type).withOpacity(0.12),
                    child: Icon(_getIcon(n.type), color: _getIconColor(n.type), size: 20),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(n.title, style: GoogleFonts.outfit(fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 14))),
                      Text(DateFormat('hh:mm a').format(n.timestamp), style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(n.message, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[700])),
                  ),
                  trailing: n.isRead ? null : Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primaryTeal, shape: BoxShape.circle)),
                  onTap: () {
                    setState(() => n.isRead = true);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'DUPLICATE_MERGE':
        return Icons.merge_type_rounded;
      case 'SLA_REMINDER':
        return Icons.alarm_rounded;
      case 'RATING_RECEIVED':
        return Icons.star_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'DUPLICATE_MERGE':
        return Colors.orange;
      case 'SLA_REMINDER':
        return Colors.redAccent;
      case 'RATING_RECEIVED':
        return Colors.amber;
      default:
        return AppTheme.primaryTeal;
    }
  }
}
