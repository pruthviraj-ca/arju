import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_export.dart';
import '../../models/project_model.dart';
import '../../models/unit_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/project_card_widget.dart';

/// Inventory list page — landing page for the Inventory module.
///
/// Displays a searchable list of project cards with live availability
/// stats. Admin users see a "+ Add Project" button; sales agents see
/// a read-only view.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  StreamSubscription? _projectsSub;
  StreamSubscription? _profileSub;
  List<ProjectModel> _projects = [];
  Map<String, List<UnitModel>> _projectUnits = {};
  final Map<String, StreamSubscription?> _unitSubs = {};
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });

    _profileSub = FirestoreService.instance.streamUserProfile().listen((profile) {
      if (mounted) {
        setState(() => _isAdmin = true);
      }
    });

    _projectsSub = FirestoreService.instance.streamProjects().listen((projects) {
      if (mounted) {
        setState(() {
          _projects = projects;
          _isLoading = false;
        });
        // Subscribe to units for each project
        for (final project in projects) {
          if (!_unitSubs.containsKey(project.id)) {
            _unitSubs[project.id] = FirestoreService.instance
                .streamUnits(project.id)
                .listen((units) {
              if (mounted) {
                setState(() => _projectUnits[project.id] = units);
              }
            });
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _projectsSub?.cancel();
    _profileSub?.cancel();
    for (final sub in _unitSubs.values) {
      sub?.cancel();
    }
    super.dispose();
  }

  List<ProjectModel> get _filteredProjects {
    if (_searchQuery.isEmpty) return _projects;
    return _projects.where((p) {
      return p.name.toLowerCase().contains(_searchQuery) ||
          p.location.toLowerCase().contains(_searchQuery) ||
          p.city.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProjects;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.dashboardScreen, (route) => false);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.backgroundLight,
        drawer: const AppDrawer(currentRoute: AppRoutes.inventoryScreen),
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceLight,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: AppTheme.primary),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          title: Text(
            'Inventory',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkText,
            ),
          ),
          actions: [
            // Only show in AppBar on wide (tablet) screens
            if (_isAdmin && isWideScreen)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.addProjectScreen),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Add Project',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.borderColor),
          ),
        ),
        // FAB for mobile-width screens
        floatingActionButton: (_isAdmin && !isWideScreen)
            ? FloatingActionButton.extended(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.addProjectScreen),
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  'Add Project',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              )
            : null,
        body: SafeArea(
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
                  decoration: InputDecoration(
                    hintText: 'Search by project name or location...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.mutedText, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              // Project list
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      )
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final project = filtered[index];
                              final units = _projectUnits[project.id] ?? [];
                              return ProjectCardWidget(
                                project: project,
                                units: units,
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.projectDetailScreen,
                                    arguments: {'projectId': project.id},
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'apartment',
              color: AppTheme.mutedText.withAlpha(100),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No projects match your search'
                  : 'No inventory added yet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.mutedText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Tap + Add Project to add your first project.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
