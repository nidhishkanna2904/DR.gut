import 'package:flutter/material.dart';
import '../services/report_picker_service.dart';
import '../theme.dart';

class ReportUploadTile extends StatelessWidget {
  final ReportFileResult? selectedReport;
  final ValueChanged<ReportFileResult?> onReportSelected;

  const ReportUploadTile({
    super.key,
    required this.selectedReport,
    required this.onReportSelected,
  });

  void _showPickerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DrGutColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DrGutColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Upload Blood Report',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: const IconChip(icon: Icons.folder_open_outlined),
                title: const Text('Import from device'),
                subtitle: const Text('PDF, JPG, or PNG (Max 10 MB)', style: TextStyle(fontSize: 12, color: DrGutColors.textSecondary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await ReportPickerService.pickFromDevice();
                  if (result != null) {
                    if (result.isTooLarge) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('File exceeds 10 MB limit. Please upload a smaller copy.'),
                            backgroundColor: DrGutColors.error,
                          ),
                        );
                      }
                    } else {
                      onReportSelected(result);
                    }
                  }
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: const IconChip(icon: Icons.photo_camera_outlined),
                title: const Text('Use camera'),
                subtitle: const Text('Capture photo of your report', style: TextStyle(fontSize: 12, color: DrGutColors.textSecondary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await ReportPickerService.pickFromCamera();
                  if (result != null) {
                    if (result.isTooLarge) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Photo exceeds 10 MB limit.'),
                            backgroundColor: DrGutColors.error,
                          ),
                        );
                      }
                    } else {
                      onReportSelected(result);
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final hasFile = selectedReport != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showPickerBottomSheet(context),
          borderRadius: BorderRadius.circular(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (hasFile && selectedReport!.isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        selectedReport!.bytes,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    IconChip(
                      icon: hasFile
                          ? (selectedReport!.name.endsWith('.pdf') ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined)
                          : Icons.cloud_upload_outlined,
                      color: hasFile ? DrGutColors.primary : DrGutColors.textSecondary,
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasFile ? selectedReport!.name : 'Upload blood report',
                          style: t.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: hasFile ? DrGutColors.textPrimary : DrGutColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasFile
                              ? _formatFileSize(selectedReport!.sizeBytes)
                              : 'PDF, JPG or PNG (up to 10 MB)',
                          style: t.bodySmall?.copyWith(color: DrGutColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasFile)
                    Text(
                      'Replace',
                      style: t.labelMedium?.copyWith(
                        color: DrGutColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    const Icon(Icons.arrow_forward_ios, size: 14, color: DrGutColors.textMuted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              const Icon(Icons.shield_outlined, size: 13, color: DrGutColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your report is analyzed securely in-memory and never saved to disk.',
                  style: t.bodySmall?.copyWith(color: DrGutColors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
