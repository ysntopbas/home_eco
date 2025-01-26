class House {
  final String id;
  final String name;
  final String ownerId;
  final String inviteCode;
  final List<String> memberIds;

  House({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.inviteCode,
    required this.memberIds,
  });
} 