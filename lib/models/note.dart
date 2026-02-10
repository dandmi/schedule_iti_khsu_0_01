class Note {
  final int? id; // note_id
  final String? title;
  final String? description;
  final int createdAt; // timestamp
  final int? lessonId;

  Note({
    this.id,
    this.title,
    this.description,
    required this.createdAt,
    this.lessonId,
  });

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['note_id'] as int?,
    title: map['title'] as String?,
    description: map['description'] as String?,
    createdAt: map['created_at'] as int,
    lessonId: map['lesson_id'] as int?,
  );

  Map<String, dynamic> toMap() => {
    'note_id': id,
    'title': title,
    'description': description,
    'created_at': createdAt,
    'lesson_id': lessonId,
  };

  Note copyWith({
    int? id,
    String? title,
    String? description,
    int? createdAt,
    int? lessonId,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      lessonId: lessonId ?? this.lessonId,
    );
  }
}
