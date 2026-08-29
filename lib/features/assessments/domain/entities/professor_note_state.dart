class ProfessorNoteState {
  const ProfessorNoteState({
    required this.isVisible,
    required this.text,
  });

  const ProfessorNoteState.hidden()
    : isVisible = false,
      text = '';

  final bool isVisible;
  final String text;
}
