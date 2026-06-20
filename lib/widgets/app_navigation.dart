/// app_navigation.dart
///
/// Provides the global [AppDrawer] navigation sidebar used across all
/// authenticated screens. Streams the user's profile from Firestore to
/// display their name, role, and email in the drawer header.
/// Also provides the [_DrawerItem] private widget for individual nav entries.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../routes/app_routes.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import './custom_icon_widget.dart';

/// App-wide navigation drawer used as the main navigation mechanism.
///
/// Shows the user's profile header (name, role, email) from Firestore
/// and provides tappable routes to all primary app screens.
class AppDrawer extends StatelessWidget {
  /// The route string of the screen that is currently open. Used to
  /// highlight the active navigation item.
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          _buildProfileHeader(context),
          const SizedBox(height: 8),
          _buildNavItems(context),
          const Divider(height: 1, color: AppTheme.borderColor),
          _buildLogoutButton(context),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  /// Builds the drawer header with user avatar, name, role, and email.
  /// Streams live profile data from Firestore.
  Widget _buildProfileHeader(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FirestoreService.instance.streamUserProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?['name'] ??
            AuthService.instance.currentUser?.displayName ??
            'Relationship Manager';
        final role = profile?['role'] ?? 'Relationship Manager';
        final initials = _buildInitials(name);

        return Container(
          width: double.infinity,
          color: AppTheme.primary,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 24,
            left: 24,
            right: 24,
            bottom: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarCircle(initials: initials),
              const SizedBox(height: 12),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              _RoleBadgeRow(
                role: role,
                email: AuthService.instance.currentUser?.email ?? '',
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Navigation Items ──────────────────────────────────────────────────────

  /// Builds the list of navigation items in the drawer body.
  Widget _buildNavItems(BuildContext context) {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _DrawerItem(
            iconName: 'dashboard',
            label: 'Dashboard',
            isActive: currentRoute == AppRoutes.dashboardScreen,
            onTap: () => _navigate(context, AppRoutes.dashboardScreen),
          ),
          _DrawerItem(
            iconName: 'people',
            label: 'My Leads',
            isActive: currentRoute == AppRoutes.myLeadsScreen,
            onTap: () => _navigate(context, AppRoutes.myLeadsScreen),
          ),
          _DrawerItem(
            iconName: 'upload_file',
            label: 'Import Leads',
            isActive: currentRoute == AppRoutes.importLeadsScreen,
            onTap: () => _navigate(context, AppRoutes.importLeadsScreen),
          ),
          _DrawerItem(
            iconName: 'event',
            label: 'Site Visits',
            isActive: currentRoute == AppRoutes.siteVisitsScreen,
            onTap: () => _navigate(context, AppRoutes.siteVisitsScreen),
          ),
          _DrawerItem(
            iconName: 'person',
            label: 'My Profile',
            isActive: currentRoute == AppRoutes.profileScreen,
            onTap: () => _navigate(context, AppRoutes.profileScreen),
          ),
        ],
      ),
    );
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  /// Builds the logout button at the bottom of the drawer.
  Widget _buildLogoutButton(BuildContext context) {
    return InkWell(
      onTap: () => _handleLogout(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            CustomIconWidget(
              iconName: 'logout',
              color: AppTheme.error,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              'Logout',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  /// Closes the drawer and navigates to [route] using pushNamedAndRemoveUntil.
  /// Does nothing if [route] is already the active screen.
  void _navigate(BuildContext context, String route) {
    Navigator.pop(context);
    if (currentRoute != route) {
      Navigator.pushNamedAndRemoveUntil(context, route, (r) => false);
    }
  }

  /// Signs out the user and redirects to the login screen.
  Future<void> _handleLogout(BuildContext context) async {
    Navigator.pop(context);
    await AuthService.instance.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.loginScreen,
        (route) => false,
      );
    }
  }

  /// Extracts up to two uppercase initials from a full [name] string.
  String _buildInitials(String name) {
    if (name.isEmpty) return 'RM';
    return name
        .trim()
        .split(' ')
        .map((e) => e[0])
        .take(2)
        .join()
        .toUpperCase();
  }
}

// ─── Avatar Circle ─────────────────────────────────────────────────────────────

/// Circular avatar displaying the user's initials in the drawer header.
class _AvatarCircle extends StatelessWidget {
  final String initials;
  const _AvatarCircle({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(38),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withAlpha(77), width: 2),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Role Badge Row ────────────────────────────────────────────────────────────

/// A row showing the user's role badge and email address in the drawer header.
class _RoleBadgeRow extends StatelessWidget {
  final String role;
  final String email;

  const _RoleBadgeRow({required this.role, required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            role,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            email,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white.withAlpha(204),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Drawer Item ──────────────────────────────────────────────────────────────

/// A single navigation entry in the [AppDrawer] with an icon and label.
/// Shows an active indicator dot when [isActive] is true.
class _DrawerItem extends StatelessWidget {
  final String iconName;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.iconName,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppTheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CustomIconWidget(
                iconName: iconName,
                color: isActive ? AppTheme.primary : AppTheme.mutedText,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? AppTheme.primary
                      : const Color(0xFF374151),
                ),
              ),
              if (isActive) ...[
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
