import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/services/booking_service.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  List<dynamic> _appointments = [];
  bool _isLoading = true;
  final BookingService _bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user == null || user.status != 'Verified') {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final appointments = await _bookingService.getUserAppointments(user.uid);
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user?.status != 'Verified') {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Pending')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                Text(
                  'Your account is pending verification.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'An admin will review your medical credentials soon. Once verified, you will have full access.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(onPressed: () => authProvider.signOut(), child: const Text('Logout')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => authProvider.signOut()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Your Appointments', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: _appointments.isEmpty
                      ? const Center(child: Text('No appointments scheduled.'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _appointments.length,
                          itemBuilder: (context, index) {
                            final appt = _appointments[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text('Patient ID: ${appt['patient_id']}'),
                                subtitle: Text('Date: ${appt['date']} at ${appt['time_slot']}'),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
