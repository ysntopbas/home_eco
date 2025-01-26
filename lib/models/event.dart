class Event {
  final String id;
  final String title;
  final String description;
  final String houseId;
  final String creatorId;
  final String inviteCode;
  final DateTime date;
  final List<String> participantIds;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.houseId,
    required this.creatorId,
    required this.inviteCode,
    required this.date,
    required this.participantIds,
  });
} 