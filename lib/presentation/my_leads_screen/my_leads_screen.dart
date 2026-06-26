import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/in_app_dialer_widget.dart';
import '../../core/app_export.dart';
import '../../models/lead_model.dart';
import '../../services/firestore_service.dart';
import '../../services/twilio_voice_service.dart';
import '../../widgets/app_navigation.dart';
import './widgets/lead_card_widget.dart';
import './widgets/lead_filter_chips_widget.dart';
import './widgets/lead_search_bar_widget.dart';
import './my_leads_filter_session.dart';

class MyLeadsScreen extends StatefulWidget {
  const MyLeadsScreen({super.key});

  @override
  State<MyLeadsScreen> createState() => _MyLeadsScreenState();
}

class _MyLeadsScreenState extends State<MyLeadsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _selectedTagFilter = 'All';
  String _selectedTempFilter = 'All';
  String _sortBy = 'Created Date';
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;
  bool _isFilterExpanded = false;

  bool get _isFilterActive =>
      _selectedFilter != 'All' ||
      _selectedTagFilter != 'All' ||
      _selectedTempFilter != 'All';

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedFilter != 'All') count++;
    if (_selectedTagFilter != 'All') count++;
    if (_selectedTempFilter != 'All') count++;
    if (_selectedDateRange != null) count++;
    return count;
  }

  StreamSubscription? _leadsSub;
  List<LeadModel> _allLeads = [];

  List<Map<String, dynamic>> get _leads {
    return _allLeads.map((l) {
      return {
        'id': l.id,
        'clientName': l.clientName,
        'phone': l.phone,
        'property': l.property,
        'status': l.status,
        'lastTag': l.lastTag,
        'followUpDate': l.followUpDate,
        'lastNote': l.lastNote,
        'isActive': l.isActive,
        'callDuration': l.callDuration,
        'createdAt': l.createdAt,
        'callsCount': l.callsCount,
        'leadTemperature': l.leadTemperature,
        'leadSource': l.source,
      };
    }).toList();
  }

  final List<String> _statusFilters = [
    'All',
    'New',
    'Called',
    'Follow-Up',
    'SV Scheduled',
    'Visited',
    'Won',
    'Lost/Dead',
  ];

  final List<String> _tempFilters = [
    'All',
    'Hot',
    'Warm',
    'Cold',
  ];

  final List<String> _tagFilters = [
    'All',
    'Booked',
    'Callback',
    'Channel Partner',
    'Closed with Colleague',
    'Dropped Buying Plans',
    'Finalised Elsewhere',
    'Interested',
    'Location Mismatch',
    'Low Budget',
    'Not Answering',
    'Not Interested',
    'Not Responding',
    'Postponed Buying Plan',
    'Prospect',
    'Site Visit Ready',
    'Source Inventory',
    'Wrong Number',
  ];

  final List<String> _sortOptions = [
    'Created Date',
    'Follow-Up Date',
    'Client Name',
    'Status',
    'Calls Count',
  ];

  @override
  void initState() {
    super.initState();
    
    // Load VoIP config
    TwilioVoiceService.instance.loadConfig();

    // Restore filters from session persistence
    _searchController.text = MyLeadsFilterSession.searchQuery;
    _searchQuery = MyLeadsFilterSession.searchQuery;
    _selectedFilter = MyLeadsFilterSession.selectedFilter;
    _selectedTagFilter = MyLeadsFilterSession.selectedTagFilter;
    _selectedTempFilter = MyLeadsFilterSession.selectedTempFilter;
    _sortBy = MyLeadsFilterSession.sortBy;
    _selectedDateRange = MyLeadsFilterSession.selectedDateRange;
    _isFilterExpanded = MyLeadsFilterSession.isFilterExpanded;

    _leadsSub = FirestoreService.instance.streamLeads().listen((leads) {
      if (mounted) {
        setState(() {
          _allLeads = leads;
          _isLoading = false;
        });
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
        MyLeadsFilterSession.searchQuery = _searchQuery;
      });
    });
  }

  @override
  void dispose() {
    _leadsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredLeads {
    var result = List<Map<String, dynamic>>.from(_leads);

    // 1. Sort first to ensure order is preserved during search/filtering
    result.sort((a, b) {
      switch (_sortBy) {
        case 'Client Name':
          return (a['clientName'] as String).compareTo(
            b['clientName'] as String,
          );
        case 'Status':
          return (a['status'] as String).compareTo(b['status'] as String);
        case 'Calls Count':
          return (b['callsCount'] as int).compareTo(a['callsCount'] as int);
        case 'Follow-Up Date':
          final aDate = a['followUpDate'] as String;
          final bDate = b['followUpDate'] as String;
          if (aDate == 'none' && bDate == 'none') return 0;
          if (aDate == 'none') return 1;
          if (bDate == 'none') return -1;
          return aDate.compareTo(bDate);
        case 'Created Date':
        default:
          final aStr = a['createdAt'] as String? ?? '';
          final bStr = b['createdAt'] as String? ?? '';
          final DateTime dateA = aStr.isNotEmpty
              ? (DateTime.tryParse(aStr) ?? DateTime.fromMillisecondsSinceEpoch(0))
              : DateTime.fromMillisecondsSinceEpoch(0);
          final DateTime dateB = bStr.isNotEmpty
              ? (DateTime.tryParse(bStr) ?? DateTime.fromMillisecondsSinceEpoch(0))
              : DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA); // descending — newest first
      }
    });

    // 2. Search filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((l) {
        return (l['clientName'] as String).toLowerCase().contains(q) ||
            (l['phone'] as String).toLowerCase().contains(q) ||
            (l['property'] as String).toLowerCase().contains(q);
      }).toList();
    }

    // 3. Status filter
    if (_selectedFilter != 'All') {
      final filterMap = {
        'New': ['new'],
        'Called': ['called'],
        'Follow-Up': ['follow-up'],
        'SV Scheduled': ['site visit scheduled'],
        'Visited': ['site visit done'],
        'Won': ['won'],
        'Lost/Dead': ['lost/dead', 'lost', 'dead'],
      };
      final targetStatuses = filterMap[_selectedFilter];
      if (targetStatuses != null) {
        result = result.where((l) {
          final leadStatus = (l['status'] as String? ?? '').toLowerCase();
          return targetStatuses.contains(leadStatus);
        }).toList();
      }
    }

    // 4. Temperature filter
    if (_selectedTempFilter != 'All') {
      result = result.where((l) {
        final temp = l['leadTemperature'] as String? ?? '';
        return temp.toLowerCase() == _selectedTempFilter.toLowerCase();
      }).toList();
    }

    // 5. Tag filter
    if (_selectedTagFilter != 'All') {
      result = result.where((l) => l['lastTag'] == _selectedTagFilter).toList();
    }

    // 6. Date range filter
    if (_selectedDateRange != null) {
      result = result.where((l) {
        final fDateStr = l['followUpDate'] as String?;
        if (fDateStr == null || fDateStr == 'none') return false;
        try {
          final parts = fDateStr.split('-');
          if (parts.length != 3) return false;
          final fDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          final start = DateTime(
            _selectedDateRange!.start.year,
            _selectedDateRange!.start.month,
            _selectedDateRange!.start.day,
          );
          final end = DateTime(
            _selectedDateRange!.end.year,
            _selectedDateRange!.end.month,
            _selectedDateRange!.end.day,
          );
          return fDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
              fDate.isBefore(end.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }

    return result;
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isLoading = true;
    });
    _leadsSub?.cancel();
    _leadsSub = FirestoreService.instance.streamLeads().listen((leads) {
      if (mounted) {
        setState(() {
          _allLeads = leads;
          _isLoading = false;
        });
      }
    });
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _selectFollowUpDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now().add(const Duration(days: 3)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.darkText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _sortBy = 'Follow-Up Date';
        MyLeadsFilterSession.selectedDateRange = picked;
        MyLeadsFilterSession.sortBy = 'Follow-Up Date';
      });
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SortSheet(
        currentSort: _sortBy,
        options: _sortOptions,
        onSelect: (val) async {
          Navigator.pop(ctx);
          if (val == 'Follow-Up Date') {
            await _selectFollowUpDateRange();
          } else {
            setState(() {
              _sortBy = val;
              _selectedDateRange = null;
              MyLeadsFilterSession.sortBy = val;
              MyLeadsFilterSession.selectedDateRange = null;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLeads;
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
      drawer: const AppDrawer(currentRoute: '/my-leads-screen'),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Leads',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkText,
              ),
            ),
            Text(
              '${_leads.length} total · ${_leads.length - _leads.where((l) {
                final status = (l['status'] as String? ?? '').toLowerCase();
                return status == 'lost/dead' || status == 'lost' || status == 'dead';
              }).length} active',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppTheme.mutedText,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showSortSheet,
            tooltip: 'Sort',
            icon: CustomIconWidget(
              iconName: 'sort',
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            LeadSearchBarWidget(
              controller: _searchController,
              onClear: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  MyLeadsFilterSession.searchQuery = '';
                });
              },
              onFilterToggle: () {
                setState(() {
                  _isFilterExpanded = !_isFilterExpanded;
                  MyLeadsFilterSession.isFilterExpanded = _isFilterExpanded;
                });
              },
              isFilterExpanded: _isFilterExpanded,
              isFilterActive: _isFilterActive,
              activeFiltersCount: _activeFiltersCount,
            ),
            // Filter chips
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: LeadFilterChipsWidget(
                statusFilters: _statusFilters,
                tagFilters: _tagFilters,
                tempFilters: _tempFilters,
                selectedStatus: _selectedFilter,
                selectedTag: _selectedTagFilter,
                selectedTemp: _selectedTempFilter,
                onStatusChanged: (val) => setState(() {
                  _selectedFilter = val;
                  MyLeadsFilterSession.selectedFilter = val;
                }),
                onTagChanged: (val) => setState(() {
                  _selectedTagFilter = val;
                  MyLeadsFilterSession.selectedTagFilter = val;
                }),
                onTempChanged: (val) => setState(() {
                  _selectedTempFilter = val;
                  MyLeadsFilterSession.selectedTempFilter = val;
                }),
              ),
              crossFadeState: _isFilterExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
              sizeCurve: Curves.easeInOut,
            ),
            if (_selectedDateRange != null)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primary.withAlpha(128),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'event',
                        color: AppTheme.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedDateRange!.start.year == _selectedDateRange!.end.year &&
                                _selectedDateRange!.start.month == _selectedDateRange!.end.month &&
                                _selectedDateRange!.start.day == _selectedDateRange!.end.day
                            ? 'Follow-up: ${_formatDate(_selectedDateRange!.start)}'
                            : 'Follow-up: ${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDateRange = null;
                            MyLeadsFilterSession.selectedDateRange = null;
                          });
                        },
                        child: Icon(
                          Icons.cancel,
                          size: 16,
                          color: AppTheme.primary.withAlpha(178),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Results count bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${filtered.length} lead${filtered.length == 1 ? '' : 's'}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedFilter != 'All' ||
                      _selectedTagFilter != 'All' ||
                      _selectedTempFilter != 'All' ||
                      _selectedDateRange != null ||
                      _searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'All';
                          _selectedTagFilter = 'All';
                          _selectedTempFilter = 'All';
                          _selectedDateRange = null;
                          _searchController.clear();
                          _searchQuery = '';
                          MyLeadsFilterSession.reset();
                        });
                      },
                      child: Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'clear',
                            color: AppTheme.error,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Clear filters',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderColor),
            // Lead list
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: AppTheme.primary,
                child: _isLoading
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: 3,
                        itemBuilder: (context, index) => const LeadCardSkeletonWidget(),
                      )
                    : filtered.isEmpty
                        ? ListView(
                            children: [
                              EmptyStateWidget(
                                iconName: 'people',
                                title: 'No leads found',
                                description: _searchQuery.isNotEmpty
                                    ? 'No leads match "$_searchQuery". Try a different search term.'
                                    : 'No leads match the selected filters. Clear filters to see all leads.',
                                actionLabel:
                                    _searchQuery.isNotEmpty ||
                                        _selectedFilter != 'All'
                                    ? 'Clear Filters'
                                    : null,
                                onAction:
                                    _searchQuery.isNotEmpty ||
                                        _selectedFilter != 'All'
                                    ? () {
                                        setState(() {
                                          _selectedFilter = 'All';
                                          _selectedTagFilter = 'All';
                                          _selectedTempFilter = 'All';
                                          _searchController.clear();
                                          _searchQuery = '';
                                          MyLeadsFilterSession.selectedFilter = 'All';
                                          MyLeadsFilterSession.selectedTagFilter = 'All';
                                          MyLeadsFilterSession.selectedTempFilter = 'All';
                                          MyLeadsFilterSession.searchQuery = '';
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          )
                        : isTablet
                        ? _buildTabletList(filtered)
                        : _buildPhoneList(filtered),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  Widget _buildPhoneList(List<Map<String, dynamic>> leads) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: leads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        return LeadCardWidget(
          lead: leads[idx],
          index: idx,
          onView: () => _onViewLead(leads[idx]),
          onCallNow: () => _onCallNow(leads[idx]),
        );
      },
    );
  }

  Widget _buildTabletList(List<Map<String, dynamic>> leads) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        int crossAxisCount;
        if (screenWidth >= 1200) {
          crossAxisCount = 4;
        } else if (screenWidth >= 900) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        const horizontalPadding = 24.0;
        const spacing = 12.0;
        final maxContentWidth = screenWidth > 1400 ? 1400.0 : screenWidth;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final cardWidth = (maxContentWidth - (horizontalPadding * 2) - totalSpacing) / crossAxisCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: List.generate(leads.length, (idx) {
                      return SizedBox(
                        width: cardWidth,
                        child: LeadCardWidget(
                          lead: leads[idx],
                          index: idx,
                          onView: () => _onViewLead(leads[idx]),
                          onCallNow: () => _onCallNow(leads[idx]),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  void _onViewLead(Map<String, dynamic> lead) {
    Navigator.pushNamed(
      context,
      AppRoutes.leadDetailScreen,
      arguments: {
        'leadId': lead['id'] as String,
        'origin': AppRoutes.myLeadsScreen,
      },
    );
  }

  Future<void> _onCallNow(Map<String, dynamic> lead) async {
    final result = await showInAppDialer(context, lead: lead);
    if (result != null && mounted) {
      try {
        final uid = FirestoreService.instance.currentUid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('calllog')
              .add({
            'leadId': result.leadId,
            'clientName': lead['clientName'] ?? '',
            'phone': lead['phone'] ?? '',
            'property': lead['property'] ?? '',
            'durationSeconds': result.durationSeconds,
            'durationFormatted': result.durationFormatted,
            'noteText': result.noteText,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Error saving call log: $e');
      }

      try {
        final leadTemp = lead['leadTemperature'] as String? ?? '';
        if (leadTemp.isEmpty) {
          await FirestoreService.instance.updateLead(lead['id'] as String, {
            'leadTemperature': 'Cold',
          });
          await FirestoreService.instance.logTemperatureChange(
            leadId: lead['id'] as String,
            clientName: lead['clientName'] as String? ?? 'Lead',
            oldTemp: '',
            newTemp: 'Cold',
          );
        }
      } catch (e) {
        debugPrint('Error updating lead temperature: $e');
      }

      if (mounted) {
        Navigator.pushNamed(
          context,
          AppRoutes.leadDetailScreen,
          arguments: {
            'leadId': lead['id'] as String,
            'origin': AppRoutes.myLeadsScreen,
          },
        );
      }
    }
  }
}




class _SortSheet extends StatelessWidget {
  final String currentSort;
  final List<String> options;
  final void Function(String) onSelect;

  const _SortSheet({
    required this.currentSort,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sort leads by',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final isSelected = opt == currentSort;
            return InkWell(
              onTap: () => onSelect(opt),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.darkText,
                        ),
                      ),
                    ),
                    if (isSelected)
                      CustomIconWidget(
                        iconName: 'check',
                        color: AppTheme.primary,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

