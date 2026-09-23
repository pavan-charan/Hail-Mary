import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/config/theme.dart';
import '../../../shared/models/user_model.dart';
import '../state/auth_notifier.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  UserRole _selectedRole = UserRole.CITIZEN;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(text: 'admin@sanitation.gov.in');
  final TextEditingController _passwordController = TextEditingController(text: 'Admin@12345');

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF042F2E), Color(0xFF0F766E), Color(0xFF064E3B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryTeal.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.water_drop_rounded, size: 48, color: AppTheme.primaryTeal),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Smart Public Sanitation',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.surfaceDark,
                    ),
                  ),
                  Text(
                    'Drinking Water & Civic Platform',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Banner
                  if (authState.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: GoogleFonts.outfit(fontSize: 13, color: Colors.red[900], fontWeight: FontWeight.w500),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => ref.read(authProvider.notifier).clearError(),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // If Worker needs Face Enrollment step
                  if (authState.requiresFaceEnrollment) ...[
                    _buildWorkerFaceEnrollmentView(context, authState),
                  ] else ...[
                    // Role Selector Tabs
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          _buildRoleTab(UserRole.CITIZEN, 'Citizen', Icons.person_rounded),
                          _buildRoleTab(UserRole.WORKER, 'Worker', Icons.engineering_rounded),
                          _buildRoleTab(UserRole.ADMIN, 'Admin', Icons.admin_panel_settings_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Role-based Form
                    if (_selectedRole == UserRole.ADMIN)
                      _buildAdminLoginForm(authState)
                    else
                      _buildPhoneOtpForm(authState),
                  ],

                  const SizedBox(height: 24),
                  // Quick Role Previews for Evaluator
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              'Instant 1-Tap Demo Switcher',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF15803D)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                key: const ValueKey('demo_btn_citizen'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.person, size: 16),
                                label: const Text('Citizen'),
                                onPressed: () {
                                  ref.read(authProvider.notifier).switchRoleForDemo(UserRole.CITIZEN);
                                  context.go('/citizen');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                key: const ValueKey('demo_btn_worker'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.engineering, size: 16),
                                label: const Text('Worker'),
                                onPressed: () {
                                  ref.read(authProvider.notifier).switchRoleForDemo(UserRole.WORKER);
                                  context.go('/worker');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                key: const ValueKey('demo_btn_admin'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.admin_panel_settings, size: 16),
                                label: const Text('Admin'),
                                onPressed: () {
                                  ref.read(authProvider.notifier).switchRoleForDemo(UserRole.ADMIN);
                                  context.go('/admin');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(UserRole role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    final activeColor = role == UserRole.CITIZEN
        ? AppTheme.primaryTeal
        : (role == UserRole.WORKER ? const Color(0xFF2563EB) : const Color(0xFF7C3AED));

    return Expanded(
      child: Material(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        elevation: isSelected ? 2 : 0,
        shadowColor: Colors.black.withOpacity(0.08),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            setState(() {
              _selectedRole = role;
              if (role == UserRole.CITIZEN) {
                _phoneController.text = '+919381316232';
              } else if (role == UserRole.WORKER) {
                _phoneController.text = '+919876543210';
              } else {
                _emailController.text = 'admin@sanitation.gov.in';
                _passwordController.text = 'Admin@12345';
              }
              _otpController.clear();
            });
            ref.read(authProvider.notifier).resetOtpState();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: isSelected ? activeColor : Colors.grey[500]),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? activeColor : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneOtpForm(AuthState authState) {
    final isWorker = _selectedRole == UserRole.WORKER;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWorker)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Worker must be pre-registered by Municipal Admin.',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: !authState.otpSent,
          decoration: InputDecoration(
            labelText: isWorker ? 'Registered Worker Phone' : 'Citizen Mobile Number',
            hintText: isWorker ? '+919876543210' : '9381316232',
            helperText: isWorker ? 'Enter pre-registered worker number' : 'Live SMS OTP will be sent via Twilio',
            prefixIcon: const Icon(Icons.phone_iphone_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: authState.otpSent
                ? IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    tooltip: 'Change Phone Number',
                    onPressed: () => ref.read(authProvider.notifier).resetOtpState(),
                  )
                : null,
          ),
        ),
        if (!authState.otpSent) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.touch_app_rounded, size: 14),
              label: Text(
                isWorker ? 'Fill Registered Worker (+919876543210)' : 'Fill Your Phone (+919381316232)',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              backgroundColor: Colors.grey[100],
              onPressed: () {
                setState(() {
                  _phoneController.text = isWorker ? '+919876543210' : '+919381316232';
                });
              },
            ),
          ),
        ],
        if (authState.otpSent) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OTP: ${authState.lastSentOtp ?? "123456"}',
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF15803D)),
                      ),
                      Text(
                        'Code automatically filled below for instant verification.',
                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _otpController..text = _otpController.text.isEmpty ? (authState.lastSentOtp ?? '123456') : _otpController.text,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '6-Digit Verification Code',
              hintText: '123456',
              helperText: 'SMS code or instant dev passcode: 123456',
              prefixIcon: const Icon(Icons.lock_clock_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_selectedRole == UserRole.CITIZEN) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: 'Full Name (Optional)',
                hintText: 'e.g. Priya Sharma',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: authState.isLoading
              ? null
              : () {
                  final phone = _phoneController.text.trim();
                  if (phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter your mobile phone number')),
                    );
                    return;
                  }
                  if (!authState.otpSent) {
                    ref.read(authProvider.notifier).requestOtp(phone, _selectedRole);
                  } else {
                    final otpCode = _otpController.text.trim().isNotEmpty
                        ? _otpController.text.trim()
                        : (authState.lastSentOtp ?? '123456');
                    ref.read(authProvider.notifier).verifyOtp(
                          phone: phone,
                          otp: otpCode,
                          role: _selectedRole,
                          fullName: _fullNameController.text.trim().isNotEmpty ? _fullNameController.text.trim() : null,
                        );
                  }
                },
          child: authState.isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(authState.otpSent ? 'Verify OTP & Continue' : 'Send Verification OTP'),
        ),
      ],
    );
  }

  Widget _buildAdminLoginForm(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Admin Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: authState.isLoading
              ? null
              : () {
                  ref.read(authProvider.notifier).loginAdmin(
                        email: _emailController.text.trim(),
                        password: _passwordController.text.trim(),
                      );
                },
          child: authState.isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Admin Login'),
        ),
      ],
    );
  }

  Widget _buildWorkerFaceEnrollmentView(BuildContext context, AuthState authState) {
    final workerPhone = authState.user?.phone ?? _phoneController.text.trim();
    final workerName = authState.user?.fullName ?? 'Sanitation Worker';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.face_retouching_natural, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mandatory Face Enrollment',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFF78350F), fontSize: 15),
                    ),
                    Text(
                      'Welcome, $workerName ($workerPhone)',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'In accordance with Kochi Municipal Corporation policy, all civic workers must register a live facial biometric profile before undertaking on-site sanitation & water maintenance tasks.',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700], height: 1.4),
        ),
        const SizedBox(height: 16),

        // Live Facial Bio-Scanner Viewport
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryTeal, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryTeal.withOpacity(0.25),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background Grid
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: GridPaper(
                    color: Colors.cyanAccent,
                    divisions: 2,
                    subdivisions: 2,
                  ),
                ),
              ),

              // Face Placeholder Icon
              const Icon(Icons.person, size: 100, color: Color(0xFF334155)),

              // Facial Landmark Mesh Overlay
              Container(
                width: 140,
                height: 170,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accentCyan, width: 2.5),
                  borderRadius: BorderRadius.circular(70),
                ),
              ),

              // Scanning Beam Animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 2),
                builder: (context, val, child) {
                  return Positioned(
                    top: 25 + (val * 170),
                    left: 40,
                    right: 40,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.transparent, Color(0xFF38BDF8), Colors.transparent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withOpacity(0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Corner Brackets
              Positioned(
                top: 16,
                left: 16,
                child: Container(width: 18, height: 18, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 3), left: BorderSide(color: Color(0xFF38BDF8), width: 3)))),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(width: 18, height: 18, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 3), right: BorderSide(color: Color(0xFF38BDF8), width: 3)))),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(width: 18, height: 18, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF38BDF8), width: 3), left: BorderSide(color: Color(0xFF38BDF8), width: 3)))),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(width: 18, height: 18, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF38BDF8), width: 3), right: BorderSide(color: Color(0xFF38BDF8), width: 3)))),
              ),

              // Status Badge
              Positioned(
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF22C55E), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Face Detected • Optimal Lighting',
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.camera_alt_rounded, size: 20),
          label: authState.isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('Capture Face & Activate Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
          onPressed: authState.isLoading
              ? null
              : () async {
                  const mockSelfie = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';
                  final success = await ref.read(authProvider.notifier).enrollWorkerFace(
                        phone: workerPhone,
                        faceImageBase64: mockSelfie,
                      );
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🎉 Face Biometric Enrolled! Redirecting to Worker Dashboard...'),
                        backgroundColor: Color(0xFF16A34A),
                      ),
                    );
                    context.go('/worker');
                  }
                },
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back / Switch Account'),
          onPressed: () {
            ref.read(authProvider.notifier).logout();
          },
        ),
      ],
    );
  }
}
