class Flashcard {
  final String id;
  final String question;
  final String answer;
  final String keyConcept;
  final String? codeSnippet;
  bool isMastered;

  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    required this.keyConcept,
    this.codeSnippet,
    this.isMastered = false,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      keyConcept: json['key_concept'] ?? json['keyConcept'] ?? 'Core Concept',
      codeSnippet: json['code_snippet'],
      isMastered: json['is_mastered'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'question': question,
    'answer': answer,
    'key_concept': keyConcept,
    'code_snippet': codeSnippet,
    'is_mastered': isMastered,
  };
}
