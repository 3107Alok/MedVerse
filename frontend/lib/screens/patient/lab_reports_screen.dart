import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:frontend/screens/pdf_viewer_screen.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/lab_service.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/theme/glassmorphism.dart';
import 'package:frontend/theme/app_theme.dart';

class LabReportsScreen extends StatelessWidget {
  const LabReportsScreen({super.key});

  Future<void> _openReport(BuildContext context, String fileId, String filename) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          fileId: fileId,
          filename: filename,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final patientId = Provider.of<AuthProvider>(context).user?.uid ?? '';
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[700];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Lab Reports'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: LabService().getPatientLabReportsStream(patientId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return GlassLoadingIndicator(isDarkMode: isDark);
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading reports', style: GoogleFonts.outfit(color: textColor)));
          }
          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.science_outlined, size: 64, color: AppTheme.pastelBlue),
                  const SizedBox(height: 16),
                  Text(
                    'No Lab Reports Available',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completed lab tests will show up here automatically.',
                    style: GoogleFonts.outfit(fontSize: 14, color: subtitleColor),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final fileId = report['reportFileId'] ?? '';
              final testName = report['testName'] ?? 'Lab Test';
              final labName = report['labName'] ?? 'Diagnostic Lab';
              final date = report['date'] ?? '';
              final bookingId = report['bookingId'] ?? '';

              return GlassContainer(
                isDarkMode: isDark,
                margin: const EdgeInsets.only(bottom: 10),
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.picture_as_pdf, color: AppTheme.accentColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            testName,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labName,
                            style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Date: $date  •  ID: $bookingId',
                            style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: AppTheme.primaryColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: fileId.isNotEmpty ? () => _openReport(context, fileId, "$testName.pdf") : null,
                      tooltip: 'View Report',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
