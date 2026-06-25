import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/services/admin_service.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  List<dynamic> _pendingDoctors = [];
  Map<String, int> _stats = {'patients': 0, 'doctors': 0};
  bool _isLoading = true;
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final doctors = await _adminService.getPendingDoctors();
      final stats = await _adminService.getDashboardStats();
      setState(() {
        _pendingDoctors = doctors;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyDoctor(String uid, String status) async {
    try {
      await _adminService.verifyDoctor(uid, status);
      _fetchData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Doctor $status')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action Failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Dashboard Overview', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildStatCard('Active Patients', _stats['patients'].toString(), Colors.blue),
                      _buildStatCard('Verified Doctors', _stats['doctors'].toString(), Colors.green),
                    ],
                  ),
                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Pending Verifications', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  _pendingDoctors.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: Text('No pending requests.')),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: _pendingDoctors.length,
                          itemBuilder: (context, index) {
                            final doc = _pendingDoctors[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(doc['name'], style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('Email: ${doc['email']}'),
                                    Text('License: ${doc['license']}'),
                                    Text('Spec: ${doc['specialization']}'),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => _verifyDoctor(doc['uid'], 'Rejected'),
                                          child: const Text('Reject', style: TextStyle(color: Colors.red)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () => _verifyDoctor(doc['uid'], 'Verified'),
                                          child: const Text('Approve'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(count, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700])),
          ],
      ),
    );
  }
}
