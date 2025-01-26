import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/house.dart';
import '../models/event.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Ev oluşturma
  Future<String> createHouse(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturum açmamış');

    final String inviteCode = _uuid.v4().substring(0, 6).toUpperCase();
    
    final house = House(
      id: _uuid.v4(),
      name: name,
      ownerId: user.uid,
      inviteCode: inviteCode,
      memberIds: [user.uid],
    );

    await _firestore.collection('houses').doc(house.id).set({
      'id': house.id,
      'name': house.name,
      'ownerId': house.ownerId,
      'inviteCode': house.inviteCode,
      'memberIds': house.memberIds,
    });

    return inviteCode;
  }

  // Eve katılma
  Future<void> joinHouse(String inviteCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturum açmamış');

    final querySnapshot = await _firestore
        .collection('houses')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Geçersiz davet kodu');
    }

    final houseDoc = querySnapshot.docs.first;
    final List<dynamic> memberIds = houseDoc.get('memberIds');

    if (memberIds.contains(user.uid)) {
      throw Exception('Zaten bu eve üyesiniz');
    }

    memberIds.add(user.uid);
    await houseDoc.reference.update({'memberIds': memberIds});
  }

  // Etkinlik oluşturma
  Future<String> createEvent(String title, String description, DateTime date, String houseId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturum açmamış');

    final String inviteCode = _uuid.v4().substring(0, 6).toUpperCase();
    
    final event = Event(
      id: _uuid.v4(),
      title: title,
      description: description,
      houseId: houseId,
      creatorId: user.uid,
      inviteCode: inviteCode,
      date: date,
      participantIds: [user.uid],
    );

    await _firestore.collection('events').doc(event.id).set({
      'id': event.id,
      'title': event.title,
      'description': event.description,
      'houseId': event.houseId,
      'creatorId': event.creatorId,
      'inviteCode': event.inviteCode,
      'date': event.date.toIso8601String(),
      'participantIds': event.participantIds,
    });

    return inviteCode;
  }

  // Etkinliğe katılma
  Future<void> joinEvent(String inviteCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturum açmamış');

    final querySnapshot = await _firestore
        .collection('events')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Geçersiz etkinlik kodu');
    }

    final eventDoc = querySnapshot.docs.first;
    final List<dynamic> participantIds = eventDoc.get('participantIds');

    if (participantIds.contains(user.uid)) {
      throw Exception('Zaten bu etkinliğe katıldınız');
    }

    participantIds.add(user.uid);
    await eventDoc.reference.update({'participantIds': participantIds});
  }
} 