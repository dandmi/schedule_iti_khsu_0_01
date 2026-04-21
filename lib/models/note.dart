class Note {
  final int? id;
  final String? title;
  final String? description;
  final int createdAt;
  final int? lessonId;

  Note({
    this.id,
    this.title,
    this.description,
    required this.createdAt,
    this.lessonId,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['note_id'] as int?,
      title: map['title'] as String?,
      description: map['description'] as String?,
      createdAt: map['created_at'] as int? ?? 0,
      lessonId: map['lesson_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'note_id': id,
    'title': title,
    'description': description,
    'created_at': createdAt,
    'lesson_id': lessonId,
  };
}
