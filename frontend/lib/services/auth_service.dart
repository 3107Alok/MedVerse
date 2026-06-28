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
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await user.updateDisplayName(name);
        await user.sendEmailVerification();
        await _auth.signOut(); // Sign out immediately

        final uid = user.uid;
        final userData = {
          'uid': uid,
          'email': email,
          'name': name,
          'role': null,
          'profileCompleted': false,
        };

        return UserModel.fromJson(userData);
      }
      return null;
    } catch (e) {
      rethrow;
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
        await user.reload(); // Get latest verification status
        final freshUser = _auth.currentUser;
        if (freshUser != null && !freshUser.emailVerified) {
          throw FirebaseAuthException(
            code: 'email-not-verified',
            message: 'Email verification is required.',
          );
        }

        final doc = await _db.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          data['uid'] = user.uid;
          return UserModel.fromJson(data);
        } else {
          // Create user document if it does not exist yet (first sign in after verification)
          final userData = {
            'uid': user.uid,
            'email': email,
            'name': user.displayName ?? '',
            'role': null,
            'profileCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          };
          await _db.collection('users').doc(user.uid).set(userData);
          return UserModel.fromJson(userData);
        }
      }
      return null;
    } catch (e) {
      rethrow;
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
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          data['uid'] = user.uid;
          return UserModel.fromJson(data);
        } else {
          final userData = {
            'uid': user.uid,
            'email': user.email ?? '',
            'name': user.displayName ?? 'New User',
            'role': null,
            'profileCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          };
          await _db.collection('users').doc(user.uid).set(userData);
          return UserModel.fromJson(userData);
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception("An account already exists with this email. Please sign in using your password.");
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}

