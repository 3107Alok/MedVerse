import 'package:cloud_firestore/cloud_firestore.dart';

class BookingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<dynamic>> getVerifiedDoctors() async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .where('status', isEqualTo: 'verified')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> bookAppointment(Map<String, dynamic> bookingData) async {
    await _db.collection('appointments').add(bookingData);
  }

  Future<List<dynamic>> getUserAppointments(String uid) async {
    final snapshot = await _db
        .collection('appointments')
        .where('patient_id', isEqualTo: uid)
        .get();
    
    // Also include appointments where this user is the doctor
    final doctorSnapshot = await _db
        .collection('appointments')
        .where('doctor_id', isEqualTo: uid)
        .get();

    final all = [...snapshot.docs, ...doctorSnapshot.docs];
    return all.map((doc) => doc.data()).toList();
  }
}
