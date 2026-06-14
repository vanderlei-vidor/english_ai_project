def detect_english_level(user_message):

    text = user_message.lower()

    words = text.split()

    word_count = len(words)

    score = 0

    # tamanho
    if word_count > 3:
        score += 1

    if word_count > 8:
        score += 1

    if word_count > 15:
        score += 1

    # passado
    if any(word in text for word in ["went", "played", "watched", "studied", "worked"]):
        score += 1

    # conectores
    if any(
        word in text for word in ["because", "although", "however", "while", "after"]
    ):
        score += 1

    # futuro
    if "will" in text:
        score += 1

    if score <= 1:
        return "A1"

    if score <= 3:
        return "A2"

    if score <= 5:
        return "B1"

    return "B2"
