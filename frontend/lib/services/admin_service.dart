import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<dynamic>> getPendingDoctors() async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> verifyDoctor(String uid, String status) async {
    await _db.collection('users').doc(uid).update({'status': status});
  }

  Future<Map<String, int>> getDashboardStats() async {
    final patients = await _db
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .get();
    
    final doctors = await _db
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('status', isEqualTo: 'Verified')
        .get();

    return {
      'patients': patients.docs.length,
      'doctors': doctors.docs.length,
    };
  }
}
