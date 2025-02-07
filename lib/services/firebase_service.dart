import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/house.dart';
import '../models/event.dart';
import '../models/house_member.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense.dart';
import '../models/payment_info.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  // Ev oluşturma
  Future<String> createHouse(String name) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      final String inviteCode = _uuid.v4().substring(0, 6).toUpperCase();
      final userName = await getUserName();

      final house = House(
        id: _uuid.v4(),
        name: name,
        ownerId: user.uid,
        inviteCode: inviteCode,
        memberIds: [user.uid],
      );

      // Kullanıcı bilgilerini güncelle/kaydet
      await _firestore.collection('users').doc(user.uid).set({
        'id': user.uid,
        'name': userName,
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('houses').doc(house.id).set({
        'id': house.id,
        'name': house.name,
        'ownerId': house.ownerId,
        'inviteCode': house.inviteCode,
        'memberIds': house.memberIds,
      });

      return inviteCode;
    } catch (e) {
      throw Exception('Ev oluşturulamadı: $e');
    }
  }

  // Eve katılma
  Future<void> joinHouse(String inviteCode) async {
    final userId = await getUserId();

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

    memberIds.add(userId);
    await houseDoc.reference.update({'memberIds': memberIds});
  }

  // Event işlemleri için yeni metodlar
  Future<String> createEvent({
    required String title,
    required String description,
    required DateTime date,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturum açmamış');
      }

      final String inviteCode = _generateInviteCode();
      final userName = await getUserName();

      final eventRef = _firestore.collection('events').doc();

      final event = Event(
        id: eventRef.id,
        title: title,
        description: description,
        creatorId: user.uid,
        creatorName: userName,
        inviteCode: inviteCode,
        date: date,
        participantIds: [user.uid],
      );

      await eventRef.set(event.toMap());

      // Kullanıcı bilgilerini güncelle/kaydet
      await _firestore.collection('users').doc(user.uid).set({
        'id': user.uid,
        'name': userName,
        'email': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
    final String userId = await getUserId();

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
    final userId = await getUserId();

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
      // Önce ev altındaki tüm harcamaları sil
      final expensesRef = _firestore
          .collection('houses')
          .doc(houseId)
          .collection('expenses');
      
      final expensesDocs = await expensesRef.get();
      for (var doc in expensesDocs.docs) {
        await doc.reference.delete();
      }

      // Sonra evin kendisini sil
      await _firestore.collection('houses').doc(houseId).delete();
    } catch (e) {
      throw 'Ev silinirken hata oluştu: $e';
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
    final String userId = await getUserId();

    final querySnapshot = await _firestore
        .collection('events')
        .where('participantIds', arrayContains: userId)
        .get();

    return querySnapshot.docs.map((doc) => Event.fromMap(doc.data())).toList();
  }

  // Etkinlik silme (sadece oluşturan kişi silebilir)
  Future<void> deleteEvent(String eventId) async {
    try {
      // Önce etkinlik altındaki tüm harcamaları sil
      final expensesRef = _firestore
          .collection('events')
          .doc(eventId)
          .collection('expenses');
      
      final expensesDocs = await expensesRef.get();
      for (var doc in expensesDocs.docs) {
        await doc.reference.delete();
      }

      // Sonra etkinliğin kendisini sil
      await _firestore.collection('events').doc(eventId).delete();
    } catch (e) {
      throw 'Etkinlik silinirken hata oluştu: $e';
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

  // Mevcut getUserId() metodunu değiştirin
  Future<String> getUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturum açmamış');
    }
    return user.uid;
  }

  // Kullanıcı adını almak için metod
  Future<String> getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Kullanıcı oturum açmamış');
    }
    
    // Önce displayName'i kontrol edelim
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }

    // Eğer displayName yoksa, Firestore'dan kontrol edelim
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('name')) {
        return userDoc.data()!['name'] as String;
      }
    } catch (e) {
      print('Firestore\'dan kullanıcı adı alınamadı: $e');
    }

    // Son çare olarak email adresinin @ öncesini kullanalım
    return user.email?.split('@')[0] ?? 'İsimsiz Kullanıcı';
  }

  Future<List<Expense>> getExpenses(String parentId, String type) async {
    try {
      final snapshot = await _firestore
          .collection(type == 'house' ? 'houses' : 'events')
          .doc(parentId)
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Expense.fromMap({
          ...data,
          'parentId': parentId,
        });
      }).toList();
    } catch (e) {
      print('Harcamalar yüklenirken hata: $e');
      return [];
    }
  }

  Future<void> addExpense({
    required String parentId,
    required String type,
    required String name,
    required int quantity,
    required double price,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Kullanıcı oturum açmamış');
      
      final userName = await getUserName();
      final expenseRef = _firestore
          .collection(type == 'house' ? 'houses' : 'events')
          .doc(parentId)
          .collection('expenses')
          .doc();

      // Üyeleri getir
      List<HouseMember> members = [];
      if (type == 'house') {
        members = await getHouseMembers(parentId);
      } else {
        members = await getEventParticipants(parentId);
      }

      // paidBy ve calculatedBy map'lerini oluştur
      Map<String, bool> paidBy = {};
      Map<String, bool> calculatedBy = {};
      for (var member in members) {
        paidBy[member.id] = member.id == user.uid;
        calculatedBy[member.id] = false; // Başlangıçta kimse hesaplamamış
      }

      await expenseRef.set({
        'id': expenseRef.id,
        'name': name,
        'quantity': quantity,
        'price': price,
        'creatorId': user.uid,
        'creatorName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'parentId': parentId,
        'type': type,
        'paidBy': paidBy,
        'calculatedBy': calculatedBy,
        'isCalculated': false,
      });
    } catch (e) {
      throw 'Harcama eklenirken hata oluştu: $e';
    }
  }

  Future<void> updatePaymentStatus(String expenseId, String userId, bool paid) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).update({
        'paidBy.$userId': paid,
      });
    } catch (e) {
      throw 'Ödeme durumu güncellenemedi: $e';
    }
  }

  Future<void> updateExpensePaidBy(String expenseId, Map<String, bool> paidBy) async {
    try {
      await _firestore.collection('expenses').doc(expenseId).update({
        'paidBy': paidBy,
      });
    } catch (e) {
      throw 'Ödeme durumları güncellenemedi: $e';
    }
  }

  Future<List<PaymentInfo>> getUserPayments() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Kullanıcı oturum açmamış');

      final houses = await getUserHouses();
      final events = await getUserEvents();
      Map<String, PaymentInfo> paymentMap = {};

      // Evlerdeki ödemeleri hesapla
      for (var house in houses) {
        final expenses = await getExpenses(house.id, 'house');
        final members = await getHouseMembers(house.id);
        
        Map<String, double> totalSpentByMember = {};
        double totalExpense = 0;

        for (var member in members) {
          totalSpentByMember[member.id] = 0;
        }

        for (var expense in expenses) {
          totalExpense += expense.totalPrice;
          totalSpentByMember[expense.creatorId] = 
              (totalSpentByMember[expense.creatorId] ?? 0) + expense.totalPrice;
        }

        double averagePerPerson = totalExpense / members.length;

        // Her üye için borç/alacak durumunu hesapla
        for (var member in members) {
          double balance = (totalSpentByMember[member.id] ?? 0) - averagePerPerson;
          
          if (member.id == user.uid) {
            if (balance < 0) {
              // Borçlu durumu - mevcut kod
              for (var creditor in members) {
                double creditorBalance = (totalSpentByMember[creditor.id] ?? 0) - averagePerPerson;
                if (creditorBalance > 0) {
                  double paymentAmount = (-balance * (creditorBalance / 
                      members.where((m) => 
                          (totalSpentByMember[m.id] ?? 0) - averagePerPerson > 0
                      ).fold(0.0, (sum, m) => 
                          sum + ((totalSpentByMember[m.id] ?? 0) - averagePerPerson))
                  )).abs();

                  if (paymentAmount > 0) {
                    String key = '${house.id}_${creditor.id}_debt';
                    paymentMap[key] = PaymentInfo(
                      expenseId: '',
                      userId: user.uid,
                      title: '${house.name} - ${creditor.name}\'e Borcunuz',
                      parentName: house.name,
                      parentId: house.id,
                      type: 'house',
                      amount: paymentAmount,
                      isPaid: false,
                      allPaid: false,
                      isDebt: true, // Yeni alan: borç mu alacak mı?
                    );
                  }
                }
              }
            } else if (balance > 0) {
              // Alacaklı durumu - yeni kod
              for (var debtor in members) {
                double debtorBalance = (totalSpentByMember[debtor.id] ?? 0) - averagePerPerson;
                if (debtorBalance < 0) {
                  double receivableAmount = (balance * (-debtorBalance / 
                      members.where((m) => 
                          (totalSpentByMember[m.id] ?? 0) - averagePerPerson < 0
                      ).fold(0.0, (sum, m) => 
                          sum + ((totalSpentByMember[m.id] ?? 0) - averagePerPerson).abs())
                  )).abs();

                  if (receivableAmount > 0) {
                    String key = '${house.id}_${debtor.id}_receivable';
                    paymentMap[key] = PaymentInfo(
                      expenseId: '',
                      userId: user.uid,
                      title: '${house.name} - ${debtor.name}\'den Alacağınız',
                      parentName: house.name,
                      parentId: house.id,
                      type: 'house',
                      amount: receivableAmount,
                      isPaid: false,
                      allPaid: false,
                      isDebt: false,
                    );
                  }
                }
              }
            }
          }
        }
      }

      // Etkinlikler için de aynı mantığı uygula
      for (var event in events) {
        final expenses = await getExpenses(event.id, 'event');
        final participants = await getEventParticipants(event.id);
        
        Map<String, double> totalSpentByMember = {};
        double totalExpense = 0;

        for (var member in participants) {
          totalSpentByMember[member.id] = 0;
        }

        for (var expense in expenses) {
          totalExpense += expense.totalPrice;
          totalSpentByMember[expense.creatorId] = 
              (totalSpentByMember[expense.creatorId] ?? 0) + expense.totalPrice;
        }

        double averagePerPerson = totalExpense / participants.length;

        // Her üye için borç/alacak durumunu hesapla
        for (var member in participants) {
          double balance = (totalSpentByMember[member.id] ?? 0) - averagePerPerson;
          
          if (member.id == user.uid) {
            if (balance < 0) {
              // Borçlu durumu - mevcut kod
              for (var creditor in participants) {
                double creditorBalance = (totalSpentByMember[creditor.id] ?? 0) - averagePerPerson;
                if (creditorBalance > 0) {
                  double paymentAmount = (-balance * (creditorBalance / 
                      participants.where((m) => 
                          (totalSpentByMember[m.id] ?? 0) - averagePerPerson > 0
                      ).fold(0.0, (sum, m) => 
                          sum + ((totalSpentByMember[m.id] ?? 0) - averagePerPerson))
                  )).abs();

                  if (paymentAmount > 0) {
                    String key = '${event.id}_${creditor.id}_debt';
                    paymentMap[key] = PaymentInfo(
                      expenseId: '',
                      userId: user.uid,
                      title: '${event.title} - ${creditor.name}\'e Borcunuz',
                      parentName: event.title,
                      parentId: event.id,
                      type: 'event',
                      amount: paymentAmount,
                      isPaid: false,
                      allPaid: false,
                      isDebt: true, // Yeni alan: borç mu alacak mı?
                    );
                  }
                }
              }
            } else if (balance > 0) {
              // Alacaklı durumu - yeni kod
              for (var debtor in participants) {
                double debtorBalance = (totalSpentByMember[debtor.id] ?? 0) - averagePerPerson;
                if (debtorBalance < 0) {
                  double receivableAmount = (balance * (-debtorBalance / 
                      participants.where((m) => 
                          (totalSpentByMember[m.id] ?? 0) - averagePerPerson < 0
                      ).fold(0.0, (sum, m) => 
                          sum + ((totalSpentByMember[m.id] ?? 0) - averagePerPerson).abs())
                  )).abs();

                  if (receivableAmount > 0) {
                    String key = '${event.id}_${debtor.id}_receivable';
                    paymentMap[key] = PaymentInfo(
                      expenseId: '',
                      userId: user.uid,
                      title: '${event.title} - ${debtor.name}\'den Alacağınız',
                      parentName: event.title,
                      parentId: event.id,
                      type: 'event',
                      amount: receivableAmount,
                      isPaid: false,
                      allPaid: false,
                      isDebt: false,
                    );
                  }
                }
              }
            }
          }
        }
      }

      return paymentMap.values.toList();
    } catch (e) {
      print('Ödemeler yüklenirken hata: $e');
      return [];
    }
  }

  Future<void> confirmPayment(
    String parentId,
    String type,
    String debtorId,
    String creditorId,
  ) async {
    try {
      final expensesSnapshot = await _firestore
          .collection(type == 'house' ? 'houses' : 'events')
          .doc(parentId)
          .collection('expenses')
          .where('creatorId', isEqualTo: creditorId)
          .get();

      if (expensesSnapshot.docs.isEmpty) {
        throw 'Harcama bulunamadı';
      }

      final batch = _firestore.batch();
      
      for (var doc in expensesSnapshot.docs) {
        Map<String, dynamic> currentPaidBy = Map<String, dynamic>.from(doc.data()['paidBy'] ?? {});
        currentPaidBy[debtorId] = true;
        
        batch.update(doc.reference, {
          'paidBy': currentPaidBy,
        });
      }

      await batch.commit();
    } catch (e) {
      throw 'Ödeme kaydedilemedi: $e';
    }
  }

  // Ödeme durumunu kontrol eden yeni bir metot ekleyelim
  Future<bool> checkPaymentStatus(
    String parentId,
    String type,
    String debtorId,
    String creditorId,
  ) async {
    try {
      final expensesSnapshot = await _firestore
          .collection(type == 'house' ? 'houses' : 'events')
          .doc(parentId)
          .collection('expenses')
          .where('creatorId', isEqualTo: creditorId)
          .get();

      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        Map<String, dynamic> paidBy = Map<String, dynamic>.from(data['paidBy'] ?? {});
        
        if (paidBy[debtorId] != true) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      print('Ödeme durumu kontrol edilemedi: $e');
      return false;
    }
  }

  // Hesaplama durumunu güncelle
  Future<void> updateCalculationStatus(String parentId, String type) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Kullanıcı oturum açmamış');

      final expenses = await getExpenses(parentId, type);
      final members = type == 'house' 
          ? await getHouseMembers(parentId)
          : await getEventParticipants(parentId);

      final batch = _firestore.batch();

      for (var expense in expenses) {
        if (!expense.isCalculated) {
          Map<String, bool> calculatedBy = Map<String, bool>.from(expense.calculatedBy);
          calculatedBy[user.uid] = true;

          // Tüm üyeler hesaplamış mı kontrol et
          bool allCalculated = true;
          for (var member in members) {
            if (calculatedBy[member.id] != true) {
              allCalculated = false;
              break;
            }
          }

          final expenseRef = _firestore
              .collection(type == 'house' ? 'houses' : 'events')
              .doc(parentId)
              .collection('expenses')
              .doc(expense.id);

          batch.update(expenseRef, {
            'calculatedBy': calculatedBy,
            'isCalculated': allCalculated,
          });
        }
      }

      await batch.commit();
    } catch (e) {
      throw 'Hesaplama durumu güncellenirken hata oluştu: $e';
    }
  }

  // Tüm harcamaların hesaplanıp hesaplanmadığını kontrol et
  Future<bool> checkAllExpensesCalculated(String parentId, String type) async {
    try {
      final expenses = await getExpenses(parentId, type);
      return expenses.every((expense) => expense.isCalculated);
    } catch (e) {
      print('Hesaplama durumu kontrol edilirken hata: $e');
      return false;
    }
  }

  Future<void> updateExpenseStatusesAfterCalculation(
    String parentId,
    String type,
    Map<String, double> balances,
    List<Expense> expenses,
  ) async {
    try {
      // Borçluları ve alacaklıları ayır
      Map<String, List<String>> debtors = {}; // borçlu -> alacaklı listesi
      Map<String, List<String>> creditors = {}; // alacaklı -> borçlu listesi

      // Borç ilişkilerini belirle
      for (var entry1 in balances.entries) {
        if (entry1.value < 0) { // Borçlu
          for (var entry2 in balances.entries) {
            if (entry2.value > 0) { // Alacaklı
              debtors.putIfAbsent(entry1.key, () => []).add(entry2.key);
              creditors.putIfAbsent(entry2.key, () => []).add(entry1.key);
            }
          }
        }
      }

      // Her harcama için paidBy durumlarını güncelle
      for (var expense in expenses) {
        Map<String, bool> updatedPaidBy = Map.from(expense.paidBy);

        if (balances[expense.creatorId]! < 0) {
          // Borçlu kişinin harcaması - herkes true
          updatedPaidBy.updateAll((_, __) => true);
        } else if (balances[expense.creatorId]! > 0) {
          // Alacaklı kişinin harcaması
          updatedPaidBy.updateAll((key, _) {
            // Eğer key bir borçlu ise ve bu alacaklıya borcu varsa false, değilse true
            if (debtors.containsKey(key)) {
              return !debtors[key]!.contains(expense.creatorId);
            }
            // Diğer alacaklılar için true
            return true;
          });
        } else {
          // Ne borçlu ne alacaklı - herkes true
          updatedPaidBy.updateAll((_, __) => true);
        }

        // Firebase'i güncelle
        await _firestore
            .collection(type == 'house' ? 'houses' : 'events')
            .doc(parentId)
            .collection('expenses')
            .doc(expense.id)
            .update({'paidBy': updatedPaidBy});
      }
    } catch (e) {
      throw 'Ödeme durumları güncellenirken hata oluştu: $e';
    }
  }

  Future<void> markAsPaid(String parentId, String type, String expenseId, String debtorId) async {
    try {
      final expenseRef = _firestore
          .collection(type == 'house' ? 'houses' : 'events')
          .doc(parentId)
          .collection('expenses')
          .doc(expenseId);

      final expenseDoc = await expenseRef.get();
      if (!expenseDoc.exists) throw 'Harcama bulunamadı';

      Map<String, dynamic> data = expenseDoc.data() as Map<String, dynamic>;
      Map<String, bool> paidBy = Map<String, bool>.from(data['paidBy'] as Map);
      
      paidBy[debtorId] = true;
      
      await expenseRef.update({'paidBy': paidBy});
    } catch (e) {
      throw 'Ödeme durumu güncellenirken hata oluştu: $e';
    }
  }

}

// Yeni sınıf ekleyelim
class PaymentSummary {
  final String expenseId;
  final String userId;
  final String creditorId;
  final String title;
  final String parentName;
  final String parentId;
  final String type;
  final double amount;
  final bool isPaid;

  PaymentSummary({
    required this.expenseId,
    required this.userId,
    required this.creditorId,
    required this.title,
    required this.parentName,
    required this.parentId,
    required this.type,
    required this.amount,
    required this.isPaid,
  });
}
