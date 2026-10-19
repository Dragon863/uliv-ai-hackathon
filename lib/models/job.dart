enum JobPriority { normal, urgent }

enum JobStatus { newJob, inProgress, completed }

enum HistoryType { created, progress, note, completed }

class HistoryEntry {
  const HistoryEntry({
    required this.timestamp,
    required this.type,
    required this.text,
  });

  final DateTime timestamp;
  final HistoryType type;
  final String text;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'text': text,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    timestamp: DateTime.parse(json['timestamp'] as String),
    type: HistoryType.values.byName(json['type'] as String),
    text: json['text'] as String,
  );
}

class Job {
  const Job({
    required this.id,
    this.house = 'Meadow House',
    required this.description,
    required this.reporter,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.latestNote,
    this.history = const [],
  });

  final String id;
  final String house;
  final String description;
  final String reporter;
  final JobPriority priority;
  final JobStatus status;
  final DateTime createdAt;
  final String? latestNote;
  final List<HistoryEntry> history;

  Job copyWith({
    JobStatus? status,
    String? latestNote,
    List<HistoryEntry>? history,
  }) => Job(
    id: id,
    house: house,
    description: description,
    reporter: reporter,
    priority: priority,
    status: status ?? this.status,
    createdAt: createdAt,
    latestNote: latestNote ?? this.latestNote,
    history: history ?? this.history,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'house': house,
    'description': description,
    'reporter': reporter,
    'priority': priority.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'latestNote': latestNote,
    'history': history.map((entry) => entry.toJson()).toList(),
  };

  factory Job.fromJson(Map<String, dynamic> json) => Job(
    id: json['id'] as String,
    house: (json['house'] as String?) ?? 'Meadow House',
    description: json['description'] as String,
    reporter: json['reporter'] as String,
    priority: JobPriority.values.byName(json['priority'] as String),
    status: JobStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    latestNote: json['latestNote'] as String?,
    history: (json['history'] as List<dynamic>? ?? [])
        .map((entry) => HistoryEntry.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false),
  );
}
