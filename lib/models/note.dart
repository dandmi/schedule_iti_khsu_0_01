class Note {
  final int? id;
  final String? title;
  final String? description;
  final String? subject;
  final int createdAt;
  final int? dueAt;
  final int? lessonId;

  Note({
    this.id,
    this.title,
    this.description,
    this.subject,
    required this.createdAt,
    this.dueAt,
    this.lessonId,
  });

  bool get hasDueAt => dueAt != null;

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['note_id'] as int?,
      title: map['title'] as String?,
      description: map['description'] as String?,
      subject: map['subject'] as String?,
      createdAt: map['created_at'] as int? ?? 0,
      dueAt: map['due_at'] as int?,
      lessonId: map['lesson_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'note_id': id,
    'title': title,
    'description': description,
    'subject': subject,
    'created_at': createdAt,
    'due_at': dueAt,
    'lesson_id': lessonId,
  };
}