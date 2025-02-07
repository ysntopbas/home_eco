class PaymentInfo {
  final String expenseId;
  final String userId;
  final String title;
  final String parentName;
  final String parentId;
  final String type;
  final double amount;
  final bool isPaid;
  final bool allPaid;
  final bool isDebt;

  PaymentInfo({
    required this.expenseId,
    required this.userId,
    required this.title,
    required this.parentName,
    required this.parentId,
    required this.type,
    required this.amount,
    required this.isPaid,
    required this.allPaid,
    required this.isDebt,
  });
} 