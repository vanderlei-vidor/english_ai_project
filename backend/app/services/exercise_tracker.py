def detect_exercise_type(exercise: str):
    if not exercise:
        return None

    if not isinstance(exercise, str):
        return "unknown"

    text = exercise.lower()

    # Multiple Choice
    if "(a)" in text and "(b)" in text or "multiple choice" in text:
        return "multiple_choice"

    # Reordering
    if (
        "reorder" in text or "/" in text
    ):  # Geralmente reordenação usa barras separando as palavras
        return "sentence_reordering"

    # Correction
    if "correct the sentence" in text or "correct:" in text:
        return "sentence_correction"

    # Verb Transformation (Melhorado para evitar o bug do texto intercalado)
    if "transform" in text or "past tense" in text or "verb" in text:
        if "(" in text and ")" in text and not "(a)" in text:  # Padrão: Naruto (to go)
            return "verb_transformation"

    # Fill Blank
    if (
        "fill in the blank" in text
        or "complete the sentence" in text
        or "_____" in text
    ):
        return "fill_blank"

    return "unknown"
