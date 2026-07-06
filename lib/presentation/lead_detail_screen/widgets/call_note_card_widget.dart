import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_icon_widget.dart';
import '../../../utils/tag_colors.dart';
import '../../../services/firestore_service.dart';

/// Displays a single call note card in the timeline.
///
/// For manual notes (isAutoLog == false): shows copy icon (always) and
/// edit icon (within 15 minutes of creation). System auto-log entries
/// show no action icons and remain completely immutable.
class CallNoteCardWidget extends StatefulWidget {
  final Map<String, dynamic> note;
  final String leadId;
  final bool isAutoLog;
  final String rawCreatedAt;
  final bool isEdited;
  final VoidCallback? onNoteUpdated;

  const CallNoteCardWidget({
    super.key,
    required this.note,
    required this.leadId,
    this.isAutoLog = false,
    this.rawCreatedAt = '',
    this.isEdited = false,
    this.onNoteUpdated,
  });

  @override
  State<CallNoteCardWidget> createState() => _CallNoteCardWidgetState();
}

class _CallNoteCardWidgetState extends State<CallNoteCardWidget> {
  bool _isEditing = false;
  bool _isSaving = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController(text: widget.note['text'] as String? ?? '');
  }

  @override
  void didUpdateWidget(covariant CallNoteCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller text if note text changed externally (e.g. stream update)
    if (!_isEditing && widget.note['text'] != oldWidget.note['text']) {
      _editCtrl.text = widget.note['text'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  /// Whether this note can be edited (within 15-minute window).
  /// Uses serverCreatedAt for tamper-proof calculation; falls back to
  /// rawCreatedAt (local timestamp) if server timestamp is unavailable.
  bool get _canEdit {
    if (widget.isAutoLog) return false;

    // Try server timestamp first
    final serverCreatedAt = widget.note['serverCreatedAt'] as DateTime?;
    if (serverCreatedAt != null) {
      return DateTime.now().difference(serverCreatedAt).inMinutes < 15;
    }

    // Fallback to raw created-at string
    if (widget.rawCreatedAt.isEmpty) return false;
    final created = DateTime.tryParse(widget.rawCreatedAt);
    if (created == null) return false;
    return DateTime.now().difference(created).inMinutes < 15;
  }

  void _copyNoteText() {
    final text = widget.note['text'] as String? ?? '';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Note copied',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _startEditing() {
    setState(() {
      _editCtrl.text = widget.note['text'] as String? ?? '';
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _editCtrl.text = widget.note['text'] as String? ?? '';
    });
  }

  Future<void> _saveEdit() async {
    final newText = _editCtrl.text.trim();
    if (newText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note text cannot be empty.')),
      );
      return;
    }

    final noteId = widget.note['id'] as String? ?? '';
    if (noteId.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await FirestoreService.instance.updateNoteText(
        widget.leadId,
        noteId,
        newText,
      );

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.success,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Note updated',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
        widget.onNoteUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.error,
            content: Text('Error updating note: $e',
                style: GoogleFonts.inter(color: Colors.white)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawTag = widget.note['tag'] as String? ?? '';
    final tag = (rawTag == 'Busy / Call Later') ? 'Callback' : rawTag;
    final text = widget.note['text'] as String? ?? '';
    final createdAt = widget.note['createdAt'] as String? ?? '';
    final followUpDate = widget.note['followUpDate'] as String?;
    final followUpDateTime = widget.note['followUpDateTime'] as String?;
    final callDuration = widget.note['callDuration'] as String?;
    final isManual = !widget.isAutoLog;
    final canEdit = _canEdit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: date + action icons + tag
          Row(
            children: [
              CustomIconWidget(
                iconName: 'access_time',
                color: AppTheme.mutedText,
                size: 13,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        createdAt,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.mutedText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // "• edited" indicator
                    if (widget.isEdited && isManual) ...[
                      const SizedBox(width: 4),
                      Text(
                        '• edited',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Action icons for manual notes only
              if (isManual) ...[
                // Copy icon — always visible
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: _copyNoteText,
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppTheme.mutedText,
                    tooltip: 'Copy note',
                  ),
                ),
                // Edit icon — only within 15-minute window
                if (canEdit) ...[
                  const SizedBox(width: 2),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      onPressed: _isEditing ? null : _startEditing,
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: AppTheme.primary,
                      tooltip: 'Edit note',
                    ),
                  ),
                ],
                const SizedBox(width: 4),
              ],
              if (tag.isNotEmpty)
                Builder(
                  builder: (context) {
                    final colors = getOutcomeTagColor(tag);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.borderColor, width: 1),
                      ),
                      child: Text(
                        tag,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textColor,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Inline edit mode OR read-only text ──
          if (_isEditing) ...[
            TextField(
              controller: _editCtrl,
              maxLines: 4,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.darkText),
              decoration: InputDecoration(
                hintText: 'Edit your note...',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.mutedText),
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSaving ? null : _cancelEditing,
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ] else ...[
            // Note text (read-only)
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.darkText,
                height: 1.5,
              ),
            ),
          ],

          // Footer: follow-up + call duration
          if ((followUpDate != null && followUpDate.isNotEmpty) ||
              (callDuration != null && callDuration.isNotEmpty)) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 8),
            Row(
              children: [
                if (followUpDate != null && followUpDate.isNotEmpty) ...[
                  CustomIconWidget(
                    iconName: 'event',
                    color: AppTheme.primary,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (context) {
                      String label = 'Follow-up: $followUpDate';
                      if (followUpDateTime != null &&
                          followUpDateTime.isNotEmpty &&
                          followUpDateTime != 'none') {
                        try {
                          final dt = DateTime.parse(followUpDateTime).toLocal();
                          final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                          final amPm = dt.hour >= 12 ? 'PM' : 'AM';
                          final minute = dt.minute.toString().padLeft(2, '0');
                          label = 'Follow-up: $followUpDate at $hour:$minute $amPm';
                        } catch (_) {}
                      }
                      return Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      );
                    },
                  ),
                ],
                const Spacer(),
                if (callDuration != null && callDuration.isNotEmpty) ...[
                  CustomIconWidget(
                    iconName: 'timer',
                    color: AppTheme.mutedText,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    callDuration,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
