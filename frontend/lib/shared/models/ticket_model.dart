enum TicketStatus {
  TICKET_CREATED,
  ASSIGNED,
  REACHED,
  REPAIRING,
  COMPLETED,
  UNDER_VERIFICATION,
  RESOLVED,
  REJECTED,
}

class TicketModel {
  final int id;
  final String ticketId;
  final int facilityId;
  final String? facilityCustomId;
  final String? facilityName;
  final int reporterId;
  final int? assignedWorkerId;
  final String? assignedWorkerName;
  final List<String> issueCategories;
  final String? description;
  final TicketStatus status;
  final int reportCount;
  final bool isMerged;
  final double reporterLatitude;
  final double reporterLongitude;
  final double? faceMatchScore;
  final bool faceVerified;
  final String? rejectionReason;
  final DateTime createdAt;

  TicketModel({
    required this.id,
    required this.ticketId,
    required this.facilityId,
    this.facilityCustomId,
    this.facilityName,
    required this.reporterId,
    this.assignedWorkerId,
    this.assignedWorkerName,
    required this.issueCategories,
    this.description,
    required this.status,
    required this.reportCount,
    this.isMerged = false,
    required this.reporterLatitude,
    required this.reporterLongitude,
    this.faceMatchScore,
    required this.faceVerified,
    this.rejectionReason,
    required this.createdAt,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    TicketStatus tStatus = TicketStatus.TICKET_CREATED;
    for (var s in TicketStatus.values) {
      if (s.name == json['status']) {
        tStatus = s;
        break;
      }
    }

    List<String> issues = [];
    if (json['issue_categories'] is List) {
      issues = (json['issue_categories'] as List).map((e) => e.toString()).toList();
    }

    return TicketModel(
      id: json['id'] ?? 0,
      ticketId: json['ticket_id'] ?? '',
      facilityId: json['facility_id'] ?? 0,
      facilityCustomId: json['facility_custom_id'],
      facilityName: json['facility_name'],
      reporterId: json['reporter_id'] ?? 0,
      assignedWorkerId: json['assigned_worker_id'],
      assignedWorkerName: json['assigned_worker_name'],
      issueCategories: issues,
      description: json['description'],
      status: tStatus,
      reportCount: json['report_count'] ?? 1,
      isMerged: json['is_merged'] ?? false,
      reporterLatitude: (json['reporter_latitude'] as num?)?.toDouble() ?? 0.0,
      reporterLongitude: (json['reporter_longitude'] as num?)?.toDouble() ?? 0.0,
      faceMatchScore: (json['face_match_score'] as num?)?.toDouble(),
      faceVerified: json['face_verified'] ?? false,
      rejectionReason: json['rejection_reason'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
