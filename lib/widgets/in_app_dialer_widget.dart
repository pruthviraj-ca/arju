import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/twilio_voice_service.dart';
import '../utils/phone_utils.dart';

/// Data returned when the dialer closes after a call ends.
class DialerResult {
  final String noteText;
  final int durationSeconds;
  final String durationFormatted;
  final String leadId;

  DialerResult({
    required this.noteText,
    required this.durationSeconds,
    required this.durationFormatted,
    required this.leadId,
  });
}

/// Simulated call state.
enum _CallState { connecting, connected, ended }

/// Full-screen in-app dialer overlay.
///
/// Usage:
/// ```dart
/// final result = await showInAppDialer(context, lead: leadMap);
/// ```
Future<DialerResult?> showInAppDialer(
  BuildContext context, {
  required Map<String, dynamic> lead,
}) {
  return Navigator.of(context).push<DialerResult>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => _InAppDialerOverlay(lead: lead),
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

class _InAppDialerOverlay extends StatefulWidget {
  final Map<String, dynamic> lead;

  const _InAppDialerOverlay({required this.lead});

  @override
  State<_InAppDialerOverlay> createState() => _InAppDialerOverlayState();
}

class _InAppDialerOverlayState extends State<_InAppDialerOverlay>
    with TickerProviderStateMixin {
  _CallState _callState = _CallState.connecting;
  bool _isMuted = false;
  bool _showKeypad = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  Timer? _connectTimer;
  String _errorMessage = '';

  final TextEditingController _noteController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _avatarGlowController;

  @override
  void initState() {
    super.initState();

    // Pulsing dots animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Avatar glow animation
    _avatarGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    final voip = TwilioVoiceService.instance;
    if (voip.isVoipEnabled) {
      voip.onDeviceRegistered = () {
        debugPrint('Dialer: VoIP Device Registered, dialing...');
        final phone = widget.lead['phone'] as String? ?? '';
        voip.connectCall(phone);
      };

      voip.onDeviceError = (err) {
        if (mounted) {
          setState(() {
            _errorMessage = err;
          });
        }
      };

      voip.onCallConnected = () {
        if (mounted) {
          setState(() {
            _callState = _CallState.connected;
            _errorMessage = '';
          });
          _startTimer();
        }
      };

      voip.onCallDisconnected = () {
        if (mounted) {
          _endCall();
        }
      };

      voip.onCallError = (err) {
        if (mounted) {
          setState(() {
            _errorMessage = err;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Call Error: $err'),
              backgroundColor: Colors.red,
            ),
          );
        }
      };

      // Initialize the device (fetches token and registers)
      voip.initializeDevice();
    } else {
      // SIM-based calling: launch the native phone dialer
      _launchNativeCall();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  /// Launches the device's native phone dialer via the tel: URI scheme.
  /// After launching, the overlay transitions to 'connected' and starts
  /// tracking call duration so the agent can log it.
  Future<void> _launchNativeCall() async {
    final phone = widget.lead['phone'] as String? ?? '';
    final formattedPhone = formatPhoneForCall(phone);

    if (formattedPhone.replaceAll('+91', '').isEmpty) {
      if (mounted) {
        setState(() => _errorMessage = 'No phone number available');
      }
      return;
    }

    final uri = Uri(scheme: 'tel', path: formattedPhone);

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched && mounted) {
        setState(() {
          _callState = _CallState.connected;
          _errorMessage = '';
        });
        _startTimer();
      } else if (mounted) {
        setState(() {
          _errorMessage = 'Could not open phone dialer';
        });
      }
    } catch (e) {
      debugPrint('Error launching native call: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initiate call: $e';
        });
      }
    }
  }

  String get _formattedDuration {
    final mins = _elapsedSeconds ~/ 60;
    final secs = _elapsedSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String get _durationForStorage {
    final mins = _elapsedSeconds ~/ 60;
    final secs = _elapsedSeconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs.toString().padLeft(2, '0')}s';
    }
    return '${secs}s';
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    if (TwilioVoiceService.instance.isVoipEnabled) {
      TwilioVoiceService.instance.muteCall(_isMuted);
    }
  }

  void _toggleKeypad() {
    setState(() => _showKeypad = !_showKeypad);
  }

  void _endCall() {
    _timer?.cancel();
    _connectTimer?.cancel();

    if (TwilioVoiceService.instance.isVoipEnabled) {
      TwilioVoiceService.instance.disconnectCall();
    }

    final result = DialerResult(
      noteText: _noteController.text.trim(),
      durationSeconds: _elapsedSeconds,
      durationFormatted: _durationForStorage,
      leadId: widget.lead['id'] as String,
    );

    Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connectTimer?.cancel();
    _pulseController.dispose();
    _avatarGlowController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.lead['clientName'] as String? ?? 'Unknown';
    final phone = widget.lead['phone'] as String? ?? '';
    final property = widget.lead['property'] as String? ?? '';
    final initials = clientName.isNotEmpty ? clientName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blurred / dark backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: const Color(0xFF0A1628).withOpacity(0.92),
              ),
            ),
          ),

          // Main dialer content
          SafeArea(
            child: Column(
              children: [
                // ── Top bar ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Branding
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.phone_in_talk,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TruAssets Dialer',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Secure icon
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              color: AppTheme.success.withOpacity(0.9),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Encrypted',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.success.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 1),

                // ── Avatar with glow ──────────────────────
                AnimatedBuilder(
                  animation: _avatarGlowController,
                  builder: (context, child) {
                    final glowOpacity = _callState == _CallState.connecting
                        ? 0.15 + (_avatarGlowController.value * 0.2)
                        : 0.1;
                    final glowSize = _callState == _CallState.connecting
                        ? 100.0 + (_avatarGlowController.value * 20)
                        : 100.0;
                    return Container(
                      width: glowSize,
                      height: glowSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_callState == _CallState.connected
                                    ? AppTheme.success
                                    : AppTheme.accent)
                                .withOpacity(glowOpacity),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF2d5f8a),
                          const Color(0xFF1a3c5e),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.inter(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Client name ───────────────────────────
                Text(
                  clientName,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                // ── Status / Timer ────────────────────────
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_callState == _CallState.connecting)
                  _PulsingDotsStatus(controller: _pulseController)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formattedDuration,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // ── Phone number ──────────────────────────
                Text(
                  phone,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.5),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),

                const SizedBox(height: 4),

                // ── Property ──────────────────────────────
                if (property.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.apartment,
                        color: Colors.white.withOpacity(0.4),
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        property,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),

                const Spacer(flex: 1),

                // ── Note input ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _noteController,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Add note during call...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(
                            left: 14,
                            right: 10,
                            top: 14,
                          ),
                          child: Icon(
                            Icons.edit_note,
                            color: Colors.white.withOpacity(0.3),
                            size: 20,
                          ),
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        filled: false,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Keypad overlay ────────────────────────
                if (_showKeypad)
                  _DialerKeypad(
                    onClose: _toggleKeypad,
                  ),

                const Spacer(flex: 1),

                // ── Bottom controls ───────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // MUTE
                      _ControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        label: _isMuted ? 'Unmute' : 'Mute',
                        isActive: _isMuted,
                        activeColor: AppTheme.accent,
                        onTap: _toggleMute,
                      ),

                      // END CALL
                      GestureDetector(
                        onTap: _endCall,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.error,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.error.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),

                      // KEYPAD
                      _ControlButton(
                        icon: Icons.dialpad,
                        label: 'Keypad',
                        isActive: _showKeypad,
                        activeColor: AppTheme.primary,
                        onTap: _toggleKeypad,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing "Calling..." status ─────────────────────────────────────────────
class _PulsingDotsStatus extends StatelessWidget {
  final AnimationController controller;

  const _PulsingDotsStatus({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Calling',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.accent,
              ),
            ),
            SizedBox(
              width: 24,
              child: Text(
                value < 0.33
                    ? '.'
                    : value < 0.66
                        ? '..'
                        : '...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Control button (Mute / Keypad) ──────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? activeColor.withOpacity(0.2)
                  : Colors.white.withOpacity(0.08),
              border: Border.all(
                color: isActive
                    ? activeColor.withOpacity(0.4)
                    : Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : Colors.white.withOpacity(0.8),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isActive ? activeColor : Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Numeric keypad ──────────────────────────────────────────────────────────
class _DialerKeypad extends StatelessWidget {
  final VoidCallback onClose;

  const _DialerKeypad({required this.onClose});

  static const _keys = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['*', '0', '#'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 48),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Keypad',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.keyboard_hide,
                  color: Colors.white.withOpacity(0.4),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._keys.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map(
                      (key) => _KeypadButton(label: key),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;

  const _KeypadButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (TwilioVoiceService.instance.isVoipEnabled) {
          TwilioVoiceService.instance.sendDigits(label);
        }
      },
      child: Container(
        width: 56,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      ),
    );
  }
}
