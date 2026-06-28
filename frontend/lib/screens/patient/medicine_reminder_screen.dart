import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/services/reminder_service.dart';

import 'package:provider/provider.dart';
import 'package:frontend/services/auth_provider.dart';
import 'package:frontend/theme/theme_notifier.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/theme/glassmorphism.dart';
import 'package:frontend/widgets/shared_glass_components.dart';

class MedicineReminderScreen extends StatefulWidget {
  const MedicineReminderScreen({super.key});

  @override
  State<MedicineReminderScreen> createState() => _MedicineReminderScreenState();
}

class _MedicineReminderScreenState extends State<MedicineReminderScreen> {
  List<dynamic> _reminders = [];
  final TextEditingController _nameController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final ReminderService _reminderService = ReminderService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReminders();
  }

  Future<void> _fetchReminders() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    try {
      final reminders = await _reminderService.getUserReminders(user.uid);
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _addReminder() async {
    if (_nameController.text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final now = DateTime.now();
    final reminderTime = DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
    
    // If time is in the past, schedule for tomorrow
    final scheduledTime = reminderTime.isBefore(now) ? reminderTime.add(const Duration(days: 1)) : reminderTime;

    final reminderData = {
      "uid": user.uid,
      "medicine_name": _nameController.text,
      "time": _selectedTime.format(context),
    };

    try {
      await _reminderService.saveReminder(reminderData);
      
      NotificationService.scheduleNotification(
        _reminders.length + 1,
        'Medicine Reminder',
        'Time to take your ${_nameController.text}',
        scheduledTime,
      );

      _fetchReminders(); // Refresh list
      _nameController.clear();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save reminder')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeNotifier>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey[700];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
      appBar: AppBar(
        title: Text('Medicine Reminders', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getBackgroundGradient(isDark),
        ),
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _reminders.isEmpty
          ? Center(child: Text('No reminders set.', style: GoogleFonts.outfit(color: subtitleColor)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final r = _reminders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassContainer(
                    isDarkMode: isDark,
                    borderRadius: 16,
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: AppTheme.primaryColor, child: Icon(Icons.medication, color: Colors.white)),
                      title: Text(r['medicine_name'], style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColor)),
                      subtitle: Text('Scheduled for ${r['time']}', style: GoogleFonts.outfit(color: subtitleColor)),
                      trailing: const Icon(Icons.notifications_active, color: Colors.orange),
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add New Reminder', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Medicine Name', prefixIcon: Icon(Icons.medication)),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Reminder Time'),
              trailing: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                if (picked != null) setState(() => _selectedTime = picked);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _addReminder, child: const Text('Save Reminder')),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
