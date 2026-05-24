

from datetime import date, timedelta

from app.models.weekly_xp import WeeklyXP
from app.models.weekly_results import WeeklyResult

def get_league_from_percentage(top_percentage: int):

    if top_percentage <= 5:
        return {
            "name": "Diamond",
            "icon": "💎",
            "color": "purple"
        }
    elif top_percentage <= 15:
        return {
            "name": "Platinum",
            "icon": "🏆",
            "color": "cyan"
        }
    
    elif top_percentage <= 35:
        return {
            "name": "Gold",
            "icon": "🥇",
            "color": "gold"
        }

    elif top_percentage <= 60:
        return {
            "name": "Silver",
            "icon": "🥈",
            "color": "silver"
        }
    else:
        return {
            "name": "Bronze",
            "icon": "🥉",
            "color": "brown"
        }
    

    


def close_week(db):
    today = date.today()
    week_start = today - timedelta(days=today.weekday())

    results = (
        db.query(WeeklyXP)
        .filter(WeeklyXP.week_start == week_start)
        .order_by(WeeklyXP.total_xp.desc())
        .all()
    )

    total_users = len(results)

    if total_users == 0:
        return

    for index, record in enumerate(results):
        position = index + 1
        percentage = round((position / total_users) * 100)
        league = get_league_from_percentage(percentage)

        result = WeeklyResult(
            user_id=record.user_id,
            week_start=week_start,
            final_position=position,
            final_xp=record.total_xp,
            league=league["name"]
        )

        db.add(result)

    # limpar weekly xp da semana
    db.query(WeeklyXP).filter(
        WeeklyXP.week_start == week_start
    ).delete()

    db.commit()


LEAGUE_ORDER = [
    "Bronze",
    "Silver",
    "Gold",
    "Platinum",
    "Diamond"
]
