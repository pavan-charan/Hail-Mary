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

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualIdController = TextEditingController(text: 'FAC-WARD12-TLT-A8F1');
  bool _isProcessing = false;

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
        // Demolished Facility Handling (Phase 5 Rule)
        final List altData = data['nearest_alternatives'] ?? [];
        final alternatives = altData.map((json) => FacilityModel.fromJson(json)).toList();

        showDialog(
          context: context,
          builder: (ctx) => DemolishedFacilityDialog(
            facilityId: cleanId,
            message: data['message'] ?? 'This facility is no longer operational.',
            alternatives: alternatives,
            onSelectAlternative: (alt) {
              ref.read(citizenMapProvider.notifier).selectFacility(alt);
              Navigator.pop(context);
            },
          ),
        ).then((_) {
          if (mounted) setState(() => _isProcessing = false);
        });
      } else {
        // Operational Facility Handling: Open Facility Details with Report & Rate
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Starting GPS route to ${facility.name}...')),
              );
            },
            onRaiseTicket: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening Ticket Issue Sheet for ${facility.facilityId}...')),
              );
            },
            onRateFacility: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Opening Rating Sheet for ${facility.facilityId}...')),
              );
            },
          ),
        ).then((_) {
          if (mounted) setState(() => _isProcessing = false);
        });
      }
    } catch (e) {
      if (!mounted) return;
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
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live Camera Scanner View
          MobileScanner(
            controller: _scannerController,
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

          // Bottom Manual Entry / Quick Test Console
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Point camera at the QR code mounted on the facility',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualIdController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Or enter Facility ID...',
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
