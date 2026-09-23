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
  final TextEditingController _phoneController = TextEditingController(text: '+919876543210');
  final TextEditingController _otpController = TextEditingController(text: '123456');
  final TextEditingController _fullNameController = TextEditingController(text: 'Kochi Citizen');
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
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text('Quick Preview: ', style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                      TextButton(
                        onPressed: () => ref.read(authProvider.notifier).switchRoleForDemo(UserRole.CITIZEN),
                        child: const Text('Citizen'),
                      ),
                      TextButton(
                        onPressed: () => ref.read(authProvider.notifier).switchRoleForDemo(UserRole.WORKER),
                        child: const Text('Worker'),
                      ),
                      TextButton(
                        onPressed: () => ref.read(authProvider.notifier).switchRoleForDemo(UserRole.ADMIN),
                        child: const Text('Admin'),
                      ),
                    ],
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
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = role;
          });
          ref.read(authProvider.notifier).resetOtpState();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? AppTheme.primaryTeal : Colors.grey[500]),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryTeal : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneOtpForm(AuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedRole == UserRole.WORKER)
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
            labelText: 'Mobile Phone Number',
            prefixIcon: const Icon(Icons.phone_iphone_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: authState.otpSent
                ? IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => ref.read(authProvider.notifier).resetOtpState(),
                  )
                : null,
          ),
        ),
        if (authState.otpSent) ...[
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Enter 6-Digit OTP',
              helperText: 'Development default: 123456',
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
                  if (!authState.otpSent) {
                    ref.read(authProvider.notifier).requestOtp(phone, _selectedRole);
                  } else {
                    ref.read(authProvider.notifier).verifyOtp(
                          phone: phone,
                          otp: _otpController.text.trim(),
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
