import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/house.dart';
import '../models/event.dart';
import '../models/house_member.dart';
import 'device_service.dart';
import 'dart:math';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Ev oluşturma
  Future<String> createHouse(String name, String ownerName) async {
    final userId = await DeviceService.getUserId();
    final String inviteCode = _uuid.v4().substring(0, 6).toUpperCase();

    // Önce kullanıcı bilgilerini kaydet
    await _firestore.collection('users').doc(userId).set({
      'id': userId,
      'name': ownerName,
    });

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

  // Event işlemleri için yeni metodlar
  Future<String> createEvent({
    required String title,
    required String description,
    required String ownerName,
    required DateTime date,
  }) async {
    try {
      final String userId = await DeviceService.getUserId();
      final String inviteCode = _generateInviteCode();

      final eventRef = _firestore.collection('events').doc();

      final event = Event(
        id: eventRef.id,
        title: title,
        description: description,
        creatorId: userId,
        creatorName: ownerName,
        inviteCode: inviteCode,
        date: date,
        participantIds: [userId],
      );

      await eventRef.set(event.toMap());
      return inviteCode;
    } catch (e) {
      throw 'Etkinlik oluşturulamadı: $e';
    }
  }

  String _generateInviteCode() {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  // Etkinliğe katılma
  Future<void> joinEvent(String inviteCode) async {
    final String userId = await DeviceService.getUserId();

    final querySnapshot = await _firestore
        .collection('events')
        .where('inviteCode', isEqualTo: inviteCode)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw 'Geçersiz etkinlik kodu';
    }

    final eventDoc = querySnapshot.docs.first;
    final event = Event.fromMap(eventDoc.data());

    if (event.participantIds.contains(userId)) {
      throw 'Zaten bu etkinliğe katıldınız';
    }

    await eventDoc.reference.update({
      'participantIds': [...event.participantIds, userId]
    });
  }

  // Kullanıcının evlerini getir
  Future<List<House>> getUserHouses() async {
    final userId = await DeviceService.getUserId();

    final querySnapshot = await _firestore
        .collection('houses')
        .where('memberIds', arrayContains: userId)
        .get();

    return querySnapshot.docs
        .map((doc) => House(
              id: doc['id'],
              name: doc['name'],
              ownerId: doc['ownerId'],
              inviteCode: doc['inviteCode'],
              memberIds: List<String>.from(doc['memberIds']),
            ))
        .toList();
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
        final userDoc =
            await _firestore.collection('users').doc(memberId).get();
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

  // Kullanıcının etkinliklerini getir
  Future<List<Event>> getUserEvents() async {
    final String userId = await DeviceService.getUserId();

    final querySnapshot = await _firestore
        .collection('events')
        .where('participantIds', arrayContains: userId)
        .get();

    return querySnapshot.docs.map((doc) => Event.fromMap(doc.data())).toList();
  }

  // Etkinlik silme (sadece oluşturan kişi silebilir)
  Future<void> deleteEvent(String eventId) async {
    try {
      final String userId = await DeviceService.getUserId();

      final eventDoc = await _firestore.collection('events').doc(eventId).get();

      if (!eventDoc.exists) {
        throw 'Etkinlik bulunamadı';
      }

      if (eventDoc.get('creatorId') != userId) {
        throw 'Bu etkinliği silme yetkiniz yok';
      }

      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      throw 'Etkinlik silinemedi: $e';
    }
  }

  // Etkinlik katılımcılarını getir
  Future<List<HouseMember>> getEventParticipants(String eventId) async {
    final eventDoc = await _firestore.collection('events').doc(eventId).get();

    if (!eventDoc.exists) {
      throw Exception('Etkinlik bulunamadı');
    }

    final List<dynamic> participantIds = eventDoc.get('participantIds');

    final participants = await Future.wait(
      participantIds.map((participantId) async {
        final userDoc =
            await _firestore.collection('users').doc(participantId).get();
        if (!userDoc.exists) {
          return HouseMember(
            id: participantId,
            name: 'Bilinmeyen Katılımcı',
          );
        }
        return HouseMember(
          id: participantId as String,
          name: userDoc.get('name') as String,
        );
      }),
    );

    return participants;
  }
}
