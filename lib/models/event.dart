class Event {
  final String id;
  final String title;
  final String description;
  final String creatorId;
  final String creatorName;
  final String inviteCode;
  final DateTime date;
  final List<String> participantIds;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.creatorId,
    required this.creatorName,
    required this.inviteCode,
    required this.date,
    required this.participantIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'inviteCode': inviteCode,
      'date': date.toIso8601String(),
      'participantIds': participantIds,
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      creatorId: map['creatorId'],
      creatorName: map['creatorName'],
      inviteCode: map['inviteCode'],
      date: DateTime.parse(map['date']),
      participantIds: List<String>.from(map['participantIds']),
    );
  }
}
