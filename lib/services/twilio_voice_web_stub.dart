/// twilio_voice_web_stub.dart
///
/// Stub implementation for non-web platforms. All methods are no-ops.
/// This file is used when `dart.library.html` is NOT available (Android/iOS).

/// No-op on non-web platforms.
void setupJsCallbacks({
  required void Function() onRegistered,
  required void Function(String error) onError,
  required void Function() onCallConnected,
  required void Function() onCallDisconnected,
  required void Function(String error) onCallError,
}) {}

/// No-op on non-web platforms.
Future<String?> fetchVoiceToken(String functionUrl, String idToken) async {
  return null;
}

/// No-op on non-web platforms.
void initTwilioDevice(String token) {}

/// No-op on non-web platforms.
void connectCall(String phoneNumber) {}

/// No-op on non-web platforms.
void disconnectCall() {}

/// No-op on non-web platforms.
void muteCall(bool isMuted) {}

/// No-op on non-web platforms.
void sendDigits(String digits) {}
