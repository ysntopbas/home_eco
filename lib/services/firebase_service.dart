import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/house.dart';
import '../models/event.dart';
import '../models/house_member.dart';
import 'device_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Ev oluşturma
  Future<String> createHouse(String name) async {
    final userId = await DeviceService.getUserId();
    final String inviteCode = _uuid.v4().substring(0, 6).toUpperCase();
    
    final house = House(
      id: _uuid.v4(),
      name: name,
      ownerId: userId,
      inviteCode: inviteCode,
      memberIds: [userId],
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
  Future<void> joinHouse(String inviteCode, String memberName) async {
    final userId = await DeviceService.getUserId();

    final querySnapshot = await _firestore
        .collection('houses')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Geçersiz davet kodu');
    }

    final houseDoc = querySnapshot.docs.first;
    final List<dynamic> memberIds = houseDoc.get('memberIds');

    if (memberIds.contains(userId)) {
      throw Exception('Zaten bu eve üyesiniz');
    }

    // Üye bilgilerini kaydet
    await _firestore.collection('users').doc(userId).set({
      'id': userId,
      'name': memberName,
    });

    memberIds.add(userId);
    await houseDoc.reference.update({'memberIds': memberIds});
  }

  // Etkinlik oluşturma
  Future<String> createEvent(String title, String description, DateTime date, String houseId) async {
    final userId = await DeviceService.getUserId();
    final String inviteCode = _uuid.v4().substring(0, 6).toUpperCase();
    
    final event = Event(
      id: _uuid.v4(),
      title: title,
      description: description,
      houseId: houseId,
      creatorId: userId,
      inviteCode: inviteCode,
      date: date,
      participantIds: [userId],
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
    final userId = await DeviceService.getUserId();

    final querySnapshot = await _firestore
        .collection('events')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Geçersiz etkinlik kodu');
    }

    final eventDoc = querySnapshot.docs.first;
    final List<dynamic> participantIds = eventDoc.get('participantIds');

    if (participantIds.contains(userId)) {
      throw Exception('Zaten bu etkinliğe katıldınız');
    }

    participantIds.add(userId);
    await eventDoc.reference.update({'participantIds': participantIds});
  }

  // Kullanıcının evlerini getir
  Future<List<House>> getUserHouses() async {
    final userId = await DeviceService.getUserId();
    
    final querySnapshot = await _firestore
        .collection('houses')
        .where('memberIds', arrayContains: userId)
        .get();

    return querySnapshot.docs.map((doc) => House(
      id: doc['id'],
      name: doc['name'],
      ownerId: doc['ownerId'],
      inviteCode: doc['inviteCode'],
      memberIds: List<String>.from(doc['memberIds']),
    )).toList();
  }

  // Ev silme
  Future<void> deleteHouse(String houseId) async {
    try {
      await _firestore.collection('houses').doc(houseId).delete();
      
      // İlgili eve ait etkinlikleri de silme
      final eventsSnapshot = await _firestore
          .collection('events')
          .where('houseId', isEqualTo: houseId)
          .get();
      
      for (var doc in eventsSnapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Ev silinirken bir hata oluştu: $e');
    }
  }

  Future<List<HouseMember>> getHouseMembers(String houseId) async {
    final house = await _firestore.collection('houses').doc(houseId).get();
    if (!house.exists) {
      throw Exception('Ev bulunamadı');
    }

    final List<dynamic> memberIds = house.get('memberIds') as List<dynamic>;
    
    final members = await Future.wait(
      memberIds.map((memberId) async {
        final userDoc = await _firestore.collection('users').doc(memberId).get();
        if (!userDoc.exists) {
          return HouseMember(
            id: memberId,
            name: 'Bilinmeyen Üye',
          );
        }
        return HouseMember(
          id: memberId as String,
          name: userDoc.get('name') as String,
        );
      }),
    );

    return members;
  }
}