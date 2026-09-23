import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/theme.dart';
import '../../../../shared/models/facility_model.dart';

class DemolishedFacilityDialog extends StatelessWidget {
  final String facilityId;
  final String message;
  final FacilityModel? demolishedFacility;
  final List<FacilityModel> alternatives;
  final Function(FacilityModel) onSelectAlternative;

  const DemolishedFacilityDialog({
    super.key,
    required this.facilityId,
    required this.message,
    this.demolishedFacility,
    required this.alternatives,
    required this.onSelectAlternative,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.do_not_disturb_on_rounded, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Facility Closed', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.red[900])),
                Text(facilityId, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              ],
            ),
          )
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.red[900], fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Nearest Operational Alternatives',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.surfaceDark),
              ),
              const SizedBox(height: 10),
              if (alternatives.isEmpty)
                Text('No nearby alternatives found in this ward.', style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600]))
              else
                ...alternatives.map((alt) => _buildAlternativeCard(context, alt)),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close Notice'),
        ),
      ],
    );
  }

  Widget _buildAlternativeCard(BuildContext context, FacilityModel alt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryTeal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            alt.facilityType == FacilityType.TOILET ? Icons.wc_rounded : Icons.water_drop_rounded,
            color: AppTheme.primaryTeal,
            size: 22,
          ),
        ),
        title: Text(alt.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(
          '${alt.walkingTimeMinutes ?? 3} mins walk (${alt.distanceMeters?.toInt() ?? 200}m) • ${alt.ward}',
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primaryTeal),
        onTap: () {
          Navigator.pop(context);
          onSelectAlternative(alt);
        },
      ),
    );
  }
}
