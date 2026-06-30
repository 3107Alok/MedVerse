import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/booking_service.dart';
import 'package:frontend/services/lab_service.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/theme/glassmorphism.dart';
import 'package:frontend/widgets/shared_glass_components.dart';
import 'package:frontend/widgets/empty_state_widget.dart';
import 'package:frontend/widgets/shimmer_loader.dart';

class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  final BookingService _bookingService = BookingService();
  final LabService _labService = LabService();

  List<Map<String, dynamic>>? _doctorBookings;
  List<Map<String, dynamic>>? _labBookings;

  StreamSubscription? _doctorSub;
  StreamSubscription? _labSub;

  // Expansion state mapped by Date string
  final Map<String, bool> _expansionStates = {};

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final patientId = authProvider.user?.uid ?? '';

      _doctorSub = _bookingService.getPatientAppointmentsStream(patientId).listen((data) {
        if (mounted) {
          setState(() => _doctorBookings = data);
        }
      });

      _labSub = _labService.getPatientLabBookingsStream(patientId).listen((data) {
        if (mounted) {
          setState(() {
            _labBookings = data.map((e) {
              e['isLab'] = true;
              return e;
            }).toList();
          });
        }
      });
    });
  }

  Future<void> _handleRefresh() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final patientId = authProvider.user?.uid ?? '';

    // Temporarily cancel listener and pull manually to prevent full state flickering
    _doctorSub?.cancel();
    _labSub?.cancel();

    try {
      final docFuture = _bookingService.getPatientAppointmentsStream(patientId).first;
      final labFuture = _labService.getPatientLabBookingsStream(patientId).first;

      final results = await Future.wait([docFuture, labFuture]);

      if (mounted) {
        setState(() {
          _doctorBookings = results[0];
          _labBookings = results[1].map((e) {
            e['isLab'] = true;
            return e;
          }).toList();
        });
      }
    } catch (_) {}

    // Restore real-time listeners
    if (mounted) {
      _doctorSub = _bookingService.getPatientAppointmentsStream(patientId).listen((data) {
        if (mounted) {
          setState(() => _doctorBookings = data);
        }
      });

      _labSub = _labService.getPatientLabBookingsStream(patientId).listen((data) {
        if (mounted) {
          setState(() {
            _labBookings = data.map((e) {
              e['isLab'] = true;
              return e;
            }).toList();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _doctorSub?.cancel();
    _labSub?.cancel();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
      case 'approved':
        return Colors.blue;
      case 'checked_in':
      case 'checked in':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
      default:
        return Colors.grey;
    }
  }

  String _formatHeaderDate(String dateStr) {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

      if (dateStr == todayStr) return 'Today';
      if (dateStr == yesterdayStr) return 'Yesterday';

      final date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('d MMMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _cancelBooking(String id, bool isLab) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Request', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel this booking request?', style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, Cancel', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (isLab) {
          await FirebaseFirestore.instance.collection('lab_bookings').doc(id).delete();
        } else {
          await FirebaseFirestore.instance.collection('appointments').doc(id).delete();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking request cancelled successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel request: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDarkMode;

    final bgColor = isDark ? const Color(0xFF0F0F1A) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[600];

    // Initial Loading State -> Shimmer skeletons
    if (_doctorBookings == null || _labBookings == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text('Appointment History', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.getBackgroundGradient(isDark),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ShimmerWidget(
                  width: double.infinity,
                  height: 120,
                  borderRadius: 20,
                ),
              );
            },
          ),
        ),
      );
    }

    final combined = [..._doctorBookings!, ..._labBookings!];
    
    // Group combined appointments by date field
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var appt in combined) {
      final dateStr = appt['date'] ?? 'Unknown Date';
      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }
      grouped[dateStr]!.add(appt);
    }

    // Sort grouped dates descending (newest at the top)
    final sortedDates = grouped.keys.toList();
    sortedDates.sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          'Appointment History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getBackgroundGradient(isDark),
        ),
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: combined.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 100),
                    EmptyStateWidget(
                      icon: Icons.calendar_today_outlined,
                      title: 'No Appointment History',
                      description: 'Your completed and upcoming appointments\nwill appear here.',
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    final dateKey = sortedDates[index];
                    final list = grouped[dateKey] ?? [];
                    final isExpanded = _expansionStates[dateKey] ?? false;

                    // Sort items within the same day by createdAt or time_slot
                    list.sort((a, b) {
                      final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                      return bTime.compareTo(aTime);
                    });

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GlassContainer(
                        isDarkMode: isDark,
                        borderRadius: 20,
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            // Collapsible Header Card
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _expansionStates[dateKey] = !isExpanded;
                                });
                              },
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: Radius.circular(isExpanded ? 0 : 20),
                                bottomRight: Radius.circular(isExpanded ? 0 : 20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month, color: AppTheme.primaryColor, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatHeaderDate(dateKey),
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${list.length} appointment${list.length > 1 ? 's' : ''}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: subtitleColor,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Expandable list items
                            AnimatedCrossFade(
                              firstChild: const SizedBox.shrink(),
                              secondChild: Column(
                                children: list.map((appt) {
                                  final isLab = appt['isLab'] == true;
                                  final status = appt['status']?.toString() ?? 'pending';
                                  final statusColor = _getStatusColor(status);

                                  final bookingTimeText = appt['createdAt'] != null
                                      ? DateFormat('MMM dd, yyyy • hh:mm a')
                                          .format((appt['createdAt'] as Timestamp).toDate())
                                      : 'Just now';

                                  return Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                        ),
                                      ),
                                    ),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            width: 5,
                                            color: statusColor,
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          isLab
                                                              ? (appt['labName'] ?? 'Diagnostic Lab')
                                                              : (appt['doctor_name'] ?? 'Doctor'),
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.bold,
                                                            color: textColor,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: statusColor.withOpacity(0.12),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          status.toUpperCase(),
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            color: statusColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  if (isLab)
                                                    Text(
                                                      'LAB BOOKING • ${appt['testName']}',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11,
                                                        color: subtitleColor,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    )
                                                  else
                                                    FutureBuilder<Map<String, dynamic>?>(
                                                      future: _bookingService.getPatientById(appt['doctor_id'] ?? ''),
                                                      builder: (context, docSnapshot) {
                                                        if (docSnapshot.hasData && docSnapshot.data != null) {
                                                          final docData = docSnapshot.data!;
                                                          final dept = docData['department'] ?? docData['category'] ?? 'General Medicine';
                                                          final spec = docData['specialization'] ?? '';
                                                          final displayInfo = spec.isNotEmpty ? '$dept ($spec)' : dept;
                                                          return Text(
                                                            displayInfo,
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 11,
                                                              color: subtitleColor,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          );
                                                        }
                                                        return Text(
                                                          'General Medicine',
                                                          style: GoogleFonts.outfit(
                                                            fontSize: 11,
                                                            color: subtitleColor,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.access_time_filled, size: 14, color: subtitleColor),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Slot: ${appt['time_slot']}',
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: textColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Reason / Symptoms:',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 11,
                                                      color: subtitleColor,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    appt['symptoms'] ?? 'No symptoms provided',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 13,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Divider(height: 1, color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        isLab ? 'Booking ID:' : 'Booked On:',
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 10,
                                                          color: subtitleColor,
                                                        ),
                                                      ),
                                                      Text(
                                                        isLab ? (appt['bookingId'] ?? '') : bookingTimeText,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 10,
                                                          color: subtitleColor,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (status.toLowerCase() == 'pending') ...[
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        OutlinedButton.icon(
                                                          onPressed: () => _cancelBooking(appt['id'] ?? '', isLab),
                                                          icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                                          label: Text(
                                                            'Cancel Request',
                                                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                                                          ),
                                                          style: OutlinedButton.styleFrom(
                                                            foregroundColor: Colors.red,
                                                            side: const BorderSide(color: Colors.red, width: 1.2),
                                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                            minimumSize: const Size(0, 30),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 250),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
