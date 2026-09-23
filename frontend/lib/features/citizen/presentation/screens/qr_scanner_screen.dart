import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/facility_model.dart';
import '../../state/citizen_map_notifier.dart';
import '../widgets/demolished_facility_dialog.dart';
import '../widgets/facility_details_bottom_sheet.dart';
import '../widgets/raise_ticket_modal.dart';
import '../widgets/rate_facility_dialog.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualIdController = TextEditingController(text: 'FAC-KOC-MD-A8F1');
  bool _isProcessing = false;

  final List<Map<String, String>> _quickTestQrs = [
    {
      'id': 'FAC-KOC-MD-A8F1',
      'label': 'Marine Drive Restroom (Active)',
      'type': 'TOILET',
    },
    {
      'id': 'FAC-KOC-MG-C349',
      'label': 'MG Road Water Point (Active)',
      'type': 'WATER',
    },
    {
      'id': 'FAC-KOC-FK-9B04',
      'label': 'Fort Kochi Restroom',
      'type': 'TOILET',
    },
    {
      'id': 'FAC-KOC-VY-D102',
      'label': 'Vyttila Restroom (Maintenance)',
      'type': 'TOILET',
    },
    {
      'id': 'FAC-DEMOLISHED-TEST',
      'label': 'Demolished Asset (Phase 5 Demo)',
      'type': 'DEMOLISHED',
    },
  ];

  @override
  void dispose() {
    _scannerController.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  Future<void> _handleScannedCode(String rawPayload) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final cleanId = rawPayload.trim();
    final apiClient = ref.read(apiClientProvider);
    final mapState = ref.read(citizenMapProvider);

    try {
      final response = await apiClient.dio.get(
        '/qr/scan/$cleanId',
        queryParameters: {
          'user_lat': mapState.userLocation.latitude,
          'user_lon': mapState.userLocation.longitude,
        },
      );
      final data = response.data;
      final isOperational = data['is_operational'] ?? true;

      if (!mounted) return;

      if (!isOperational) {
        // Demolished Facility Handling (Phase 5 Rule: Display notice + nearest active alternatives)
        final List altData = data['nearest_alternatives'] ?? [];
        final alternatives = altData.map((json) => FacilityModel.fromJson(json)).toList();

        showDialog(
          context: context,
          builder: (ctx) => DemolishedFacilityDialog(
            facilityId: cleanId,
            message: data['message'] ?? 'This municipal facility has been demolished or decommissioned.',
            alternatives: alternatives,
            onSelectAlternative: (alt) {
              ref.read(citizenMapProvider.notifier).selectFacility(alt);
              ref.read(citizenMapProvider.notifier).startNavigation(alt);
              Navigator.pop(context);
            },
          ),
        ).then((_) {
          if (mounted) setState(() => _isProcessing = false);
        });
      } else {
        // Operational Facility Handling: Open Facility Details with working Report, Rate & Navigate
        final facility = FacilityModel.fromJson(data['facility']);
        ref.read(citizenMapProvider.notifier).selectFacility(facility);

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => FacilityDetailsBottomSheet(
            facility: facility,
            onNavigate: () {
              Navigator.pop(ctx);
              ref.read(citizenMapProvider.notifier).startNavigation(facility);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Starting GPS walking route to ${facility.name}...')),
              );
            },
            onRaiseTicket: () {
              Navigator.pop(ctx);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => RaiseTicketModal(facility: facility),
              );
            },
            onRateFacility: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (_) => RateFacilityDialog(facility: facility),
              );
            },
          ),
        ).then((_) {
          if (mounted) setState(() => _isProcessing = false);
        });
      }
    } catch (e) {
      if (!mounted) return;

      // Fallback lookup from locally loaded facilities
      final localMatch = mapState.allFacilities.where((f) =>
          f.facilityId.toLowerCase() == cleanId.toLowerCase() ||
          f.name.toLowerCase().contains(cleanId.toLowerCase())).firstOrNull;

      if (localMatch != null) {
        if (localMatch.status == FacilityStatus.DEMOLISHED) {
          final alternatives = mapState.allFacilities
              .where((f) => f.status == FacilityStatus.ACTIVE && f.facilityType == localMatch.facilityType)
              .take(3)
              .toList();

          showDialog(
            context: context,
            builder: (ctx) => DemolishedFacilityDialog(
              facilityId: cleanId,
              message: 'This facility has been decommissioned by Kochi Municipal Corporation.',
              alternatives: alternatives,
              onSelectAlternative: (alt) {
                ref.read(citizenMapProvider.notifier).selectFacility(alt);
                ref.read(citizenMapProvider.notifier).startNavigation(alt);
                Navigator.pop(context);
              },
            ),
          ).then((_) {
            if (mounted) setState(() => _isProcessing = false);
          });
          return;
        }

        ref.read(citizenMapProvider.notifier).selectFacility(localMatch);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => FacilityDetailsBottomSheet(
            facility: localMatch,
            onNavigate: () {
              Navigator.pop(ctx);
              ref.read(citizenMapProvider.notifier).startNavigation(localMatch);
              Navigator.pop(context);
            },
            onRaiseTicket: () {
              Navigator.pop(ctx);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => RaiseTicketModal(facility: localMatch),
              );
            },
            onRateFacility: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (_) => RateFacilityDialog(facility: localMatch),
              );
            },
          ),
        ).then((_) {
          if (mounted) setState(() => _isProcessing = false);
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red[800],
          content: Text('Invalid QR Code: No facility matched with ID "$cleanId".'),
        ),
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Scan Facility QR Code', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            tooltip: 'Toggle Flashlight',
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            tooltip: 'Switch Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live Camera Scanner View
          MobileScanner(
            controller: _scannerController,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Webcam Access Prompt in Browser',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please click "Allow" in Chrome for camera access, or use the quick test facility chips below.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final val = barcode.rawValue;
                if (val != null && val.isNotEmpty) {
                  _handleScannedCode(val);
                  break;
                }
              }
            },
          ),

          // High-Tech Viewfinder Target Box Overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accentCyan, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 3), left: BorderSide(color: Colors.white, width: 3)))),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 3), right: BorderSide(color: Colors.white, width: 3)))),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 3), left: BorderSide(color: Colors.white, width: 3)))),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 3), right: BorderSide(color: Colors.white, width: 3)))),
                  ),
                  if (_isProcessing)
                    const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)),
                ],
              ),
            ),
          ),

          // Bottom Manual Entry & Quick-Test QR Chips
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.90),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Point camera at the QR code mounted on the facility, or select a test asset below:',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  // Quick test QR chips for instant testing
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickTestQrs.map((item) {
                        final isDemolished = item['type'] == 'DEMOLISHED';
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: Icon(
                              isDemolished
                                  ? Icons.do_not_disturb_on_rounded
                                  : item['type'] == 'WATER'
                                      ? Icons.water_drop_rounded
                                      : Icons.wc_rounded,
                              size: 14,
                              color: isDemolished ? Colors.redAccent : AppTheme.primaryTeal,
                            ),
                            label: Text(
                              item['label']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDemolished ? Colors.redAccent : Colors.white,
                              ),
                            ),
                            backgroundColor: Colors.white12,
                            onPressed: _isProcessing ? null : () => _handleScannedCode(item['id']!),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Manual ID Text Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualIdController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter Facility ID (e.g. FAC-KOC-MD-A8F1)...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white12,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: _isProcessing
                            ? null
                            : () => _handleScannedCode(_manualIdController.text.trim()),
                        child: const Text('Scan ID'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
