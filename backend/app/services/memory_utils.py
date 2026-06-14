def get_top_errors(common_errors, limit=3):
    # Blindagem preventiva
    if not common_errors or not isinstance(common_errors, dict):
        return []

    sorted_errors = sorted(common_errors.items(), key=lambda x: x[1], reverse=True)

    return [error[0] for error in sorted_errors[:limit]]


def get_top_topics(topics, limit=3):
    # Blindagem preventiva
    if not topics or not isinstance(topics, dict):
        return []

    sorted_topics = sorted(topics.items(), key=lambda x: x[1], reverse=True)

    return [topic[0] for topic in sorted_topics[:limit]]
