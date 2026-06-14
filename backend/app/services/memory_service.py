import copy
from sqlalchemy.orm import Session
from sqlalchemy.orm.attributes import flag_modified
from app.models.user_memory import UserMemory, TOPICS_DATABASE
from app.services.exercise_tracker import detect_exercise_type
from app.services.level_service import detect_english_level
from app.services.skill_tracker import detect_skill


def get_user_memory(db: Session, user_id: str):
    memory = db.query(UserMemory).filter(UserMemory.user_id == user_id).first()

    if not memory:
        memory = UserMemory(
            user_id=user_id,
            data={
                "english_level": "A1",
                "common_errors": {},
                "favorite_topics": {},
                "weak_skills": {},
                "recent_exercise_types": [],
                "conversation_style": "casual",
                "total_conversations": 0,
            },
        )
        db.add(memory)
        db.commit()
        db.refresh(memory)

    return memory


def update_memory_from_message(
    db: Session, user_id: str, user_message: str, correction: str, exercise: str
):
    memory = get_user_memory(db, user_id)

    # ⚡ CORREÇÃO DO BUG: Usamos deepcopy para duplicar os dicionários internos também
    data = copy.deepcopy(memory.data)

    # Inicializações de segurança
    if not isinstance(data.get("favorite_topics"), dict):
        data["favorite_topics"] = {}
    if not isinstance(data.get("weak_skills"), dict):
        data["weak_skills"] = {}
    if not isinstance(data.get("common_errors"), dict):
        data["common_errors"] = {}
    if not isinstance(data.get("recent_exercise_types"), list):
        data["recent_exercise_types"] = []

    # 🎯 Bloco Weak Skills
    skill = detect_skill(correction)
    if skill:
        data["weak_skills"][skill] = data["weak_skills"].get(skill, 0) + 1

    # 🚀 Histórico Recente de Exercícios
    exercise_type = detect_exercise_type(exercise)
    if exercise_type:
        data["recent_exercise_types"].append(exercise_type)
        data["recent_exercise_types"] = data["recent_exercise_types"][-5:]

    # 🔥 TOTAL CONVERSATIONS
    data["total_conversations"] = data.get("total_conversations", 0) + 1

    # 🔥 DETECT ENGLISH LEVEL
    detected_level = detect_english_level(user_message)
    levels = {"A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5, "C2": 6}
    current_level = data.get("english_level", "A1")

    if levels.get(detected_level, 1) > levels.get(current_level, 1):
        data["english_level"] = detected_level

    # 🔥 DETECT FAVORITE TOPICS
    message_lower = user_message.lower()
    for topic, keywords in TOPICS_DATABASE.items():
        for keyword in keywords:
            if keyword in message_lower:
                data["favorite_topics"][topic] = (
                    data["favorite_topics"].get(topic, 0) + 1
                )
                break

    # 🔥 DETECT VERB TENSE ERROR
    if "went" in correction.lower():
        data["common_errors"]["verb tense"] = (
            data["common_errors"].get("verb tense", 0) + 1
        )

    # 🔥 DETECT ARTICLES
    if "article" in correction.lower():
        data["common_errors"]["articles"] = data["common_errors"].get("articles", 0) + 1

    # ⚡ SALVAMENTO BLINDADO: Atualiza o dicionário
    memory.data = data

    # 🔥 O SEGREDO: Força o SQLAlchemy a ver a alteração profunda no JSON
    flag_modified(memory, "data")

    db.commit()
    return memory
