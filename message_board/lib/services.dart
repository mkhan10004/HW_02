import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._auth) : changes = _auth.authStateChanges();

  final FirebaseAuth _auth;
  final Stream<User?> changes;
  User? get currentUser => _auth.currentUser;

  Future<void> register(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();
}

class Profile {
  const Profile(this.uid, this.firstName, this.lastName);

  final String uid;
  final String firstName;
  final String lastName;
  String get name => '$firstName $lastName';
}

class Message {
  Message(QueryDocumentSnapshot<Map<String, dynamic>> document)
    : id = document.id,
      text = document.data()['text'] as String,
      authorUid = document.data()['authorUid'] as String,
      authorName = document.data()['authorName'] as String,
      createdAt = (document.data()['createdAt'] as Timestamp?)?.toDate(),
      edited = document.data()['editedAt'] != null,
      pending = document.metadata.hasPendingWrites;

  final String id, text, authorUid, authorName;
  final DateTime? createdAt;
  final bool edited, pending;
}

class BoardData {
  const BoardData(this.messages, this.fromCache);
  final List<Message> messages;
  final bool fromCache;
}

class BoardService {
  BoardService(this._db);

  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');

  Future<Profile?> loadProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    final data = doc.data();
    if (data == null) {
      if (doc.metadata.isFromCache) {
        throw StateError('Connect to the internet to check your profile.');
      }
      return null;
    }
    return Profile(
      uid,
      data['firstName'] as String,
      data['lastName'] as String,
    );
  }

  Future<void> saveProfile(Profile profile) async {
    final ref = _users.doc(profile.uid);
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) return;
      transaction.set(ref, {
        'uid': profile.uid,
        'firstName': profile.firstName,
        'lastName': profile.lastName,
        'role': 'member',
        'registrationDateTime': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<BoardData> watchBoard() => _messages
      .orderBy('createdAt')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => BoardData(
          snapshot.docs.map(Message.new).toList(growable: false),
          snapshot.metadata.isFromCache,
        ),
      );

  String newPostId() => _messages.doc().id;

  Future<void> create(String id, Profile author, String text) async {
    final ref = _messages.doc(id);
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        if (existing.data()?['authorUid'] != author.uid) {
          throw StateError('This post ID belongs to a different account.');
        }
        return;
      }
      transaction.set(ref, {
        'text': text,
        'authorUid': author.uid,
        'authorName': author.name,
        'createdAt': FieldValue.serverTimestamp(),
        'editedAt': null,
      });
    });
  }

  Future<void> update(String id, String text) => _messages.doc(id).update({
    'text': text,
    'editedAt': FieldValue.serverTimestamp(),
  });

  Future<void> delete(String id) => _messages.doc(id).delete();

  // Force a server read so the rules check cannot be satisfied by local cache.
  Future<void> checkSignedOutRead() async {
    await _messages.limit(1).get(const GetOptions(source: Source.server));
  }

  // Use a transaction so an unexpected allow cannot leave a queued test write
  // on a disconnected device. Only run on a disposable test post.
  Future<void> checkOwnership(Message target, {required bool delete}) async {
    final ref = _messages.doc(target.id);
    await _db.runTransaction((transaction) async {
      if (!(await transaction.get(ref)).exists) {
        throw StateError('The test post no longer exists.');
      }
      if (delete) {
        transaction.delete(ref);
      } else {
        transaction.update(ref, {
          'text': target.text,
          'editedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}

String friendlyError(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FirebaseException) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email or password is incorrect.',
      'email-already-in-use' => 'That email already has an account. Sign in.',
      'weak-password' => 'Choose a stronger password.',
      'operation-not-allowed' =>
        'Enable Email/Password in Firebase Authentication.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' ||
      'unavailable' ||
      'deadline-exceeded' => 'Connect to the internet and try again.',
      'permission-denied' =>
        'Firestore denied this action. Check your account and the deployed rules.',
      _ => 'The request failed (${error.code}). Try again.',
    };
  }
  return 'Something went wrong. Try again.';
}
