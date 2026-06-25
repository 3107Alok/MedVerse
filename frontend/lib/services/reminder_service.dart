import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> saveReminder(Map<String, dynamic> reminderData) async {
    await _db.collection('reminders').add(reminderData);
  }

  Future<List<dynamic>> getUserReminders(String uid) async {
    final snapshot = await _db
        .collection('reminders')
        .where('uid', isEqualTo: uid)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}
