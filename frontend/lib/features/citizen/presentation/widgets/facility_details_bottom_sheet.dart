import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme.dart';
import '../../../../shared/models/facility_model.dart';

class FacilityDetailsBottomSheet extends StatelessWidget {
  final FacilityModel facility;
  final VoidCallback onNavigate;
  final VoidCallback onRaiseTicket;
  final VoidCallback onRateFacility;

  const FacilityDetailsBottomSheet({
    super.key,
    required this.facility,
    required this.onNavigate,
    required this.onRaiseTicket,
    required this.onRateFacility,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = AppTheme.getConfidenceColor(facility.confidenceScore);

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

            // Header with Type Icon, Name, and Confidence Score
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    facility.facilityType == FacilityType.TOILET ? Icons.wc_rounded : Icons.water_drop_rounded,
                    color: AppTheme.primaryTeal,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(facility.facilityId, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal)),
                          const SizedBox(width: 8),
                          Text('• ${facility.ward}', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(facility.name, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.surfaceDark)),
                      const SizedBox(height: 2),
                      Text(facility.address, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                // Confidence Score Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scoreColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${facility.confidenceScore.toInt()}%',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: scoreColor),
                      ),
                      Text(
                        'Confidence',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: scoreColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Metrics Bar: Distance, Walking Time, Last Verified
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricColumn(
                    Icons.directions_walk_rounded,
                    '${facility.walkingTimeMinutes ?? 2} mins',
                    '${facility.distanceMeters?.toInt() ?? 150}m away',
                  ),
                  Container(height: 30, width: 1, color: Colors.grey[300]),
                  _buildMetricColumn(
                    Icons.access_time_rounded,
                    '${facility.openingTime} - ${facility.closingTime}',
                    'Daily Timings',
                  ),
                  Container(height: 30, width: 1, color: Colors.grey[300]),
                  _buildMetricColumn(
                    Icons.verified_user_outlined,
                    facility.lastVerifiedFormatted ?? 'Verified Today',
                    'Last Verified',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amenities & Attributes Grid
            Text('Amenities & Access', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildAmenityTile(
                    facility.waterAvailability ? Icons.water_drop_rounded : Icons.water_damage_outlined,
                    'Water Supply',
                    facility.waterAvailability ? 'Available' : 'Unavailable',
                    facility.waterAvailability ? Colors.blue : Colors.red,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAmenityTile(
                    facility.wheelchairAccessible ? Icons.accessible_forward_rounded : Icons.not_accessible_rounded,
                    'Wheelchair Access',
                    facility.wheelchairAccessible ? 'Ramp Available' : 'No Ramp',
                    facility.wheelchairAccessible ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildAmenityTile(
                    Icons.wc_rounded,
                    'Gender Access',
                    facility.genderAccess.name,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppTheme.primaryTeal),
                    ),
                    icon: const Icon(Icons.navigation_rounded, color: AppTheme.primaryTeal),
                    label: const Text('Navigate', style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w600)),
                    onPressed: onNavigate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Colors.amber),
                    ),
                    icon: const Icon(Icons.report_problem_outlined, color: Colors.amber),
                    label: const Text('Report Issue', style: TextStyle(color: AppTheme.surfaceDark, fontWeight: FontWeight.w600)),
                    onPressed: onRaiseTicket,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.star_rate_rounded, size: 18),
                    label: const Text('Rate', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: onRateFacility,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricColumn(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryTeal),
        const SizedBox(height: 4),
        Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(subtitle, style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 11)),
      ],
    );
  }

  Widget _buildAmenityTile(IconData icon, String title, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(title, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[700]), textAlign: TextAlign.center),
          Text(status, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
