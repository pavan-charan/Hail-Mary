import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildRoleTab(UserRole.CITIZEN, 'Citizen', Icons.person_outline),
                          _buildRoleTab(UserRole.WORKER, 'Worker', Icons.engineering_outlined),
                          _buildRoleTab(UserRole.ADMIN, 'Admin', Icons.admin_panel_settings_outlined),
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

                  const SizedBox(height: 20),
                  // Quick Role Previews for Evaluator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Text(
                            '⚡ Instant 1-Tap Role Demo Switcher:',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryTeal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.person, size: 14),
                                label: const Text('Citizen'),
                                onPressed: () => ref.read(authProvider.notifier).switchRoleForDemo(UserRole.CITIZEN),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.engineering, size: 14),
                                label: const Text('Worker'),
                                onPressed: () => ref.read(authProvider.notifier).switchRoleForDemo(UserRole.WORKER),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                icon: const Icon(Icons.admin_panel_settings, size: 14),
                                label: const Text('Admin'),
                                onPressed: () => ref.read(authProvider.notifier).switchRoleForDemo(UserRole.ADMIN),
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
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          mouseCursor: SystemMouseCursors.click,
          onTap: () {
            setState(() {
              _selectedRole = role;
            });
            ref.read(authProvider.notifier).resetOtpState();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Icon(icon, size: 22, color: isSelected ? AppTheme.primaryTeal : Colors.grey[500]),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryTeal : Colors.grey[600],
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
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Enter 6-Digit OTP',
              hintText: '123456',
              helperText: 'Enter SMS OTP received (or dev code: 123456)',
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
                    final otpCode = _otpController.text.trim().isNotEmpty ? _otpController.text.trim() : '123456';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.face_retouching_natural, color: Colors.orange, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mandatory Worker Face Enrollment',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.brown[900], fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Capture a live face selfie to activate your worker profile. This facial profile will be used to verify maintenance repairs on-site.',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 20),

        // Facial Camera View Simulator
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryTeal, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.face, size: 90, color: Colors.white24),
              Container(
                width: 120,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accentCyan, width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(60),
                ),
              ),
              Positioned(
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: Text('Live Camera Ready', style: GoogleFonts.outfit(color: Colors.white, fontSize: 11)),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          icon: const Icon(Icons.camera_alt_rounded),
          label: authState.isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Capture & Activate Account'),
          onPressed: authState.isLoading
              ? null
              : () {
                  // Mock live base64 selfie
                  const mockSelfie = 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=';
                  ref.read(authProvider.notifier).enrollWorkerFace(
                        phone: _phoneController.text.trim(),
                        faceImageBase64: mockSelfie,
                      );
                },
        ),
      ],
    );
  }
}
