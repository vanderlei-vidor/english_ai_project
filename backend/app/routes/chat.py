from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.chat_schemas import ChatRequest
from app.models.conversation import Conversation
from app.models.message import Message
from app.services.chat_service import generate_response
import uuid
import json
from app.services.score_service import calculate_score
from app.models.progress import Progress
from app.models.streak import Streak
from app.services.streak_service import update_streak
from app.models.xp import XP
from app.services.xp_service import calculate_xp
from app.services.score_service import get_level, calculate_global_score
from app.services.xp_service import get_level_from_xp
from datetime import date
from app.models.weekly_xp import WeeklyXP
from datetime import timedelta

router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/chat")
def chat(request: ChatRequest, db: Session = Depends(get_db)):

    try:

        # 🔹 1️⃣ Se já existe conversation_id → usar
        if request.conversation_id:
            conversation = db.query(Conversation).filter(
                Conversation.id == request.conversation_id,
                Conversation.user_id == request.user_id
            ).first()

            if not conversation:
                return {"error": "Conversation não encontrada"}

        # 🔹 2️⃣ Se não existe → criar nova
        else:
            conversation = Conversation(
                id=str(uuid.uuid4()),
                user_id=request.user_id
            )
            db.add(conversation)
            db.commit()
            db.refresh(conversation)

        # 🔹 3️⃣ Salvar mensagem do usuário
        user_message = Message(
            conversation_id=conversation.id,
            sender="user",
            content=request.message
        )
        db.add(user_message)
        db.commit()

        # 🔹 4️⃣ Buscar histórico
        history = db.query(Message).filter(
            Message.conversation_id == conversation.id
        ).order_by(Message.created_at.asc()).all()

        messages_for_ai = []

        for msg in history[-8:]:
            messages_for_ai.append({
                "role": "assistant" if msg.sender == "ai" else "user",
                "content": msg.content
            })

        # 🔹 5️⃣ Chamar IA
        ai_response_dict = generate_response(messages_for_ai)
        if "error" in ai_response_dict:
            return ai_response_dict

        # 🔹 6️⃣ Converter para JSON string
        ai_response_json = json.dumps(ai_response_dict, ensure_ascii=False)

        # 🔹 7️⃣ Salvar resposta da IA
        ai_message = Message(
            conversation_id=conversation.id,
            sender="ai",
            content=ai_response_dict["conversation_reply"]
        )
        db.add(ai_message)
        db.commit()

        # 🔹 8️⃣ Calcular score da conversa
        conversation_messages = db.query(Message).filter(
            Message.conversation_id == conversation.id
        ).all()

        score = calculate_score(conversation_messages)

        # 🔹 9️⃣ Salvar progresso
        progress = Progress(
            user_id=request.user_id,
            conversation_id=conversation.id,
            score=score
        )

        db.add(progress)
        db.commit()

        # 🔹 Calcular score global atualizado
        all_progress = db.query(Progress).filter(
            Progress.user_id == request.user_id
        ).all()

        global_score = calculate_global_score(all_progress)

        cefr_level = get_level(global_score)

        # 🔹 🔥 10️⃣ Atualizar streak
        streak = db.query(Streak).filter(
            Streak.user_id == request.user_id
        ).first()

        if not streak:
            streak = Streak(user_id=request.user_id)
            db.add(streak)
            db.commit()
            db.refresh(streak)

        streak = update_streak(streak)
        db.commit()


    # 🔥 XP SYSTEM
        had_error = score < 100

        xp_record = db.query(XP).filter(
            XP.user_id == request.user_id
        ).first()

        if not xp_record:
            xp_record = XP(user_id=request.user_id, total_xp=0)
            db.add(xp_record)
            db.commit()
            db.refresh(xp_record)

        earned_xp = calculate_xp(score, had_error, streak.current_streak)

        xp_record.total_xp += earned_xp
        db.commit()

        # 🔥 WEEKLY XP SYSTEM
        today = date.today()

        # início da semana (segunda-feira)
        week_start = today - timedelta(days=today.weekday())

        weekly_record = db.query(WeeklyXP).filter(
            WeeklyXP.user_id == request.user_id,
            WeeklyXP.week_start == week_start
        ).first()

        if not weekly_record:
            weekly_record = WeeklyXP(
                user_id=request.user_id,
                total_xp=0,
                week_start=week_start
            )
            db.add(weekly_record)
            db.commit()
            db.refresh(weekly_record)

        weekly_record.total_xp += earned_xp
        db.commit()


        

        level_data = get_level_from_xp(xp_record.total_xp)

        from app.services.badge_service import check_and_award_badges

        badges_earned = check_and_award_badges(
            db=db,
            user_id=request.user_id,
            score=score,
            streak=streak.current_streak,
            xp_total=xp_record.total_xp,
            cefr_code=cefr_level["code"]
        )

        from app.services.weekly_service import check_and_close_week

        check_and_close_week(db)


        return {
            "conversation_id": conversation.id,
            "ai_response": ai_response_dict,
            "score": score,
            "streak": {
                "current": streak.current_streak,
                "longest": streak.longest_streak
            },

            "xp": {
                "earned": earned_xp,
                "total": xp_record.total_xp,
                "level": level_data
            },

            "badges_earned": badges_earned
                }
        
    except Exception as e:

        return {
            "error": str(e)
        }
