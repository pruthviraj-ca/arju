/// twilio_voice_web_impl.dart
///
/// Web-specific implementation that bridges Dart with the Twilio Voice
/// JavaScript SDK using dart:js interop. This file is ONLY compiled
/// when `dart.library.html` is available (i.e., web platform).

import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

/// Registers Dart handler functions as globally accessible JavaScript
/// callbacks so the Twilio JS SDK can invoke them on call events.
void setupJsCallbacks({
  required void Function() onRegistered,
  required void Function(String error) onError,
  required void Function() onCallConnected,
  required void Function() onCallDisconnected,
  required void Function(String error) onCallError,
}) {
  js.context['dartOnTwilioDeviceRegistered'] = js.allowInterop(() {
    onRegistered();
  });

  js.context['dartOnTwilioDeviceError'] = js.allowInterop((error) {
    onError(error.toString());
  });

  js.context['dartOnCallConnected'] = js.allowInterop(() {
    onCallConnected();
  });

  js.context['dartOnCallDisconnected'] = js.allowInterop(() {
    onCallDisconnected();
  });

  js.context['dartOnCallError'] = js.allowInterop((error) {
    onCallError(error.toString());
  });
}

/// Fetches a Twilio voice access token from the configured Cloud Function.
///
/// [functionUrl] - The base Cloud Function URL.
/// [idToken] - Firebase ID token for authenticating the request.
/// Returns the token string, or `null` on failure.
Future<String?> fetchVoiceToken(String functionUrl, String idToken) async {
  final cleanUrl =
      functionUrl.endsWith('/') ? functionUrl : '$functionUrl/';
  final tokenEndpoint = '${cleanUrl}twilioAccessToken';

  debugPrint('Fetching Twilio token from: $tokenEndpoint');

  final request = await html.HttpRequest.request(
    tokenEndpoint,
    method: 'POST',
    requestHeaders: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    },
  );

  if (request.status == 200) {
    final responseData = jsonDecode(request.responseText ?? '{}');
    return responseData['token'] as String?;
  } else {
    final responseData = jsonDecode(request.responseText ?? '{}');
    final error =
        responseData['error'] as String? ?? 'HTTP ${request.status}';
    debugPrint('Token retrieval failed: $error');
    return null;
  }
}

/// Initializes the Twilio Device with the given access token.
void initTwilioDevice(String token) {
  js.context['twilioDialer'].callMethod('init', [token]);
}

/// Initiates an outbound call to [phoneNumber].
void connectCall(String phoneNumber) {
  js.context['twilioDialer'].callMethod('connect', [phoneNumber]);
}

/// Hangs up / disconnects the currently active call.
void disconnectCall() {
  js.context['twilioDialer'].callMethod('disconnect');
}

/// Mutes or unmutes the microphone on the active call.
void muteCall(bool isMuted) {
  js.context['twilioDialer'].callMethod('mute', [isMuted]);
}

/// Sends DTMF tone [digits] on the active call.
void sendDigits(String digits) {
  js.context['twilioDialer'].callMethod('sendDigits', [digits]);
}
