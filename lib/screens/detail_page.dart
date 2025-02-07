import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/theme_provider.dart';

class DetailPage extends StatefulWidget {
  final dynamic item; // House veya Event
  final String type; // 'house' veya 'event'

  const DetailPage({
    super.key,
    required this.item,
    required this.type,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Expense> _expenses = [];
  Map<String, double> _balances = {};
  bool _isLoading = false;
  List<dynamic> _members = [];
  bool _isCalculated = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Üyeleri yükle
      _members = widget.type == 'house'
          ? await _firebaseService.getHouseMembers(widget.item.id)
          : await _firebaseService.getEventParticipants(widget.item.id);

      // Harcamaları yükle
      final expenses = await _firebaseService.getExpenses(
        widget.item.id,
        widget.type,
      );
      
      // Hesaplanmış mı kontrol et
      final allCalculated = await _firebaseService.checkAllExpensesCalculated(
        widget.item.id,
        widget.type,
      );
      
      // Eğer hesaplanmışsa bakiyeleri hesapla
      Map<String, double> balances = {};
      if (allCalculated) {
        balances = _calculateBalances(expenses, _members);
        await _loadPaymentStatuses();
        
        // Sadece _isCalculated false iken çağır (ilk hesaplama yapıldığında)
        if (!_isCalculated) {
          await _firebaseService.updateExpenseStatusesAfterCalculation(
            widget.item.id,
            widget.type,
            balances,
            expenses,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _expenses = expenses;
        _balances = balances;
        _isCalculated = allCalculated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veriler yüklenirken hata oluştu: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPaymentStatuses() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    Map<String, bool> statuses = {};
    
    for (var member in widget.type == 'house' ? 
        await _firebaseService.getHouseMembers(widget.item.id) :
        await _firebaseService.getEventParticipants(widget.item.id)) {
      if (_balances[member.id] != null && _balances[member.id]! > 0) {
        final status = await _firebaseService.checkPaymentStatus(
          widget.item.id,
          widget.type,
          currentUser.uid,
          member.id,
        );
        statuses[member.id] = status;
      }
    }

    if (mounted) {
      setState(() {
      });
    }
  }


  Map<String, double> _calculateBalances(List<Expense> expenses, List<dynamic> members) {
    Map<String, double> totalSpentByMember = {};
    double totalExpense = 0;

    // Her üyenin başlangıç harcamasını 0 olarak ayarla
    for (var member in members) {
      totalSpentByMember[member.id] = 0;
    }

    // Toplam harcamayı ve kişi başı harcamaları hesapla
    for (var expense in expenses) {
      totalExpense += expense.totalPrice;
      totalSpentByMember[expense.creatorId] = 
          (totalSpentByMember[expense.creatorId] ?? 0) + expense.totalPrice;
    }

    // Kişi başı düşen ortalama tutarı hesapla
    double averagePerPerson = totalExpense / members.length;

    // Her üyenin borç/alacak durumunu hesapla
    Map<String, double> balances = {};
    for (var member in members) {
      balances[member.id] = (totalSpentByMember[member.id] ?? 0) - averagePerPerson;
    }

    return balances;
  }






  Widget _buildMembersList() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final balance = _balances[member.id] ?? 0;
        final isCalculated = _expenses.isNotEmpty && 
            _expenses.first.calculatedBy.values.where((calculated) => calculated).length == _members.length;

        // Kişinin borçlu olduğu alacaklıları bul
        List<Map<String, dynamic>> debts = [];
        if (balance < 0 && member.id == currentUserId) {
          // Alacaklıları ve alacak miktarlarını bul
          for (var otherMember in _members) {
            double creditorBalance = _balances[otherMember.id] ?? 0;
            if (creditorBalance > 0) {
              // Kullanıcının bu alacaklıya ait tüm harcamalardaki ödeme durumunu kontrol et
              bool hasUnpaidExpenses = false;
              String? firstUnpaidExpenseId;
              
              for (var expense in _expenses) {
                if (expense.creatorId == otherMember.id && 
                    expense.paidBy.containsKey(member.id) && 
                    !expense.paidBy[member.id]!) {
                  hasUnpaidExpenses = true;
                  firstUnpaidExpenseId = expense.id;
                  break;
                }
              }

              // Sadece ödenmemiş harcama varsa listeye ekle
              if (hasUnpaidExpenses) {
                debts.add({
                  'creditorId': otherMember.id,
                  'creditorName': otherMember.name,
                  'amount': creditorBalance,
                  'expenseId': firstUnpaidExpenseId,
                });
              }
            }
          }
        }

        return Card(
          color: isCalculated 
              ? balance > 0 
                  ? customColors?.success
                  : balance < 0 
                      ? customColors?.error
                      : customColors?.neutral
              : theme.cardColor,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  member.name,
                  style: TextStyle(
                    fontWeight: isCalculated ? FontWeight.bold : FontWeight.normal,
                    color: customColors?.cardText
                  ),
                ),
                subtitle: isCalculated
                    ? Text(
                        balance > 0
                            ? 'Alacak: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(balance)}'
                            : balance < 0
                                ? 'Borç: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(balance.abs())}'
                                : 'Borç/Alacak yok',
                        style: TextStyle(
                          color: balance > 0 
                              ? customColors?.positiveBalance
                              : balance < 0 
                                  ? customColors?.negativeBalance
                                  : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (isCalculated && debts.isNotEmpty)
                ...debts.map((debt) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${debt['creditorName']}: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(debt['amount'])}',
                        style: TextStyle(
                          color: customColors?.negativeBalance,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await _firebaseService.markAsPaid(
                              widget.item.id,
                              widget.type,
                              debt['expenseId'],
                              member.id,
                            );
                            _loadData();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Hata: $e')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: customColors?.negativeBalance,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        child: const Text('Öde'),
                      ),
                    ],
                  ),
                )).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpensesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _expenses.length,
      itemBuilder: (context, index) {
        final expense = _expenses[index];
        return Card(
          child: ListTile(
            title: Text(expense.name),
            subtitle: Text(
              '${expense.creatorName} tarafından eklendi\n'
              '${expense.quantity} adet x ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(expense.price)}',
            ),
            trailing: Text(
              NumberFormat.currency(
                locale: 'tr_TR',
                symbol: '₺',
              ).format(expense.totalPrice),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalculateButton() {
    // Kaç kişinin hesapladığını bul
    int calculatedCount = 0;
    if (_expenses.isNotEmpty) {
      final firstExpense = _expenses.first;
      calculatedCount = firstExpense.calculatedBy.values
          .where((calculated) => calculated)
          .length;
    }

    return Row(
      children: [
        Text(
          '$calculatedCount/${_members.length}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.calculate),
          label: const Text('Hesapla'),
          style: ElevatedButton.styleFrom(
            //backgroundColor: Colors.green,
            //foregroundColor: Colors.white,
          ),
          onPressed: () async {
            try {
              await _firebaseService.updateCalculationStatus(
                widget.item.id,
                widget.type,
              );

              // Tüm harcamalar hesaplandı mı kontrol et
              final allCalculated = await _firebaseService.checkAllExpensesCalculated(
                widget.item.id,
                widget.type,
              );

              if (!mounted) return;

              if (allCalculated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm hesaplamalar tamamlandı!')),
                );
                _loadData(); // Verileri yenile
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hesaplama kaydedildi. Diğer üyelerin hesaplaması bekleniyor.')),
                );
                _loadData(); // Hesaplayan kişi sayısını güncellemek için
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Hata: $e')),
              );
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.type == 'house' 
        ? widget.item.name 
        : widget.item.title;

    // Hesaplayan kişi sayısını kontrol et
    int calculatedCount = 0;
    if (_expenses.isNotEmpty) {
      final firstExpense = _expenses.first;
      calculatedCount = firstExpense.calculatedBy.values
          .where((calculated) => calculated)
          .length;
    }
    
    // Tüm üyeler hesaplamış mı?
    final allMembersCalculated = _members.isNotEmpty && 
        calculatedCount == _members.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_expenses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildCalculateButton(),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.type == 'event') ...[
                        Text(
                          'Tarih: ${DateFormat('dd/MM/yyyy').format(widget.item.date)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Açıklama: ${widget.item.description}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        widget.type == 'house' ? 'Ev Üyeleri' : 'Katılımcılar',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildMembersList(),
                      if (_expenses.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Harcamalar',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildExpensesList(),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: !allMembersCalculated
          ? FloatingActionButton(
              onPressed: _showAddExpenseModal,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _showAddExpenseModal() async {
    if (!mounted) return;

    String? name;
    int? quantity;
    double? price;
    double total = 0;

    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final priceController = TextEditingController();

    final currentContext = context;

    await showModalBottomSheet(
      context: currentContext,
      isScrollControlled: true,
      builder: (BuildContext modalContext) => StatefulBuilder(
        builder: (modalContext, setState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Harcama Ekle',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Ürün Adı',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => name = value,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Adet',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  quantity = int.tryParse(value);
                  setState(() {
                    total = (quantity ?? 0) * (price ?? 0);
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Birim Fiyat',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  price = double.tryParse(value);
                  setState(() {
                    total = (quantity ?? 0) * (price ?? 0);
                  });
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Toplam: ${NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(total)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (name != null && quantity != null && price != null) {
                    try {
                      await _firebaseService.addExpense(
                        name: name!,
                        quantity: quantity!,
                        price: price!,
                        parentId: widget.item.id,
                        type: widget.type,
                      );

                      if (!mounted) return;
                      _loadData();
                      
                      Navigator.pop(modalContext); // İşlemler başarılı olduktan sonra kapat

                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        const SnackBar(content: Text('Harcama başarıyla eklendi')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(content: Text('Hata: $e')),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(modalContext).showSnackBar(
                      const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
                    );
                  }
                },
                child: const Text('Tamam'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
} 