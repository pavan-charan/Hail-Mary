import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
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

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitializing = true;
  String? _cameraError;
  bool _isProcessing = false;
  late AnimationController _laserController;

  final TextEditingController _manualIdController = TextEditingController(text: 'FAC-KOC-MD-A8F1');

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
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  @override
  void dispose() {
    _laserController.dispose();
    _cameraController?.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isCameraInitializing = true;
      _cameraError = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = 'No webcam or camera device detected on this system.';
        });
        return;
      }

      // On Web/Laptop, prioritize front or first available webcam
      int targetIndex = 0;
      if (kIsWeb) {
        targetIndex = 0;
      } else {
        final backIdx = _cameras.indexWhere((cam) => cam.lensDirection == CameraLensDirection.back);
        if (backIdx != -1) targetIndex = backIdx;
      }

      _selectedCameraIndex = targetIndex;
      await _startCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = 'Camera access request: $e';
        });
      }
    }
  }

  Future<void> _startCameraController(CameraDescription camera) async {
    try {
      await _cameraController?.dispose();

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
          _cameraError = 'Webcam initialization: $e';
        });
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only 1 camera available on this device.')),
      );
      return;
    }

    setState(() => _isCameraInitializing = true);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _captureAndScanQr() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not ready. Tap any quick test chip below to test instantly!')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final apiClient = ref.read(apiClientProvider);
      final decodeRes = await apiClient.dio.post('/qr/decode-image', data: {
        'image_base64': base64String,
      });

      final decodeData = decodeRes.data;
      if (decodeData['success'] == true && decodeData['facility_id'] != null) {
        final decodedId = decodeData['facility_id'].toString();
        await _handleScannedCode(decodedId);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.orange[900],
              content: Text(decodeData['message'] ?? 'No QR detected in photo. Hold the code closer and retry, or tap a test chip below.'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red[800],
            content: Text('Error scanning camera photo: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
    final isCameraReady = !_isCameraInitializing && _cameraError == null && _cameraController != null && _cameraController!.value.isInitialized;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Scan Facility QR Code', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            tooltip: 'Switch Camera',
            onPressed: _switchCamera,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Retry Camera',
            onPressed: _initializeCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Viewfinder Area
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Camera Stream or Placeholder
                if (isCameraReady)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize?.height ?? 400,
                        height: _cameraController!.value.previewSize?.width ?? 600,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                else if (_isCameraInitializing)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primaryTeal),
                        SizedBox(height: 16),
                        Text('Opening webcam stream...', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  )
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.videocam_rounded, color: AppTheme.primaryTeal, size: 54),
                          const SizedBox(height: 12),
                          Text(
                            'Webcam Preview Ready',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Click "Allow" in Chrome or tap Request Access below:',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal, foregroundColor: Colors.white),
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Request Camera Permission'),
                            onPressed: _initializeCamera,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Viewfinder Target Frame
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.accentCyan, width: 2),
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.black.withOpacity(0.15),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(width: 18, height: 18, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 3), left: BorderSide(color: Colors.white, width: 3)))),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(width: 18, height: 18, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white, width: 3), right: BorderSide(color: Colors.white, width: 3)))),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(width: 18, height: 18, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 3), left: BorderSide(color: Colors.white, width: 3)))),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(width: 18, height: 18, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white, width: 3), right: BorderSide(color: Colors.white, width: 3)))),
                      ),
                      // Animated Laser
                      AnimatedBuilder(
                        animation: _laserController,
                        builder: (context, child) {
                          return Positioned(
                            top: 15 + (_laserController.value * 205),
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan,
                                boxShadow: [
                                  BoxShadow(color: AppTheme.accentCyan.withOpacity(0.8), blurRadius: 8, spreadRadius: 1.5),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (_isProcessing)
                        const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan)),
                    ],
                  ),
                ),

                // Capture Button placed below viewfinder
                Positioned(
                  bottom: 16,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 4,
                    ),
                    icon: _isProcessing
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: Text(_isProcessing ? 'Analyzing Frame...' : 'Capture & Scan QR Code', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13)),
                    onPressed: _isProcessing ? null : _captureAndScanQr,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Quick-Test and Manual Entry Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Point webcam at QR code or tap any quick-test asset below:',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 10),

                // Quick test QR chips
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
                const SizedBox(height: 10),

                // Manual ID Text Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualIdController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter Facility ID (e.g. FAC-KOC-MD-A8F1)...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white12,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ],
      ),
    );
  }
}
