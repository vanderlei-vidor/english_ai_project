from datetime import date, timedelta
from app.models.weekly_xp import WeeklyXP
from app.models.weekly_results import WeeklyResult


def get_league_from_percentage(top_percentage: int):
    if top_percentage <= 5:
        return {"name": "Diamond", "icon": "💎", "color": "purple"}
    elif top_percentage <= 15:
        return {"name": "Platinum", "icon": "🏆", "color": "cyan"}
    elif top_percentage <= 35:
        return {"name": "Gold", "icon": "🥇", "color": "gold"}
    elif top_percentage <= 60:
        return {"name": "Silver", "icon": "🥈", "color": "silver"}
    else:
        return {"name": "Bronze", "icon": "🥉", "color": "brown"}


def close_week(db, target_week_start: date = None):
    """
    Fecha a semana de forma segura.
    Se 'target_week_start' não for passado, ele calcula automaticamente
    com base na segunda-feira da semana passada (ideal para rodar nas segundas-feiras).
    """
    if target_week_start is None:
        today = date.today()
        # Se rodar na segunda-feira, volta 7 dias para pegar a segunda passada
        # Se rodar no domingo, pega a segunda da própria semana
        current_monday = today - timedelta(days=today.weekday())
        if today.weekday() == 0:  # É segunda-feira?
            target_week_start = current_monday - timedelta(days=7)
        else:
            target_week_start = current_monday

    # 1. Puxa os dados estritamente da semana correta
    results = (
        db.query(WeeklyXP)
        .filter(WeeklyXP.week_start == target_week_start)
        .order_by(WeeklyXP.total_xp.desc())
        .all()
    )

    total_users = len(results)
    if total_users == 0:
        return

    results_to_save = []

    # 2. Processa o ranking dos usuários
    for index, record in enumerate(results):
        position = index + 1
        percentage = round((position / total_users) * 100)
        league = get_league_from_percentage(percentage)

        result = WeeklyResult(
            user_id=record.user_id,
            week_start=target_week_start,
            final_position=position,
            final_xp=record.total_xp or 0,  # Proteção contra valores nulos
            league=league["name"],
        )
        results_to_save.append(result)

    try:
        # ⚡ OTIMIZAÇÃO: Salva todos os registros em lote (Bulk Insert) de uma só vez
        db.add_all(results_to_save)

        # 3. Limpa o XP da semana que foi fechada com sucesso
        db.query(WeeklyXP).filter(WeeklyXP.week_start == target_week_start).delete()

        db.commit()
        print(
            f" [SUCCESS] Semana {target_week_start} fechada. {total_users} usuários processados."
        )

    except Exception as e:
        db.rollback()
        print(f" [ERROR] Falha ao fechar a semana {target_week_start}: {str(e)}")
        raise e


LEAGUE_ORDER = ["Bronze", "Silver", "Gold", "Platinum", "Diamond"]
