import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/house.dart';
import '../models/event.dart';
import 'device_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Ev oluşturma
  Future<String> createHouse(String name) async {
    final deviceId = await DeviceService.getDeviceId();
    final String inviteCode = _uuid.v4().substring(0, 6).toUpperCase();
    
    final house = House(
      id: _uuid.v4(),
      name: name,
      ownerId: deviceId,
      inviteCode: inviteCode,
      memberIds: [deviceId],
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
    final deviceId = await DeviceService.getDeviceId();

    final querySnapshot = await _firestore
        .collection('houses')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Geçersiz davet kodu');
    }

    final houseDoc = querySnapshot.docs.first;
    final List<dynamic> memberIds = houseDoc.get('memberIds');

    if (memberIds.contains(deviceId)) {
      throw Exception('Zaten bu eve üyesiniz');
    }

    memberIds.add(deviceId);
    await houseDoc.reference.update({'memberIds': memberIds});
  }

  // Etkinlik oluşturma
  Future<String> createEvent(String title, String description, DateTime date, String houseId) async {
    final deviceId = await DeviceService.getDeviceId();
    final String inviteCode = _uuid.v4().substring(0, 6).toUpperCase();
    
    final event = Event(
      id: _uuid.v4(),
      title: title,
      description: description,
      houseId: houseId,
      creatorId: deviceId,
      inviteCode: inviteCode,
      date: date,
      participantIds: [deviceId],
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
    final deviceId = await DeviceService.getDeviceId();

    final querySnapshot = await _firestore
        .collection('events')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Geçersiz etkinlik kodu');
    }

    final eventDoc = querySnapshot.docs.first;
    final List<dynamic> participantIds = eventDoc.get('participantIds');

    if (participantIds.contains(deviceId)) {
      throw Exception('Zaten bu etkinliğe katıldınız');
    }

    participantIds.add(deviceId);
    await eventDoc.reference.update({'participantIds': participantIds});
  }

  // Kullanıcının evlerini getir
  Future<List<House>> getUserHouses() async {
    final deviceId = await DeviceService.getDeviceId();
    
    final querySnapshot = await _firestore
        .collection('houses')
        .where('memberIds', arrayContains: deviceId)
        .get();

    return querySnapshot.docs.map((doc) => House(
      id: doc['id'],
      name: doc['name'],
      ownerId: doc['ownerId'],
      inviteCode: doc['inviteCode'],
      memberIds: List<String>.from(doc['memberIds']),
    )).toList();
  }

  Future<void> deleteHouse(String houseId) async {
    await _firestore.collection('houses').doc(houseId).delete();
  }
} 