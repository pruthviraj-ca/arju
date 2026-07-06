import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/twilio_voice_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/custom_icon_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _regionController = TextEditingController();
  final _bioController = TextEditingController();

  // Twilio Configuration Controllers
  bool _twilioEnabled = false;
  final _accountSidController = TextEditingController();
  final _apiKeySidController = TextEditingController();
  final _apiSecretController = TextEditingController();
  final _twimlAppSidController = TextEditingController();
  final _callerIdController = TextEditingController();
  final _functionUrlController = TextEditingController();
  bool _obscureApiSecret = true;

  StreamSubscription? _profileSub;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill email and display name from Firebase Auth
    final user = AuthService.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
    }

    // Stream profile details from Firestore
    _profileSub = FirestoreService.instance.streamUserProfile().listen((profile) {
      if (mounted) {
        if (profile != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _nameController.text = profile['name'] ?? _nameController.text;
            _roleController.text = profile['role'] ?? '';
            _phoneController.text = profile['phone'] ?? '';
            _regionController.text = profile['region'] ?? '';
            _bioController.text = profile['bio'] ?? '';

            // Load Twilio Config
            final twilio = profile['twilioConfig'] as Map<String, dynamic>? ?? {};
            _twilioEnabled = twilio['enabled'] as bool? ?? false;
            _accountSidController.text = twilio['accountSid'] ?? '';
            _apiKeySidController.text = twilio['apiKeySid'] ?? '';
            _apiSecretController.text = twilio['apiSecret'] ?? '';
            _twimlAppSidController.text = twilio['twimlAppSid'] ?? '';
            _callerIdController.text = twilio['callerId'] ?? '';
            _functionUrlController.text = twilio['functionUrl'] ?? '';

            setState(() {
              _isLoading = false;
            });
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _nameController.dispose();
    _roleController.dispose();
    _phoneController.dispose();
    _regionController.dispose();
    _bioController.dispose();
    _accountSidController.dispose();
    _apiKeySidController.dispose();
    _apiSecretController.dispose();
    _twimlAppSidController.dispose();
    _callerIdController.dispose();
    _functionUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final role = _roleController.text.trim();
      final phone = _phoneController.text.trim();
      final region = _regionController.text.trim();
      final bio = _bioController.text.trim();

      // 1. Update Firebase Auth displayName
      await AuthService.instance.currentUser?.updateDisplayName(name);

      // 2. Save custom profile fields and Twilio settings in Firestore
      await FirestoreService.instance.updateUserProfile({
        'name': name,
        'role': role,
        'phone': phone,
        'region': region,
        'bio': bio,
        'twilioConfig': {
          'enabled': _twilioEnabled,
          'accountSid': _accountSidController.text.trim(),
          'apiKeySid': _apiKeySidController.text.trim(),
          'apiSecret': _apiSecretController.text.trim(),
          'twimlAppSid': _twimlAppSidController.text.trim(),
          'callerId': _callerIdController.text.trim(),
          'functionUrl': _functionUrlController.text.trim(),
        },
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Reload config in Twilio service
      await TwilioVoiceService.instance.loadConfig();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated successfully!',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: $e',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final email = user?.email ?? '';
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboardScreen, (route) => false);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.backgroundLight,
        drawer: const AppDrawer(currentRoute: '/profile-screen'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppTheme.borderColor,
        leading: Builder(
          builder: (context) => IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: CustomIconWidget(
              iconName: 'menu',
              color: AppTheme.primary,
              size: 24,
            ),
          ),
        ),
        title: Text(
          'My Profile',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 16,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isTablet ? 560 : double.infinity,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Profile Header / Avatar Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: AppTheme.primaryContainer,
                                  child: Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                        : 'RM',
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _nameController.text.isNotEmpty
                                      ? _nameController.text
                                      : 'Relationship Manager',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _roleController.text.isNotEmpty
                                      ? _roleController.text
                                      : 'Relationship Manager',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  email,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Form inputs Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Full Name
                                Text(
                                  'Full Name',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameController,
                                  textCapitalization: TextCapitalization.words,
                                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
                                  decoration: const InputDecoration(
                                    hintText: 'Rahul Sharma',
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                                ),
                                const SizedBox(height: 16),

                                // Role
                                Text(
                                  'Role / Designation',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _roleController,
                                  textCapitalization: TextCapitalization.words,
                                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
                                  decoration: const InputDecoration(
                                    hintText: 'Senior Relationship Manager',
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Role is required' : null,
                                ),
                                const SizedBox(height: 16),

                                // Phone Number
                                Text(
                                  'Phone Number',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textCapitalization: TextCapitalization.none,
                                  autocorrect: false,
                                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
                                  decoration: const InputDecoration(
                                    hintText: '+91 98765 43210',
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Region / Assigned Zone
                                Text(
                                  'Assigned Region / Zone',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _regionController,
                                  textCapitalization: TextCapitalization.words,
                                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
                                  decoration: const InputDecoration(
                                    hintText: 'Bengaluru East',
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Short Bio / Notes
                                Text(
                                  'Short Bio',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.darkText,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _bioController,
                                  maxLines: 3,
                                  textCapitalization: TextCapitalization.sentences,
                                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
                                  decoration: const InputDecoration(
                                    hintText: 'Briefly describe your experience, specialization, etc...',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Twilio VoIP Settings Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CustomIconWidget(
                                      iconName: 'phone_in_talk',
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Twilio VoIP Calling',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.darkText,
                                      ),
                                    ),
                                    const Spacer(),
                                    Switch(
                                      value: _twilioEnabled,
                                      activeColor: AppTheme.primary,
                                      onChanged: (val) {
                                        setState(() {
                                          _twilioEnabled = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enable real browser-based calling using WebRTC instead of opening your phone\'s native dialer.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.mutedText,
                                  ),
                                ),
                                if (_twilioEnabled) ...[
                                  const SizedBox(height: 20),
                                  const Divider(color: AppTheme.borderColor),
                                  const SizedBox(height: 16),

                                  // Account SID
                                  _buildTwilioField(
                                    label: 'Twilio Account SID',
                                    controller: _accountSidController,
                                    hintText: 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                                  ),
                                  const SizedBox(height: 16),

                                  // API Key SID
                                  _buildTwilioField(
                                    label: 'Twilio API Key SID',
                                    controller: _apiKeySidController,
                                    hintText: 'SKxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                                  ),
                                  const SizedBox(height: 16),

                                  // API Secret
                                  _buildTwilioField(
                                    label: 'Twilio API Secret',
                                    controller: _apiSecretController,
                                    hintText: 'Secret Key (only visible to you)',
                                    obscureText: _obscureApiSecret,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureApiSecret
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        size: 18,
                                        color: AppTheme.mutedText,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureApiSecret = !_obscureApiSecret;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // TwiML App SID
                                  _buildTwilioField(
                                    label: 'TwiML App SID',
                                    controller: _twimlAppSidController,
                                    hintText: 'APxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
                                  ),
                                  const SizedBox(height: 16),

                                  // Caller ID
                                  _buildTwilioField(
                                    label: 'Twilio Caller ID (E.164)',
                                    controller: _callerIdController,
                                    hintText: 'e.g. +12345678901',
                                  ),
                                  const SizedBox(height: 16),

                                  // Firebase Function URL
                                  _buildTwilioField(
                                    label: 'Firebase Cloud Functions Base URL',
                                    controller: _functionUrlController,
                                    hintText: 'e.g. https://us-central1-projectId.cloudfunctions.net',
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Save Button
                          ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Save Profile Details',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

  Widget _buildTwilioField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon,
          ),
          validator: (v) {
            if (_twilioEnabled && (v == null || v.trim().isEmpty)) {
              return '$label is required';
            }
            return null;
          },
        ),
      ],
    );
  }
}
