import random

AVAILABLE_TYPES = [
    "multiple_choice",
    "fill_blank",
    "sentence_correction",
    "sentence_reordering",
    "verb_transformation",
]


def choose_exercise_type(memory_data):
    # Garante que puxa uma lista caso venha nulo do banco
    recent = memory_data.get("recent_exercise_types", [])
    if not isinstance(recent, list):
        recent = []

    # Evita repetir os últimos 3 tipos de exercícios aplicados
    allowed = [t for t in AVAILABLE_TYPES if t not in recent[-3:]]

    if not allowed:
        allowed = AVAILABLE_TYPES

    return random.choice(allowed)


def should_generate_exercise(correction: str, memory_data: dict):
    # Se o usuário errou a frase ATUAL (e a correção não for o nosso texto de sucesso "Correct!")
    if correction and "Correct!" not in correction:
        return True

    weak_skills = memory_data.get("weak_skills", {})
    if not isinstance(weak_skills, dict):
        return False

    total_weakness = sum(weak_skills.values())

    # Só ativa se o peso das dificuldades acumuladas for relevante
    if total_weakness >= 10:
        return True

    return False
