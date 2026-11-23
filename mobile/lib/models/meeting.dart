class Participant {
  final String? id;
  final String name;
  final String email;
  String status; // 'Attended' or 'Absent'
  String? speakerLabel;

  Participant({
    this.id,
    required this.name,
    required this.email,
    this.status = 'Attended',
    this.speakerLabel,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      status: json['status'] ?? 'Attended',
      speakerLabel: json['speaker_label'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      'status': status,
      if (speakerLabel != null) 'speaker_label': speakerLabel,
    };
  }
}

class TranscriptSegment {
  final String? id;
  String speakerLabel;
  final double startTime;
  final double endTime;
  final String text;

  TranscriptSegment({
    this.id,
    required this.speakerLabel,
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      id: json['id'],
      speakerLabel: json['speaker_label'] ?? 'SPEAKER_00',
      startTime: (json['start_time'] as num?)?.toDouble() ?? 0.0,
      endTime: (json['end_time'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] ?? '',
    );
  }

  String get timeFormatted {
    final sMin = (startTime ~/ 60).toString().padLeft(2, '0');
    final sSec = ((startTime % 60).toInt()).toString().padLeft(2, '0');
    final eMin = (endTime ~/ 60).toString().padLeft(2, '0');
    final eSec = ((endTime % 60).toInt()).toString().padLeft(2, '0');
    return '$sMin:$sSec - $eMin:$eSec';
  }
}

class DecisionItem {
  final String decision;
  final String timestamp;

  DecisionItem({required this.decision, required this.timestamp});

  factory DecisionItem.fromJson(Map<String, dynamic> json) {
    return DecisionItem(
      decision: json['decision'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class ActionItem {
  final String task;
  final String owner;
  final String deadline;
  final String timestamp;

  ActionItem({
    required this.task,
    required this.owner,
    required this.deadline,
    required this.timestamp,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      task: json['task'] ?? '',
      owner: json['owner'] ?? 'Not specified',
      deadline: json['deadline'] ?? 'Not specified',
      timestamp: json['timestamp'] ?? '',
    );
  }
}

class MeetingSummary {
  final String executiveSummary;
  final List<String> topicsDiscussed;
  final List<DecisionItem> decisions;
  final List<ActionItem> actionItems;
  final List<String> openQuestions;

  MeetingSummary({
    required this.executiveSummary,
    required this.topicsDiscussed,
    required this.decisions,
    required this.actionItems,
    required this.openQuestions,
  });

  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      executiveSummary: json['executive_summary'] ?? '',
      topicsDiscussed: List<String>.from(json['topics_discussed'] ?? []),
      decisions: (json['decisions'] as List? ?? [])
          .map((d) => DecisionItem.fromJson(d))
          .toList(),
      actionItems: (json['action_items'] as List? ?? [])
          .map((a) => ActionItem.fromJson(a))
          .toList(),
      openQuestions: List<String>.from(json['open_questions'] ?? []),
    );
  }
}

class Meeting {
  final String id;
  final String title;
  String status; // 'processing', 'ready', 'failed', 'sent'
  final String? audioUrl;
  String? pdfUrl;
  MeetingSummary? summary;
  final DateTime createdAt;
  final List<Participant> participants;
  List<TranscriptSegment> segments;

  Meeting({
    required this.id,
    required this.title,
    required this.status,
    this.audioUrl,
    this.pdfUrl,
    this.summary,
    required this.createdAt,
    required this.participants,
    required this.segments,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Meeting',
      status: json['status'] ?? 'processing',
      audioUrl: json['audio_url'],
      pdfUrl: json['pdf_url'],
      summary: json['summary_json'] != null
          ? MeetingSummary.fromJson(json['summary_json'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      participants: (json['participants'] as List? ?? [])
          .map((p) => Participant.fromJson(p))
          .toList(),
      segments: (json['segments'] as List? ?? [])
          .map((s) => TranscriptSegment.fromJson(s))
          .toList(),
    );
  }
}

class Citation {
  final String speaker;
  final double startTime;
  final double endTime;
  final String timestampStr;
  final String text;

  Citation({
    required this.speaker,
    required this.startTime,
    required this.endTime,
    required this.timestampStr,
    required this.text,
  });

  factory Citation.fromJson(Map<String, dynamic> json) {
    return Citation(
      speaker: json['speaker'] ?? 'SPEAKER_00',
      startTime: (json['start_time'] as num?)?.toDouble() ?? 0.0,
      endTime: (json['end_time'] as num?)?.toDouble() ?? 0.0,
      timestampStr: json['timestamp_str'] ?? '',
      text: json['text'] ?? '',
    );
  }
}

class AskResponse {
  final String answer;
  final List<Citation> citations;

  AskResponse({required this.answer, required this.citations});

  factory AskResponse.fromJson(Map<String, dynamic> json) {
    return AskResponse(
      answer: json['answer'] ?? '',
      citations: (json['citations'] as List? ?? [])
          .map((c) => Citation.fromJson(c))
          .toList(),
    );
  }
}
