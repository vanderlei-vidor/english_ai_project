from datetime import date, timedelta
from app.models.weekly_xp import WeeklyXP
from app.models.weekly_results import WeeklyResult
from app.models.system_state import SystemState  # Seu modelo Chave-Valor
from app.models.user import User
from app.services.ranking_service import get_league_from_percentage, LEAGUE_ORDER


def check_and_close_week(db):
    today = date.today()
    # Calcula a segunda-feira da semana ATUAL
    current_week_start = today - timedelta(days=today.weekday())

    # ⚡ AJUSTE CHAVE-VALOR: Buscamos a linha específica onde a chave é 'last_closed_week'
    state_record = (
        db.query(SystemState).filter(SystemState.key == "last_closed_week").first()
    )

    if not state_record:
        print(
            " [WARNING] Estado do sistema ('last_closed_week') não configurado na tabela system_state."
        )
        return

    # ⚡ CONVERSÃO DE TIPO: Como o banco salva String, convertemos para objeto date do Python
    try:
        last_closed_week = date.fromisoformat(state_record.value)
    except (ValueError, TypeError):
        print(
            f" [ERROR] O valor '{state_record.value}' não é uma data válida no formato YYYY-MM-DD."
        )
        return

    # 🛡️ Se o sistema já processou o fechamento dessa semana, aborta para evitar duplicidade
    if last_closed_week == current_week_start:
        return

    # ⚡ SQL JOIN: Puxa os pontos da semana passada usando a data que descobrimos no par chave-valor
    query_results = (
        db.query(WeeklyXP, User)
        .join(User, User.id == WeeklyXP.user_id)
        .filter(WeeklyXP.week_start == last_closed_week)
        .order_by(WeeklyXP.total_xp.desc())
        .all()
    )

    total_users = len(query_results)
    if total_users == 0:
        # Se ninguém pontuou, atualiza o ponteiro do sistema para a semana atual
        state_record.value = current_week_start.isoformat()
        db.commit()
        return

    weekly_results_to_save = []

    for index, (record, user) in enumerate(query_results):
        position = index + 1
        top_percentage = round((position / total_users) * 100)

        current_league = user.current_league

        try:
            current_index = LEAGUE_ORDER.index(current_league)
        except ValueError:
            current_index = 0

        # Regras de promoção e rebaixamento
        if top_percentage <= 20 and current_index < len(LEAGUE_ORDER) - 1:
            user.current_league = LEAGUE_ORDER[current_index + 1]
        elif top_percentage >= 80 and current_index > 0 and total_users > 2:
            user.current_league = LEAGUE_ORDER[current_index - 1]

        league_info = get_league_from_percentage(top_percentage)

        weekly_result = WeeklyResult(
            user_id=record.user_id,
            week_start=last_closed_week,  # Usando a data correta
            final_position=position,
            final_xp=record.total_xp or 0,
            league=league_info["name"],
        )
        weekly_results_to_save.append(weekly_result)

    try:
        db.add_all(weekly_results_to_save)

        # Limpa os registros brutos semanais antigos
        db.query(WeeklyXP).filter(WeeklyXP.week_start == last_closed_week).delete()

        # ⚡ ATUALIZAÇÃO CHAVE-VALOR: Converte a data atual para texto (ISO) e salva no banco
        state_record.value = current_week_start.isoformat()

        db.commit()
        print(
            f" [SUCCESS] Semana {current_week_start} iniciada. {total_users} usuários processados."
        )

    except Exception as e:
        db.rollback()
        print(f" [ERROR] Falha crítica no fechamento de semana: {str(e)}")
        raise e
