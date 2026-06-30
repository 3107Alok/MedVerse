import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/booking_service.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/theme/glassmorphism.dart';
import 'package:frontend/widgets/shared_glass_components.dart';

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key});

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  List<dynamic> _doctors = [];
  bool _isLoading = true;
  String? _selectedDoctorId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;
  final BookingService _bookingService = BookingService();
  
  final _symptomsController = TextEditingController();

  List<String> _dynamicSlots = [];
  bool _isSlotsLoading = false;
  String? _slotsErrorMessage;
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    super.dispose();
  }

  Future<void> _fetchDoctors() async {
    try {
      final doctors = await _bookingService.getVerifiedDoctors();
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.settings.arguments is String) {
          final argsId = ModalRoute.of(context)!.settings.arguments as String;
          if (argsId.isNotEmpty && _doctors.any((d) => d['uid'] == argsId)) {
            setState(() {
              _selectedDoctorId = argsId;
            });
            _updateAvailableSlots();
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateAvailableSlots() async {
    if (_selectedDoctorId == null) return;
    
    setState(() {
      _isSlotsLoading = true;
      _dynamicSlots = [];
      _selectedSlot = null;
      _slotsErrorMessage = null;
    });

    try {
      final doc = _doctors.firstWhere((d) => d['uid'] == _selectedDoctorId);
      final rawOnline = doc['onlineStatus'];
      final bool isOnline = rawOnline == true || rawOnline == null || rawOnline.toString().toLowerCase() == 'online';
      if (!isOnline) {
        setState(() {
          _slotsErrorMessage = "Doctor is currently offline and not accepting bookings.";
          _isSlotsLoading = false;
        });
        return;
      }

      final rawAvail = doc['availability'];
      if (rawAvail == null) {
        // Fallback slots if doctor profile is legacy
        setState(() {
          _dynamicSlots = ['09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM', '04:00 PM'];
          _isSlotsLoading = false;
        });
        return;
      }

      final workingDays = List<String>.from(rawAvail['workingDays'] ?? []);
      final String dayName = DateFormat('EEEE').format(_selectedDate); // e.g. "Monday"
      
      if (!workingDays.contains(dayName)) {
        setState(() {
          _slotsErrorMessage = "Doctor does not consult on $dayName.\nAvailable days: ${workingDays.join(', ')}";
          _isSlotsLoading = false;
        });
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final booked = await _bookingService.getBookedSlotsForDoctor(_selectedDoctorId!, dateStr);

      final String startTime = rawAvail['startTime'] ?? "09:00";
      final String endTime = rawAvail['endTime'] ?? "17:00";
      final int duration = rawAvail['consultationDuration'] ?? 20;
      final int buffer = rawAvail['bufferTime'] ?? 10;
      final String breakStartStr = rawAvail['breakTimeStart'] ?? "13:00";
      final String breakEndStr = rawAvail['breakTimeEnd'] ?? "14:00";

      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      final breakStartParts = breakStartStr.split(':');
      final breakEndParts = breakEndStr.split(':');

      var current = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 
          int.parse(startParts[0]), int.parse(startParts[1]));
      final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 
          int.parse(endParts[0]), int.parse(endParts[1]));
      final breakStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 
          int.parse(breakStartParts[0]), int.parse(breakStartParts[1]));
      final breakEnd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 
          int.parse(breakEndParts[0]), int.parse(breakEndParts[1]));

      final List<String> generated = [];
      final now = DateTime.now();
      final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(now);

      while (current.add(Duration(minutes: duration)).isBefore(end) || 
             current.add(Duration(minutes: duration)).isAtSameMomentAs(end)) {
        final currentEnd = current.add(Duration(minutes: duration));
        
        final overlapsBreak = (current.isBefore(breakEnd) && currentEnd.isAfter(breakStart));
        
        if (!overlapsBreak) {
          final slotString = DateFormat('hh:mm a').format(current);
          
          bool isFuture = true;
          if (isToday) {
            if (current.isBefore(now)) {
              isFuture = false;
            }
          }
          
          if (isFuture && !booked.contains(slotString)) {
            generated.add(slotString);
          }
        }
        
        current = current.add(Duration(minutes: duration + buffer));
      }

      setState(() {
        _dynamicSlots = generated;
        if (generated.isEmpty) {
          _slotsErrorMessage = "All slots are fully booked for this date.";
        }
        _isSlotsLoading = false;
      });

    } catch (e) {
      setState(() {
        _slotsErrorMessage = "Error loading slots. Please try again.";
        _isSlotsLoading = false;
      });
    }
  }

  Future<void> _bookAppointment() async {
    if (!_formKey.currentState!.validate() || _selectedDoctorId == null || _selectedSlot == null || _isBooking) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Provider.of<ThemeNotifier>(context, listen: false).isDarkMode;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    setState(() {
      _isBooking = true;
    });

    try {
      // Check if user already booked this doctor on this day
      final existingQuery = await FirebaseFirestore.instance
          .collection('appointments')
          .where('patient_id', isEqualTo: authProvider.user?.uid)
          .where('doctor_id', isEqualTo: _selectedDoctorId)
          .where('date', isEqualTo: dateStr)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _isBooking = false;
          });
          showGlassAlertDialog(
            context: context,
            isDarkMode: isDark,
            title: 'Request Exists',
            message: 'You already have an appointment request with this doctor for this date.',
          );
        }
        return;
      }

      final selectedDoc = _doctors.firstWhere((d) => d['uid'] == _selectedDoctorId);

      final bookingData = {
        'patient_id': authProvider.user?.uid,
        'patient_name': authProvider.user?.name ?? 'Patient',
        'doctor_id': _selectedDoctorId,
        'doctor_name': selectedDoc['name'] ?? 'Doctor',
        'date': dateStr,
        'time_slot': _selectedSlot,
        'symptoms': _symptomsController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _bookingService.bookAppointment(bookingData);
      if (mounted) {
        final isDark = Provider.of<ThemeNotifier>(context, listen: false).isDarkMode;
        showGlassSuccessDialog(
          context: context,
          isDarkMode: isDark,
          title: 'Booking Confirmed',
          message: 'Appointment booked successfully!\nPlease wait for approval from the doctor.',
          details: [
            {'label': 'Doctor', 'value': selectedDoc['name'] ?? 'Doctor'},
            {'label': 'Date', 'value': DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)},
            {'label': 'Time Slot', 'value': _selectedSlot ?? ''},
          ],
          onDone: () {
            if (mounted) {
              Navigator.pop(context);
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking Failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        title: Text('Book Appointment', style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getBackgroundGradient(isDark),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                bottom: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Doctor', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    _doctors.isEmpty 
                      ? Text('No verified doctors found.', style: GoogleFonts.outfit(color: textColor))
                      : SizedBox(
                          height: 140,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _doctors.length,
                            itemBuilder: (context, index) {
                              final doc = _doctors[index];
                              final isSelected = _selectedDoctorId == doc['uid'];
                              final String fee = doc['consultationFee']?.toString() ?? '500';
                              final String qual = doc['qualification'] ?? 'MBBS';
                              
                              final rawOnline = doc['onlineStatus'];
                              final bool isOnline = rawOnline == true || rawOnline == null || rawOnline.toString().toLowerCase() == 'online';

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedDoctorId = doc['uid'];
                                  });
                                  _updateAvailableSlots();
                                },
                                  child: GlassContainer(
                                    width: 130,
                                    margin: const EdgeInsets.only(right: 12),
                                    isDarkMode: isDark,
                                    borderRadius: 16,
                                    border: isSelected 
                                        ? Border.all(color: AppTheme.primaryColor, width: 2) 
                                        : Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                                    baseColor: isSelected
                                        ? AppTheme.primaryColor.withOpacity(isDark ? 0.15 : 0.08)
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: isSelected
                                                ? AppTheme.primaryColor
                                                : (isDark ? Colors.white.withOpacity(0.12) : Colors.grey[200]),
                                            backgroundImage: doc['profileImageUrl'] != null && doc['profileImageUrl'].toString().isNotEmpty
                                                ? NetworkImage(doc['profileImageUrl'])
                                                : null,
                                            child: doc['profileImageUrl'] != null && doc['profileImageUrl'].toString().isNotEmpty
                                                ? null
                                                : Icon(
                                                    Icons.person,
                                                    size: 24,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : (isDark ? Colors.white70 : Colors.black54),
                                                  ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            doc['name'],
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: isDark ? Colors.white : Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$qual • ₹$fee',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isOnline ? Colors.greenAccent[400] : Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isOnline ? 'Online' : 'Offline',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isOnline 
                                                      ? (isDark ? Colors.greenAccent[200] : Colors.green[800])
                                                      : (isDark ? Colors.white38 : Colors.grey[600]),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                          },
                          ),
                        ),
                    const SizedBox(height: 28),
                    
                    Text('Select Date', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    GlassContainer(
                      isDarkMode: isDark,
                      borderRadius: 16,
                      child: ListTile(
                        title: Text(DateFormat('EEEE, MMM d, yyyy').format(_selectedDate), style: GoogleFonts.outfit(color: textColor)),
                        trailing: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                          _updateAvailableSlots();
                        }
                      },
                    ),
                    ),
                    const SizedBox(height: 28),

                    Text('Select Time Slot', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    
                    if (_selectedDoctorId == null)
                      Text('Please select a doctor to load available slots.', style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14))
                    else if (_isSlotsLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_slotsErrorMessage != null)
                      Text(
                        _slotsErrorMessage!,
                        style: GoogleFonts.outfit(color: Colors.red[800], fontSize: 14, fontWeight: FontWeight.w500),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _dynamicSlots.map((slot) {
                          final isSelected = _selectedSlot == slot;
                          return ChoiceChip(
                            label: Text(slot),
                            selected: isSelected,
                            onSelected: (selected) => setState(() => _selectedSlot = selected ? slot : null),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 28),

                    Text('Symptoms / Reason for Visit', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _symptomsController,
                      style: GoogleFonts.outfit(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Enter symptoms (e.g. Fever, Headache, Cold...)',
                        hintStyle: GoogleFonts.outfit(color: isDark ? Colors.white54 : Colors.grey[500]),
                        prefixIcon: Icon(Icons.health_and_safety_outlined, color: AppTheme.primaryColor),
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      maxLines: 2,
                      validator: (v) => v!.isEmpty ? 'Please specify symptoms for the consultation' : null,
                    ),
                    const SizedBox(height: 36),
                    
                    ElevatedButton(
                      onPressed: (_selectedDoctorId != null && _selectedSlot != null && !_isBooking) ? _bookAppointment : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isBooking
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text('Confirm Booking', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ),
    );
  }
}
