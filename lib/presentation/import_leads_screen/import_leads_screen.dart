import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../models/lead_model.dart';
import '../../services/firestore_service.dart';
import '../../routes/app_routes.dart';

class ImportLeadsScreen extends StatefulWidget {
  const ImportLeadsScreen({super.key});

  @override
  State<ImportLeadsScreen> createState() => _ImportLeadsScreenState();
}

class ParsedLeadRow {
  final LeadModel lead;
  final String status; // 'New' or 'Duplicate'
  ParsedLeadRow({required this.lead, required this.status});
}

class _ImportLeadsScreenState extends State<ImportLeadsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  // Tab: 0 = Import & Manage, 1 = Add Manually, 2 = Find Duplicates
  int _activeTab = 0;

  bool _isParsing = false;
  bool _argsInitialized = false;
  String? _origin;
  bool _isImporting = false;
  bool _importDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _activeTab = args['tab'] as int? ?? 0;
        _origin = args['origin'] as String?;
      } else if (args is int) {
        _activeTab = args;
      }
      _argsInitialized = true;
    }
  }
  String? _fileName;
  String? _activeImportSource;
  List<ParsedLeadRow> _previewLeads = [];

  // Batch date-time controller
  DateTime? _csvDefaultLeadGenDateTime;
  final _csvDefaultLeadGenDateTimeCtrl = TextEditingController();

  // Manual lead entry controllers
  final _manualNameCtrl = TextEditingController();
  final _manualPhoneCtrl = TextEditingController();
  final _manualPropertyCtrl = TextEditingController();
  final _manualEmailCtrl = TextEditingController();
  
  DateTime? _manualLeadGenDateTime;
  final _manualLeadGenDateTimeCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isSavingManual = false;

  // Duplicate check state for manual add
  LeadModel? _duplicateLead;
  bool _hasDuplicateConflict = false;

  // Manage Leads state
  StreamSubscription? _leadsSub;
  List<LeadModel> _allLeads = [];
  List<LeadModel> _filteredLeads = [];
  final _searchCtrl = TextEditingController();
  String _selectedSourceFilter = 'All';

  // Find Duplicates state
  bool _isScanningDuplicates = false;
  Map<String, List<LeadModel>> _duplicateGroups = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _csvDefaultLeadGenDateTime = now;
    _manualPhoneCtrl.addListener(_onPhoneChanged);
    _searchCtrl.addListener(_filterAndSearchLeads);

    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    _csvDefaultLeadGenDateTimeCtrl.text = 
        '${months[now.month]} ${now.day}, ${now.year} at ${hour}:${minute} ${amPm}';

    // Stream leads for the Management list
    _leadsSub = FirestoreService.instance.streamLeads().listen((leads) {
      if (mounted) {
        setState(() {
          _allLeads = leads;
          _filterAndSearchLeads();
        });
      }
    });
  }

  @override
  void dispose() {
    _manualPhoneCtrl.removeListener(_onPhoneChanged);
    _searchCtrl.removeListener(_filterAndSearchLeads);
    _leadsSub?.cancel();
    _manualNameCtrl.dispose();
    _manualPhoneCtrl.dispose();
    _manualPropertyCtrl.dispose();
    _manualEmailCtrl.dispose();
    _manualLeadGenDateTimeCtrl.dispose();
    _csvDefaultLeadGenDateTimeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Search & Filtering ───────────────────────────────────────────────────
  void _filterAndSearchLeads() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredLeads = _allLeads.where((lead) {
        // Filter by source
        if (_selectedSourceFilter != 'All') {
          final s = _selectedSourceFilter == 'Manual' ? '' : _selectedSourceFilter;
          if (lead.source != s) return false;
        }
        // Filter by search query
        if (query.isNotEmpty) {
          final nameMatch = lead.clientName.toLowerCase().contains(query);
          final phoneMatch = lead.phone.toLowerCase().contains(query);
          if (!nameMatch && !phoneMatch) return false;
        }
        return true;
      }).toList();
    });
  }

  // ─── Duplicate Checker for Manual Form ────────────────────────────────────
  void _onPhoneChanged() {
    final text = _manualPhoneCtrl.text.trim();
    final normalized = FirestoreService.normalizePhone(text);
    if (normalized.length >= 10) {
      _checkDuplicate(text);
    } else {
      if (_duplicateLead != null) {
        setState(() {
          _duplicateLead = null;
          _hasDuplicateConflict = false;
        });
      }
    }
  }

  Future<void> _checkDuplicate(String enteredPhone) async {
    final dup = await FirestoreService.instance.findDuplicateLead(enteredPhone);
    if (mounted) {
      setState(() {
        _duplicateLead = dup;
        _hasDuplicateConflict = dup != null;
      });
      if (dup != null) {
        _formKey.currentState?.validate();
      }
    }
  }

  // ─── Save Manual Lead ─────────────────────────────────────────────────────
  Future<void> _saveManualLead() async {
    if (!_formKey.currentState!.validate()) return;

    final dup = await FirestoreService.instance.findDuplicateLead(_manualPhoneCtrl.text.trim());
    if (dup != null) {
      setState(() {
        _duplicateLead = dup;
        _hasDuplicateConflict = true;
      });
      _formKey.currentState!.validate();
      return;
    }

    setState(() => _isSavingManual = true);

    final lead = LeadModel(
      id: '',
      clientName: _manualNameCtrl.text.trim(),
      phone: _manualPhoneCtrl.text.trim(),
      property: _manualPropertyCtrl.text.trim().isNotEmpty
          ? _manualPropertyCtrl.text.trim()
          : 'Any',
      status: 'new',
      lastTag: '',
      followUpDate: 'none',
      lastNote: '',
      isActive: true,
      callDuration: '—',
      createdAt: _manualLeadGenDateTime != null
          ? _manualLeadGenDateTime!.toIso8601String()
          : DateTime.now().toIso8601String(),
      callsCount: 0,
      source: '', // Manual
    );

    try {
      await FirestoreService.instance.addLead(lead);
      setState(() => _isSavingManual = false);
      _manualNameCtrl.clear();
      _manualPhoneCtrl.clear();
      _manualPropertyCtrl.clear();
      _manualEmailCtrl.clear();
      _manualLeadGenDateTimeCtrl.clear();
      _manualLeadGenDateTime = null;
      _showSuccessSnackBar('Lead added successfully!');
    } catch (e) {
      setState(() => _isSavingManual = false);
      _showErrorSnackBar('Error saving lead: $e');
    }
  }

  // ─── Scan Duplicates ──────────────────────────────────────────────────────
  Future<void> _scanForDuplicates() async {
    setState(() {
      _isScanningDuplicates = true;
      _duplicateGroups = {};
    });

    try {
      final leads = await FirestoreService.instance.getLeadsOnce();
      final Map<String, List<LeadModel>> groups = {};
      for (final lead in leads) {
        final norm = FirestoreService.normalizePhone(lead.phone);
        if (norm.isNotEmpty) {
          groups.putIfAbsent(norm, () => []).add(lead);
        }
      }

      final Map<String, List<LeadModel>> actualDuplicates = {};
      groups.forEach((key, list) {
        if (list.length >= 2) {
          actualDuplicates[key] = list;
        }
      });

      setState(() {
        _duplicateGroups = actualDuplicates;
        _isScanningDuplicates = false;
      });
    } catch (e) {
      setState(() => _isScanningDuplicates = false);
      _showErrorSnackBar('Error scanning: $e');
    }
  }

  // ─── Delete Duplicate Lead ────────────────────────────────────────────────
  Future<void> _deleteDuplicateLead(LeadModel lead) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Lead?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to delete "${lead.clientName}"? This action is permanent and cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService.instance.deleteLead(lead.id);
        _showSuccessSnackBar('Lead "${lead.clientName}" deleted');
        _scanForDuplicates();
      } catch (e) {
        _showErrorSnackBar('Error deleting lead: $e');
      }
    }
  }

  // ─── Resolve Duplicates Bulk ──────────────────────────────────────────────
  Future<void> _resolveDuplicatesBulk(String phone, List<LeadModel> groupLeads) async {
    final sortedLeads = List<LeadModel>.from(groupLeads);
    sortedLeads.sort((a, b) {
      final dateA = DateTime.tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateB = DateTime.tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dateB.compareTo(dateA); // Newest first
    });

    final newestLead = sortedLeads.first;
    final leadsToDelete = sortedLeads.skip(1).toList();
    final idsToDelete = leadsToDelete.map((l) => l.id).toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Keep Newest, Delete Rest?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'This will keep the newest lead: "${newestLead.clientName}" and permanently delete the other ${leadsToDelete.length} duplicates. This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete ${leadsToDelete.length} Leads', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService.instance.deleteLeadsBatch(idsToDelete);
        _showSuccessSnackBar('${leadsToDelete.length} duplicates resolved successfully.');
        _scanForDuplicates();
      } catch (e) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  // ─── CSV File Picker & Parser ─────────────────────────────────────────────
  Future<void> _pickAndParseFile(String source) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null || file.bytes!.isEmpty) {
        throw Exception("Could not read file data. Please try again.");
      }
      
      setState(() {
        _isParsing = true;
        _fileName = file.name;
        _activeImportSource = source;
        _previewLeads = [];
        _importDone = false;
      });

      String csvString = utf8.decode(file.bytes!, allowMalformed: true);
      csvString = csvString.replaceAll('\uFEFF', '').trim();

      if (csvString.isEmpty) {
        throw Exception("The selected file is empty.");
      }

      String delimiter = ',';
      final firstLine = csvString.split('\n').first;
      if (firstLine.contains(';') && !firstLine.contains(',')) {
        delimiter = ';';
      } else if (firstLine.contains('\t') && !firstLine.contains(',')) {
        delimiter = '\t';
      }

      final fields = const CsvToListConverter().convert(
        csvString,
        fieldDelimiter: delimiter,
        shouldParseNumbers: false,
      );
      
      if (fields.isEmpty) {
        throw Exception("Could not parse any data from the file.");
      }

      final bool hasHeader = fields.length > 1;
      final int dataStart = hasHeader ? 1 : 0;

      if (fields.length <= dataStart) {
        throw Exception("File has no data rows.");
      }

      final headers = fields.first.map((e) => e.toString().toLowerCase().trim()).toList();
      final existingLeads = await FirestoreService.instance.getLeadsOnce();
      final existingPhones = existingLeads.map((l) => FirestoreService.normalizePhone(l.phone)).toSet();

      List<ParsedLeadRow> parsedList = [];
      Set<String> processedPhonesInBatch = {};

      for (int i = dataStart; i < fields.length; i++) {
        final row = fields[i];
        if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) continue;

        String name = '';
        String phone = '';
        String email = '';
        String property = '';
        String dateStr = '';

        if (source == 'MagicBricks') {
          int nameIdx = headers.indexOf('name');
          int mobileIdx = headers.indexWhere((h) => h == 'mobile' || h == 'primaryphone' || h == 'phone');
          int emailIdx = headers.indexOf('email');
          int propIdx = headers.indexWhere((h) => h == 'property' || h == 'propertyname');
          int dateIdx = headers.indexWhere((h) => h == 'date' || h == 'leadgeneratedat');

          if (nameIdx != -1 && row.length > nameIdx) name = row[nameIdx].toString().trim();
          if (mobileIdx != -1 && row.length > mobileIdx) phone = row[mobileIdx].toString().trim();
          if (emailIdx != -1 && row.length > emailIdx) email = row[emailIdx].toString().trim();
          if (propIdx != -1 && row.length > propIdx) property = row[propIdx].toString().trim();
          if (dateIdx != -1 && row.length > dateIdx) dateStr = row[dateIdx].toString().trim();

        } else if (source == '99acres') {
          int nameIdx = headers.indexOf('name');
          int phoneIdx = headers.indexWhere((h) => h == 'contact number' || h == 'contactnumber' || h == 'phone' || h == 'mobile');
          int emailIdx = headers.indexOf('email');
          int projIdx = headers.indexWhere((h) => h == 'project' || h == 'property');
          int dateIdx = headers.indexWhere((h) => h == 'enquiry date' || h == 'enquirydate' || h == 'date');

          if (nameIdx != -1 && row.length > nameIdx) name = row[nameIdx].toString().trim();
          if (phoneIdx != -1 && row.length > phoneIdx) phone = row[phoneIdx].toString().trim();
          if (emailIdx != -1 && row.length > emailIdx) email = row[emailIdx].toString().trim();
          if (projIdx != -1 && row.length > projIdx) property = row[projIdx].toString().trim();
          if (dateIdx != -1 && row.length > dateIdx) dateStr = row[dateIdx].toString().trim();

        } else if (source == 'NoBroker') {
          int nameIdx = headers.indexWhere((h) => h == 'customer name' || h == 'customername' || h == 'name');
          int phoneIdx = headers.indexOf('phone');
          int emailIdx = headers.indexOf('email');
          int propIdx = headers.indexOf('property');
          int dateIdx = headers.indexOf('date');

          if (nameIdx != -1 && row.length > nameIdx) name = row[nameIdx].toString().trim();
          if (phoneIdx != -1 && row.length > phoneIdx) phone = row[phoneIdx].toString().trim();
          if (emailIdx != -1 && row.length > emailIdx) email = row[emailIdx].toString().trim();
          if (propIdx != -1 && row.length > propIdx) property = row[propIdx].toString().trim();
          if (dateIdx != -1 && row.length > dateIdx) dateStr = row[dateIdx].toString().trim();

        } else if (source == 'Meta Ads') {
          int nameIdx = headers.indexWhere((h) => h == 'full_name' || h == 'fullname' || h == 'name');
          int phoneIdx = headers.indexWhere((h) => h == 'phone_number' || h == 'phonenumber' || h == 'phone');
          int emailIdx = headers.indexOf('email');
          int adIdx = headers.indexWhere((h) => h == 'ad_name' || h == 'adname' || h == 'property');
          int dateIdx = headers.indexWhere((h) => h == 'created_time' || h == 'createdtime' || h == 'date');

          if (nameIdx != -1 && row.length > nameIdx) name = row[nameIdx].toString().trim();
          if (phoneIdx != -1 && row.length > phoneIdx) phone = row[phoneIdx].toString().trim();
          if (emailIdx != -1 && row.length > emailIdx) email = row[emailIdx].toString().trim();
          if (adIdx != -1 && row.length > adIdx) property = row[adIdx].toString().trim();
          if (dateIdx != -1 && row.length > dateIdx) dateStr = row[dateIdx].toString().trim();

        } else if (source == 'Google Ads') {
          int fNameIdx = headers.indexWhere((h) => h == 'first name' || h == 'firstname');
          int lNameIdx = headers.indexWhere((h) => h == 'last name' || h == 'lastname');
          int nameIdx = headers.indexOf('name');
          int phoneIdx = headers.indexWhere((h) => h == 'phone number' || h == 'phonenumber' || h == 'phone');
          int emailIdx = headers.indexOf('email');
          int campIdx = headers.indexWhere((h) => h == 'campaign name' || h == 'campaignname' || h == 'property');
          int dateIdx = headers.indexOf('date');

          if (fNameIdx != -1 && row.length > fNameIdx) {
            String fname = row[fNameIdx].toString().trim();
            String lname = (lNameIdx != -1 && row.length > lNameIdx) ? row[lNameIdx].toString().trim() : '';
            name = '$fname $lname'.trim();
          } else if (nameIdx != -1 && row.length > nameIdx) {
            name = row[nameIdx].toString().trim();
          }
          if (phoneIdx != -1 && row.length > phoneIdx) phone = row[phoneIdx].toString().trim();
          if (emailIdx != -1 && row.length > emailIdx) email = row[emailIdx].toString().trim();
          if (campIdx != -1 && row.length > campIdx) property = row[campIdx].toString().trim();
          if (dateIdx != -1 && row.length > dateIdx) dateStr = row[dateIdx].toString().trim();
        }

        if (phone.endsWith('.0')) phone = phone.substring(0, phone.length - 2);

        DateTime? parsedDate;
        if (dateStr.isNotEmpty) {
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (_) {}
        }
        final createdAtDate = parsedDate ?? _csvDefaultLeadGenDateTime ?? DateTime.now();
        final normalizedPhone = FirestoreService.normalizePhone(phone);

        bool isDuplicate = false;
        if (normalizedPhone.isNotEmpty) {
          if (existingPhones.contains(normalizedPhone) || processedPhonesInBatch.contains(normalizedPhone)) {
            isDuplicate = true;
          } else {
            processedPhonesInBatch.add(normalizedPhone);
          }
        }

        final lead = LeadModel(
          id: '',
          clientName: name.isNotEmpty ? name : 'Unknown Lead',
          phone: phone.isNotEmpty ? phone : 'No Phone',
          email: email,
          property: property.isNotEmpty ? property : 'Any',
          status: 'new',
          lastTag: '',
          followUpDate: 'none',
          lastNote: '',
          isActive: true,
          callDuration: '—',
          createdAt: createdAtDate.toIso8601String(),
          callsCount: 0,
          source: source,
        );

        parsedList.add(ParsedLeadRow(
          lead: lead,
          status: isDuplicate ? 'Duplicate' : 'New',
        ));
      }

      if (parsedList.isEmpty) {
        throw Exception("No valid rows parsed from the CSV.");
      }

      setState(() {
        _previewLeads = parsedList;
        _isParsing = false;
      });

    } catch (e) {
      setState(() => _isParsing = false);
      _showErrorSnackBar('$e');
    }
  }

  // ─── Import Confirmed Leads ───────────────────────────────────────────────
  Future<void> _importConfirmedLeads() async {
    final newLeads = _previewLeads
        .where((r) => r.status == 'New')
        .map((r) => r.lead)
        .toList();

    if (newLeads.isEmpty) {
      setState(() {
        _importDone = true;
      });
      return;
    }

    setState(() => _isImporting = true);

    try {
      await FirestoreService.instance.addLeadsBatch(newLeads);

      final importedCount = newLeads.length;
      final skippedCount = _previewLeads.length - importedCount;

      setState(() {
        _isImporting = false;
        _importDone = true;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Import Summary', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            content: Text(
              '$importedCount leads imported successfully.\n$skippedCount duplicate leads were skipped.',
              style: GoogleFonts.inter(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                },
                child: Text('OK', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      _showErrorSnackBar('Error importing leads: $e');
    }
  }

  void _reset() {
    setState(() {
      _fileName = null;
      _activeImportSource = null;
      _previewLeads = [];
      _importDone = false;
    });
  }

  // ─── Helpers for Snackbars ────────────────────────────────────────────────
  void _showSuccessSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.success,
          content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(msg, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildTabSelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final useCompactTabs = screenWidth < 600;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton(0, Icons.upload_file, useCompactTabs ? 'Import' : 'Import & Manage'),
          const SizedBox(width: 4),
          _buildTabButton(1, Icons.person_add, useCompactTabs ? 'Add' : 'Add Manually'),
          const SizedBox(width: 4),
          _buildTabButton(2, Icons.people_outline, useCompactTabs ? 'Duplicates' : 'Find Duplicates'),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            horizontalMargin: 16,
            columnSpacing: 20,
            columns: [
              DataColumn(label: Text('Name', style: _headerStyle())),
              DataColumn(label: Text('Phone', style: _headerStyle())),
              DataColumn(label: Text('Email', style: _headerStyle())),
              DataColumn(label: Text('Property', style: _headerStyle())),
              DataColumn(label: Text('Source', style: _headerStyle())),
              DataColumn(label: Text('Status', style: _headerStyle())),
            ],
            rows: _previewLeads.map((row) {
              final isNew = row.status == 'New';
              return DataRow(
                cells: [
                  DataCell(Text(row.lead.clientName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkText))),
                  DataCell(Text(row.lead.phone, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText))),
                  DataCell(Text(row.lead.email.isNotEmpty ? row.lead.email : '—', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText))),
                  DataCell(Text(row.lead.property, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText))),
                  DataCell(Text(row.lead.source, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isNew ? AppTheme.successContainer : AppTheme.errorContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        row.status,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isNew ? AppTheme.success : AppTheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─── Tab Button Builder ───────────────────────────────────────────────────
  Widget _buildTabButton(int index, IconData icon, String label) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
          if (index == 2) {
            _scanForDuplicates();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? AppTheme.primary : AppTheme.mutedText),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? AppTheme.primary : AppTheme.mutedText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppTheme.mutedText,
    letterSpacing: 0.5,
  );

  // ─── UI Layout Grid of Integrations ───────────────────────────────────────
  Widget _buildIntegrationGrid() {
    final integrations = [
      {'name': 'MagicBricks', 'desc': 'CSV export from MagicBricks portal', 'icon': Icons.home_work_outlined, 'color': Colors.orange},
      {'name': '99acres', 'desc': 'CSV export from 99acres portal', 'icon': Icons.apartment_outlined, 'color': Colors.blue},
      {'name': 'NoBroker', 'desc': 'CSV export from NoBroker portal', 'icon': Icons.money_off_outlined, 'color': Colors.green},
      {'name': 'Meta Ads', 'desc': 'CSV export of Facebook/Instagram ads', 'icon': Icons.campaign_outlined, 'color': Colors.indigo},
      {'name': 'Google Ads', 'desc': 'Google Ads lead form CSV export', 'icon': Icons.ads_click_outlined, 'color': Colors.red},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 600;
        final crossAxisCount = constraints.maxWidth > 900 ? 5 : (constraints.maxWidth > 600 ? 3 : 2);
        final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
        final cardHeight = isMobile ? 145.0 : 130.0;
        final childAspectRatio = cardWidth / cardHeight;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: integrations.length,
          itemBuilder: (context, idx) {
            final item = integrations[idx];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['name'] as String,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    item['desc'] as String,
                    style: GoogleFonts.inter(fontSize: 10, color: AppTheme.mutedText),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _pickAndParseFile(item['name'] as String),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Connect',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Manage Leads Section Widget ──────────────────────────────────────────
  Widget _buildManageLeadsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.people_outline, color: AppTheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'Manage Leads',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFD1D5DB)),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.mutedText),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderColor),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSourceFilter,
                  items: ['All', 'MagicBricks', '99acres', 'NoBroker', 'Meta Ads', 'Google Ads', 'Manual']
                      .map((src) => DropdownMenuItem(
                            value: src,
                            child: Text(
                              src == 'Manual' ? 'Manual (No Source)' : src,
                              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedSourceFilter = val;
                        _filterAndSearchLeads();
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_filteredLeads.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const Icon(Icons.people_outline, size: 48, color: AppTheme.borderColor),
                  const SizedBox(height: 8),
                  Text(
                    'No leads found matching criteria',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredLeads.length,
              separatorBuilder: (context, idx) => const Divider(height: 1, color: AppTheme.borderColor),
              itemBuilder: (context, idx) {
                final lead = _filteredLeads[idx];
                final dateStr = lead.createdAt.length >= 10 ? lead.createdAt.substring(0, 10) : lead.createdAt;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    lead.clientName,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkText),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildInfoBadge(Icons.phone, lead.phone),
                        _buildInfoBadge(Icons.apartment, lead.property),
                        _buildInfoBadge(Icons.source, lead.source.isNotEmpty ? lead.source : 'Manual'),
                        _buildInfoBadge(Icons.calendar_month, dateStr),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                    onPressed: () => _deleteLeadConfirmation(lead),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildInfoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.mutedText),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.mutedText, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _deleteLeadConfirmation(LeadModel lead) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Lead?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'Delete "${lead.clientName}"? This action is permanent and cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.mutedText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService.instance.deleteLead(lead.id);
        _showSuccessSnackBar('Lead deleted');
      } catch (e) {
        _showErrorSnackBar('Error deleting: $e');
      }
    }
  }

  // ─── Find Duplicates View ─────────────────────────────────────────────────
  Widget _buildDuplicatesTab() {
    if (_isScanningDuplicates) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (_duplicateGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: AppTheme.success),
              const SizedBox(height: 16),
              Text(
                'No duplicate leads found ✓',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.success),
              ),
              const SizedBox(height: 8),
              Text(
                'All active leads have unique phone numbers.',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.people_outline,
          title: 'Duplicate Leads Resolver',
          subtitle: 'Scan and resolve duplicate leads in Firestore by primary phone number.',
        ),
        const SizedBox(height: 20),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _duplicateGroups.length,
          separatorBuilder: (context, idx) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final key = _duplicateGroups.keys.elementAt(idx);
            final leads = _duplicateGroups[key]!;
            return Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppTheme.borderColor),
              ),
              child: ExpansionTile(
                title: Text(
                  'Phone: $key',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkText),
                ),
                subtitle: Text(
                  'Matched names: ${leads.map((l) => l.clientName).join(", ")}',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${leads.length} Duplicates',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.error),
                  ),
                ),
                children: [
                  const Divider(height: 1, color: AppTheme.borderColor),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: leads.length,
                    itemBuilder: (context, lIdx) {
                      final lead = leads[lIdx];
                      final dateStr = lead.createdAt.length >= 10 ? lead.createdAt.substring(0, 10) : lead.createdAt;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          lead.clientName,
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText),
                        ),
                        subtitle: Text(
                          'Property: ${lead.property}  |  Source: ${lead.source.isNotEmpty ? lead.source : "Manual"}\nAdded: $dateStr  |  Status: ${lead.status.toUpperCase()}',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText, height: 1.4),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                          onPressed: () => _deleteDuplicateLead(lead),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppTheme.borderColor),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => _resolveDuplicatesBulk(key, leads),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.auto_delete, size: 16),
                        label: Text(
                          'Keep Newest, Delete Rest',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Main Scaffold build ──────────────────────────────────────────────────
  void _goBack() {
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboardScreen, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        _goBack();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppTheme.surfaceLight,
          elevation: 0,
          leading: _origin != null
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
                  onPressed: _goBack,
                )
              : Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: AppTheme.primary),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
        title: Text(
          'Import & Manage Leads',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.darkText,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderColor),
        ),
      ),
      drawer: const AppDrawer(currentRoute: '/import-leads-screen'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab Selector
            _buildTabSelector(),
            const SizedBox(height: 24),

            // TAB 0: CSV Import & Management
            if (_activeTab == 0) ...[
              if (_previewLeads.isEmpty && !_isParsing) ...[
                _SectionHeader(
                  icon: Icons.upload_file,
                  title: 'Lead Source Integrations',
                  subtitle: 'Select a lead source below and upload its CSV export to map and import leads.',
                ),
                const SizedBox(height: 16),
                _buildIntegrationGrid(),
                const SizedBox(height: 20),
                _buildManageLeadsSection(),
              ],
              if (_isParsing) ...[
                _ParsingIndicator(fileName: _fileName ?? '')
              ],
              if (_previewLeads.isNotEmpty) ...[
                _PreviewHeader(
                  fileName: _fileName ?? '',
                  rowCount: _previewLeads.length,
                  importDone: _importDone,
                  onReset: _reset,
                ),
                const SizedBox(height: 16),
                _buildPreviewTable(),
                const SizedBox(height: 20),
                if (!_importDone) ...[
                  // Date Picker configuration for missing CSV dates
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch Lead Generation Date & Time',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Applied to imported leads that do not specify a date/time in the CSV.',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.mutedText),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _csvDefaultLeadGenDateTimeCtrl,
                          readOnly: true,
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
                          decoration: InputDecoration(
                            hintText: 'Select Date & Time',
                            prefixIcon: const Icon(Icons.access_time, size: 16),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppTheme.borderColor),
                            ),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _csvDefaultLeadGenDateTime ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null && mounted) {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(_csvDefaultLeadGenDateTime ?? DateTime.now()),
                              );
                              if (time != null && mounted) {
                                setState(() {
                                  _csvDefaultLeadGenDateTime = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                  const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                  final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
                                  final amPm = time.hour >= 12 ? 'PM' : 'AM';
                                  final minute = time.minute.toString().padLeft(2, '0');
                                  _csvDefaultLeadGenDateTimeCtrl.text = 
                                      '${months[date.month]} ${date.day}, ${date.year} at ${hour}:${minute} ${amPm}';
                                });
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ImportButton(
                    rowCount: _previewLeads.length,
                    newCount: _previewLeads.where((r) => r.status == 'New').length,
                    isLoading: _isImporting,
                    onImport: _importConfirmedLeads,
                  ),
                ],
                if (_importDone)
                  _ImportSuccessBanner(
                    rowCount: _previewLeads.where((r) => r.status == 'New').length,
                    duplicateCount: _previewLeads.where((r) => r.status == 'Duplicate').length,
                    onGoToLeads: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/my-leads-screen', (r) => false,
                    ),
                    onReset: _reset,
                  ),
              ],
            ],

            // TAB 1: Add Manually
            if (_activeTab == 1) ...[
              _SectionHeader(
                icon: Icons.person_add,
                title: 'Add Lead Manually',
                subtitle: 'Fill in the details below to add a single lead to your pipeline.',
              ),
              const SizedBox(height: 24),
              _ManualLeadForm(
                formKey: _formKey,
                nameCtrl: _manualNameCtrl,
                phoneCtrl: _manualPhoneCtrl,
                propertyCtrl: _manualPropertyCtrl,
                emailCtrl: _manualEmailCtrl,
                dateCtrl: _manualLeadGenDateTimeCtrl,
                onTapDate: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null && mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null && mounted) {
                      setState(() {
                        _manualLeadGenDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                        const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                        final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
                        final amPm = time.hour >= 12 ? 'PM' : 'AM';
                        final minute = time.minute.toString().padLeft(2, '0');
                        _manualLeadGenDateTimeCtrl.text = 
                            '${months[date.month]} ${date.day}, ${date.year} at ${hour}:${minute} ${amPm}';
                      });
                    }
                  }
                },
                isSaving: _isSavingManual,
                onSave: _saveManualLead,
                duplicateLead: _duplicateLead,
                hasDuplicateConflict: _hasDuplicateConflict,
              ),
            ],

            // TAB 2: Find Duplicates
            if (_activeTab == 2) ...[
              _buildDuplicatesTab(),
            ],
          ],
        ),
      ),
    ),
    ),
    );
  }
}

// ─── Shared UI Helper Components ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(icon, color: AppTheme.primary, size: 22),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.mutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParsingIndicator extends StatelessWidget {
  final String fileName;
  const _ParsingIndicator({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 16),
          Text(
            'Parsing "$fileName"…',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reading rows, mapping columns, and scanning for duplicates',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  final String fileName;
  final int rowCount;
  final bool importDone;
  final VoidCallback onReset;

  const _PreviewHeader({
    required this.fileName,
    required this.rowCount,
    required this.importDone,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.successContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 14),
              const SizedBox(width: 5),
              Text(
                '$rowCount leads parsed',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            fileName,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!importDone)
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(
              Icons.refresh,
              size: 14,
              color: AppTheme.mutedText,
            ),
            label: Text(
              'Change file',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.mutedText),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
      ],
    );
  }
}

class _ImportButton extends StatelessWidget {
  final int rowCount;
  final int newCount;
  final bool isLoading;
  final VoidCallback onImport;

  const _ImportButton({
    required this.rowCount,
    required this.newCount,
    required this.isLoading,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onImport,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Importing…',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Import $newCount New Leads (Skip ${rowCount - newCount} Duplicates)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ImportSuccessBanner extends StatelessWidget {
  final int rowCount;
  final int duplicateCount;
  final VoidCallback onGoToLeads;
  final VoidCallback onReset;

  const _ImportSuccessBanner({
    required this.rowCount,
    required this.duplicateCount,
    required this.onGoToLeads,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.successContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withAlpha(77)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.success, size: 40),
          const SizedBox(height: 12),
          Text(
            'Import Completed!',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$rowCount new leads added. $duplicateCount duplicate leads were skipped.',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.success),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onGoToLeads,
                icon: const Icon(Icons.people, size: 16),
                label: Text(
                  'View My Leads',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(
                  'Import More',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManualLeadForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController propertyCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController dateCtrl;
  final VoidCallback onTapDate;
  final bool isSaving;
  final VoidCallback onSave;
  final LeadModel? duplicateLead;
  final bool hasDuplicateConflict;

  const _ManualLeadForm({
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.propertyCtrl,
    required this.emailCtrl,
    required this.dateCtrl,
    required this.onTapDate,
    required this.isSaving,
    required this.onSave,
    this.duplicateLead,
    this.hasDuplicateConflict = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FieldLabel(label: 'Full Name', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: nameCtrl,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
              decoration: _inputDecoration('e.g. Rajesh Kumar', Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            const _FieldLabel(label: 'Phone Number', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: phoneCtrl,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
              decoration: _inputDecoration('e.g. 9876543210', Icons.phone_outlined),
              keyboardType: TextInputType.phone,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone number is required';
                if (v.trim().length < 10) return 'Enter a valid phone number';
                if (hasDuplicateConflict) return 'This lead already exists';
                return null;
              },
            ),
            if (duplicateLead != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.error),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This lead already exists — ${duplicateLead!.clientName} (${duplicateLead!.property})',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.error,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.leadDetailScreen,
                          arguments: duplicateLead!.id,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.visibility, size: 16),
                      label: Text(
                        'View Existing Lead',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            const _FieldLabel(label: 'Property Interest', required: false),
            const SizedBox(height: 6),
            StatefulBuilder(
              builder: (context, setStateLocal) {
                final currentText = propertyCtrl.text.trim();
                final List<String> dropdownOptions = ['Any', 'Mantri Serenity', 'Mantri Courtyard'];
                final String dropdownValue = dropdownOptions.contains(currentText)
                    ? (currentText.isEmpty ? 'Any' : currentText)
                    : 'Any';

                return DropdownButtonFormField<String>(
                  value: dropdownValue,
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
                  decoration: _inputDecoration('Select Property', Icons.apartment_outlined),
                  dropdownColor: Colors.white,
                  items: dropdownOptions.map((prop) {
                    return DropdownMenuItem<String>(
                      value: prop,
                      child: Text(prop),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      propertyCtrl.text = val;
                      setStateLocal(() {});
                    }
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            const _FieldLabel(label: 'Email (optional)', required: false),
            const SizedBox(height: 6),
            TextFormField(
              controller: emailCtrl,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
              decoration: _inputDecoration('e.g. rajesh@email.com', Icons.email_outlined),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),

            const _FieldLabel(label: 'Lead Generation Date & Time', required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: dateCtrl,
              readOnly: true,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.darkText),
              decoration: _inputDecoration('Select Date & Time', Icons.access_time),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Lead Generation Date & Time is required' : null,
              onTap: onTapDate,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Add Lead',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFD1D5DB)),
      prefixIcon: Icon(icon, size: 18, color: AppTheme.mutedText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkText,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          Text('*', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.error)),
        ],
      ],
    );
  }
}
