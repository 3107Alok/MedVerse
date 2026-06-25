import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/services/booking_service.dart';

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key});

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  List<dynamic> _doctors = [];
  bool _isLoading = true;
  String? _selectedDoctorId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;
  final BookingService _bookingService = BookingService();

  final List<String> _slots = [
    '09:00 AM', '10:00 AM', '11:00 AM', '02:00 PM', '03:00 PM', '04:00 PM'
  ];

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      final doctors = await _bookingService.getVerifiedDoctors();
      setState(() {
        _doctors = doctors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _bookAppointment() async {
    if (_selectedDoctorId == null || _selectedSlot == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookingData = {
      'patient_id': authProvider.user?.uid,
      'doctor_id': _selectedDoctorId,
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'time_slot': _selectedSlot,
    };

    try {
      await _bookingService.bookAppointment(bookingData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment Booked Successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking Failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Doctor', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _doctors.isEmpty 
                    ? const Text('No verified doctors found.')
                    : SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _doctors.length,
                          itemBuilder: (context, index) {
                            final doc = _doctors[index];
                            final isSelected = _selectedDoctorId == doc['uid'];
                            return GestureDetector(
                              onTap: () => setState(() => _selectedDoctorId = doc['uid']),
                              child: Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[300]!),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircleAvatar(child: Icon(Icons.person)),
                                    const SizedBox(height: 8),
                                    Text(
                                      doc['name'],
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: isSelected ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  const SizedBox(height: 32),
                  Text('Select Date', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                  ),
                  const SizedBox(height: 32),
                  Text('Select Time Slot', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _slots.map((slot) {
                      final isSelected = _selectedSlot == slot;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: isSelected,
                        onSelected: (selected) => setState(() => _selectedSlot = selected ? slot : null),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: (_selectedDoctorId != null && _selectedSlot != null) ? _bookAppointment : null,
                    child: const Text('Confirm Booking'),
                  ),
                ],
              ),
            ),
    );
  }
}
