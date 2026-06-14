import re

# Dicionário de mapeamento: Categoria -> Lista de palavras-chave ou regex
SKILL_PATTERNS = {
    "past_tense": [
        "past tense",
        "did",
        "went",
        "was",
        "were",
        "had",
        "ed ",
        "yesterday",
        "ago",
    ],
    "articles": [
        " article",
        "use a ",
        "use an ",
        "use the ",
        "missing a ",
        "missing an",
    ],
    "prepositions": [
        "preposition",
        " on ",
        " in ",
        " at ",
        " to ",
        " for ",
        " about ",
        " with ",
    ],
    "pronouns": [
        "pronoun",
        " he ",
        " she ",
        " they ",
        " his ",
        " her ",
        " your ",
        " my ",
    ],
}


def detect_skill(correction: str) -> str | None:
    if not correction or not isinstance(correction, str):
        return None

    text = correction.lower()

    # Percorre o mapa de habilidades buscando alguma ocorrência relevante
    for skill, keywords in SKILL_PATTERNS.items():
        for keyword in keywords:
            if keyword in text:
                return skill

    return None
