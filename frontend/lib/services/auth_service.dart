import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:frontend/models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get user => _auth.authStateChanges();

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        final uid = user.uid;
        final userData = {
          'uid': uid,
          'email': email,
          'name': name,
          'role': role.toString().split('.').last,
          'status': role == UserRole.doctor ? 'pending' : 'active',
          ...?extraData,
        };

        await _db.collection("users").doc(uid).set(userData);

        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      // SignUp error handled by provider
      return null;
    }
  }

  Future<UserModel?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return UserModel.fromJson(doc.data()!);
        }
      }
      return null;
    } catch (e) {
      // SignIn error handled by provider
      return null;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return UserModel.fromJson(doc.data()!);
        } else {
          // New Google User - default to patient
          final userData = {
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName ?? 'New User',
            'role': 'patient',
            'status': 'active',
          };
          await _db.collection('users').doc(user.uid).set(userData);
          return UserModel.fromJson(userData);
        }
      }
      return null;
    } catch (e) {
        // Google Sign-In error handled by provider
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

