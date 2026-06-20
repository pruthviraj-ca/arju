/// twilio_voice_service.dart
///
/// VoIP calling service for the TruAssets CRM. On web, it uses the
/// Twilio Voice JavaScript SDK via JS interop. On mobile (Android/iOS),
/// all VoIP methods are graceful no-ops because mobile uses SIM-based
/// calling via url_launcher instead.
///
/// Usage:
///   1. Call [loadConfig] after login to read Twilio credentials from Firestore.
///   2. Call [initializeDevice] to fetch a voice token and register the device.
///   3. Use [connectCall], [disconnectCall], [muteCall], and [sendDigits]
///      during an active call.
///   4. Assign the callback properties (e.g. [onCallConnected]) to react to
///      call lifecycle events in the UI.

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

// Conditional imports for web-only functionality
import 'twilio_voice_web_stub.dart'
    if (dart.library.html) 'twilio_voice_web_impl.dart' as web_impl;

/// Singleton VoIP service that wraps the Twilio Voice JS SDK.
///
/// Call lifecycle events are surfaced via optional callback properties
/// that the UI layer can assign to react to state changes.
class TwilioVoiceService {
  TwilioVoiceService._();

  /// Global singleton instance.
  static final TwilioVoiceService instance = TwilioVoiceService._();

  // ─── Internal State ────────────────────────────────────────────────────────

  bool _isVoipEnabled = false;
  String? _functionUrl;
  bool _isDeviceRegistered = false;

  // ─── UI Lifecycle Callbacks ───────────────────────────────────────────────

  /// Called when the Twilio Device is successfully registered.
  VoidCallback? onDeviceRegistered;

  /// Called when the Twilio Device encounters a registration error.
  /// Receives the error message string.
  ValueSetter<String>? onDeviceError;

  /// Called when an outbound call connects.
  VoidCallback? onCallConnected;

  /// Called when the active call disconnects.
  VoidCallback? onCallDisconnected;

  /// Called when the call encounters an error.
  /// Receives the error message string.
  ValueSetter<String>? onCallError;

  // ─── State Accessors ──────────────────────────────────────────────────────

  /// Whether VoIP calling is enabled in the user's profile settings.
  bool get isVoipEnabled => _isVoipEnabled;

  /// Whether the Twilio Device has been successfully registered.
  bool get isDeviceRegistered => _isDeviceRegistered;

  // ─── Initialization ───────────────────────────────────────────────────────

  /// Loads Twilio configuration from the current user's Firestore profile.
  ///
  /// Reads the `twilioConfig` map from `/users/{uid}` and caches the
  /// `enabled` flag and `functionUrl`. On web, also wires up JS callbacks.
  Future<void> loadConfig() async {
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final config = data['twilioConfig'] as Map<String, dynamic>? ?? {};
        _isVoipEnabled = config['enabled'] as bool? ?? false;
        _functionUrl = config['functionUrl'] as String?;

        debugPrint(
            'Twilio VoIP config loaded: enabled=$_isVoipEnabled, functionUrl=$_functionUrl');

        if (_isVoipEnabled && kIsWeb) {
          web_impl.setupJsCallbacks(
            onRegistered: () {
              debugPrint('Twilio Device: Registered');
              _isDeviceRegistered = true;
              onDeviceRegistered?.call();
            },
            onError: (error) {
              debugPrint('Twilio Device Error: $error');
              _isDeviceRegistered = false;
              onDeviceError?.call(error);
            },
            onCallConnected: () {
              debugPrint('Twilio Call: Connected');
              onCallConnected?.call();
            },
            onCallDisconnected: () {
              debugPrint('Twilio Call: Disconnected');
              onCallDisconnected?.call();
            },
            onCallError: (error) {
              debugPrint('Twilio Call Error: $error');
              onCallError?.call(error);
            },
          );
        }
      }
    } catch (e) {
      debugPrint('Error loading Twilio configuration: $e');
    }
  }

  /// Fetches a short-lived voice access token from Firebase Cloud Functions
  /// and registers the Twilio Device, making it ready to place calls.
  ///
  /// No-op on non-web platforms. Calls [onDeviceError] if setup fails.
  Future<void> initializeDevice() async {
    if (!kIsWeb) {
      debugPrint('Twilio Web SDK is only supported on Web browsers.');
      return;
    }

    if (_functionUrl == null || _functionUrl!.trim().isEmpty) {
      onDeviceError?.call('Firebase Cloud Function URL is not configured.');
      return;
    }

    try {
      final idToken = await AuthService.instance.currentUser?.getIdToken();
      if (idToken == null) {
        onDeviceError?.call('User authentication token expired or missing.');
        return;
      }

      final token = await web_impl.fetchVoiceToken(_functionUrl!, idToken);
      if (token != null && token.isNotEmpty) {
        web_impl.initTwilioDevice(token);
      } else {
        onDeviceError?.call('Backend returned an empty token.');
      }
    } catch (e) {
      debugPrint('Error initializing Twilio Device: $e');
      onDeviceError?.call('Device initialization failed: $e');
    }
  }

  // ─── Call Control ─────────────────────────────────────────────────────────

  /// Initiates an outbound call to [phoneNumber].
  ///
  /// Strips non-numeric characters (except '+') before dialling.
  /// No-op on non-web platforms.
  void connectCall(String phoneNumber) {
    if (!kIsWeb) return;
    try {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      web_impl.connectCall(cleanPhone);
    } catch (e) {
      debugPrint('Error connecting Twilio call: $e');
      onCallError?.call(e.toString());
    }
  }

  /// Hangs up / disconnects the currently active call.
  ///
  /// No-op on non-web platforms.
  void disconnectCall() {
    if (!kIsWeb) return;
    try {
      web_impl.disconnectCall();
    } catch (e) {
      debugPrint('Error disconnecting Twilio call: $e');
    }
  }

  /// Mutes or unmutes the microphone on the active call.
  ///
  /// [isMuted] - `true` to mute, `false` to unmute.
  /// No-op on non-web platforms.
  void muteCall(bool isMuted) {
    if (!kIsWeb) return;
    try {
      web_impl.muteCall(isMuted);
    } catch (e) {
      debugPrint('Error muting Twilio call: $e');
    }
  }

  /// Sends DTMF tone [digits] on the active call (e.g., for IVR navigation).
  ///
  /// No-op on non-web platforms.
  void sendDigits(String digits) {
    if (!kIsWeb) return;
    try {
      web_impl.sendDigits(digits);
    } catch (e) {
      debugPrint('Error sending DTMF digits: $e');
    }
  }
}
