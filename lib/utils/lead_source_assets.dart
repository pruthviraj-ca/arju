import 'package:flutter/material.dart';

/// Only uncomment files that you have actually placed in assets/leadSources/
/// If a file does not exist yet, comment out or remove that line below
/// and that source will automatically use the fallback icon instead.
const Map<String, String> sourceLogoMap = {
  // 'MagicBricks': 'assets/leadSources/magicbricks.png',
  // '99acres': 'assets/leadSources/99acres.png',
  // 'NoBroker': 'assets/leadSources/nobroker.png',
  // 'Meta Ads': 'assets/leadSources/meta.png',
  // 'Google Ads': 'assets/leadSources/google.png',
};

// Generic fallback icons (Material Icon keys for CustomIconWidget) - always available, no files needed
const Map<String, String> sourceFallbackIcon = {
  'MagicBricks': 'home',
  '99acres': 'business',
  'NoBroker': 'key',
  'Meta Ads': 'campaign',
  'Google Ads': 'search',
  'Referral': 'people',
  'Walk-in': 'directions_walk',
};

class SourceIconData {
  final IconData icon;
  final Color color;

  const SourceIconData({
    required this.icon,
    required this.color,
  });
}

const Map<String, SourceIconData> sourceIconMap = {
  'MagicBricks': SourceIconData(icon: Icons.home_work_outlined, color: Colors.orange),
  '99acres': SourceIconData(icon: Icons.apartment_outlined, color: Colors.blue),
  'NoBroker': SourceIconData(icon: Icons.money_off_outlined, color: Colors.green),
  'Meta Ads': SourceIconData(icon: Icons.campaign_outlined, color: Colors.indigo),
  'Google Ads': SourceIconData(icon: Icons.ads_click_outlined, color: Colors.red),
  'Referral': SourceIconData(icon: Icons.people_outline, color: Colors.teal),
  'Walk-in': SourceIconData(icon: Icons.directions_walk, color: Colors.blueGrey),
};
