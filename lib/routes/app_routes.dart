import 'package:flutter/material.dart';

import '../presentation/dashboard_screen/dashboard_screen.dart';
import '../presentation/login_screen/login_screen.dart';
import '../presentation/my_leads_screen/my_leads_screen.dart';
import '../presentation/import_leads_screen/import_leads_screen.dart';
import '../presentation/lead_detail_screen/lead_detail_screen.dart';
import '../presentation/site_visits_screen/site_visits_screen.dart';
import '../presentation/profile_screen/profile_screen.dart';
import '../presentation/reports_screen/reports_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String loginScreen = '/login-screen';
  static const String dashboardScreen = '/dashboard-screen';
  static const String reportsScreen = '/reports-screen';
  static const String myLeadsScreen = '/my-leads-screen';
  static const String importLeadsScreen = '/import-leads-screen';
  static const String leadDetailScreen = '/lead-detail-screen';
  static const String siteVisitsScreen = '/site-visits-screen';
  static const String profileScreen = '/profile-screen';

  static Map<String, WidgetBuilder> routes = {
    loginScreen: (context) => const LoginScreen(),
    dashboardScreen: (context) => const DashboardScreen(),
    reportsScreen: (context) => const ReportsScreen(),
    myLeadsScreen: (context) => const MyLeadsScreen(),
    importLeadsScreen: (context) => const ImportLeadsScreen(),
    leadDetailScreen: (context) => const LeadDetailScreen(),
    siteVisitsScreen: (context) => const SiteVisitsScreen(),
    profileScreen: (context) => const ProfileScreen(),
  };
}
