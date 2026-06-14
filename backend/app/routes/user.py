from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.user import User
from app.models.schemas import UserCreate
import uuid
from app.models.progress import Progress
from app.models.user_badge import UserBadge
from app.models.badge import Badge
from app.models.xp import XP
from app.models.user_badge import UserBadge
from app.models.badge import Badge
from app.models.xp import XP
from app.models.user import User
from app.services.ranking_service import get_league_from_percentage
from datetime import date, timedelta
from app.models.weekly_xp import WeeklyXP
from app.services.ranking_service import get_league_from_percentage
from app.models.streak import Streak
from app.services.season_service import close_season
from app.services.weekly_service import check_and_close_week
from sqlalchemy import func


from app.services.score_service import (
    calculate_global_score,
    get_level,
    get_next_level
)


router = APIRouter()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@router.post("/users")
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    new_user = User(
        id=str(uuid.uuid4()),
        email=user.email,
        password_hash=user.password
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {"message": "Usuário criado com sucesso!", "user_id": new_user.id}

@router.post("/admin/close-week")
def close_week_endpoint(db: Session = Depends(get_db)):
    check_and_close_week(db)
    return {"message": "Semana encerrada com sucesso"}


@router.get("/progress/{user_id}")
def get_user_progress(user_id: str, db: Session = Depends(get_db)):

    records = db.query(Progress).filter(
        Progress.user_id == user_id
    ).all()

    global_score = calculate_global_score(records)
    level = get_level(global_score)
    meta = get_next_level(global_score)

    streak = db.query(Streak).filter(
        Streak.user_id == user_id
    ).first()

    return {
        "total_conversations": len(records),
        "global_score": global_score,
        "level": level,
        "meta": meta,
        "streak": {
            "current": streak.current_streak if streak else 0,
            "longest": streak.longest_streak if streak else 0
        }
    }


@router.get("/badges/{user_id}")
def get_user_badges(user_id: str, db: Session = Depends(get_db)):

    results = (
        db.query(Badge)
        .join(UserBadge, Badge.id == UserBadge.badge_id)
        .filter(UserBadge.user_id == user_id)
        .all()
    )

    badge_list = []

    for badge in results:
        badge_list.append({
            "code": badge.code,
            "title": badge.title,
            "description": badge.description,
            "icon": badge.icon,
            "category": badge.category
        })

    return {
        "total_badges": len(badge_list),
        "badges": badge_list
    }

@router.get("/profile/{user_id}")
def get_user_profile(user_id: str, db: Session = Depends(get_db)):

    user = db.query(User).filter(User.id == user_id).first()

    records = db.query(Progress).filter(
        Progress.user_id == user_id
    ).all()

    global_score = calculate_global_score(records)
    level = get_level(global_score)
    meta = get_next_level(global_score)

    streak = db.query(Streak).filter(
        Streak.user_id == user_id
    ).first()

    xp_record = db.query(XP).filter(
        XP.user_id == user_id
    ).first()

    from app.services.xp_service import get_level_from_xp

    xp_data = {
        "total_xp": xp_record.total_xp if xp_record else 0,
        "level_data": get_level_from_xp(xp_record.total_xp if xp_record else 0)
    }

    return {
        "user_id": user_id,

        "user_league": user.current_league if user else "Bronze",

        "stats": {
            "total_conversations": len(records),
            "global_score": global_score
        },

        "level": level,
        "meta": meta,

        "streak": {
            "current": streak.current_streak if streak else 0,
            "longest": streak.longest_streak if streak else 0
        },

        "xp": xp_data
    }

@router.get("/ranking/weekly")
def get_weekly_ranking(db: Session = Depends(get_db)):
    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    # ⚡ CORREÇÃO: Descobre quantos usuários totais pontuaram essa semana no app inteiro
    total_active_users = (
        db.query(func.count(WeeklyXP.id))
        .filter(WeeklyXP.week_start == week_start)
        .scalar()
        or 1
    )

    # Puxa o Top 20 incluindo a liga atual salva no cadastro do usuário
    results = (
        db.query(User.id, User.email, User.current_league, WeeklyXP.total_xp)
        .join(WeeklyXP, WeeklyXP.user_id == User.id)
        .filter(WeeklyXP.week_start == week_start)
        .order_by(WeeklyXP.total_xp.desc())
        .limit(20)
        .all()
    )

    ranking = []
    for position, user in enumerate(results, start=1):
        # ⚡ CORREÇÃO: Porcentagem baseada no universo total de jogadores ativos da semana
        top_percentage = round((position / total_active_users) * 100)

        ranking.append(
            {
                "position": position,
                "user_id": user.id,
                "email": user.email,
                "weekly_xp": user.total_xp,
                "league": user.current_league,  # Puxa a liga real dele do banco
                "top_percentage": top_percentage,
            }
        )

    return {
        "week_start": str(week_start),
        "total_ranked_in_app": total_active_users,
        "ranking": ranking,
    }


@router.get("/ranking/{user_id}")
def get_user_ranking_position(user_id: str, db: Session = Depends(get_db)):
    # 1. Puxa o XP do usuário que fez a requisição
    user_xp_record = db.query(XP).filter(XP.user_id == user_id).first()
    if not user_xp_record:
        return {"error": "Usuário não possui registros de XP no ranking global"}

    user_xp = user_xp_record.total_xp

    # ⚡ CORREÇÃO DE ALTA PERFORMANCE: Em vez de carregar a tabela inteira,
    # apenas contamos quantos usuários têm mais XP do que ele.
    better_users_count = (
        db.query(func.count(XP.id)).filter(XP.total_xp > user_xp).scalar()
    )
    position = better_users_count + 1

    # Total de usuários cadastrados no app para calcular o percentil
    total_users = db.query(func.count(User.id)).scalar() or 1
    top_percentage = round((position / total_users) * 100)

    league_info = get_league_from_percentage(top_percentage)

    return {
        "position": position,
        "total_users": total_users,
        "total_xp": user_xp,
        "top_percentage": top_percentage,
        "league": league_info,
    }
@router.post("/admin/close-season")
def close_season_endpoint(db: Session = Depends(get_db)):
    close_season(db)
    return {"message": "Temporada encerrada com sucesso"}