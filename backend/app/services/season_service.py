from datetime import date
from app.models.league_history import LeagueHistory
from app.models.xp import XP
from app.models.weekly_xp import WeeklyXP
from app.models.user import User


def close_season(db):
    today = date.today()
    season_month = today.strftime("%Y-%m")

    # 1. Puxa o ranking necessário para gerar o histórico da temporada
    ranking = (
        db.query(User.id, XP.total_xp, User.current_league)
        .join(XP, XP.user_id == User.id)
        .order_by(XP.total_xp.desc())
        .all()
    )

    if not ranking:
        return

    history_records = []
    current_position = 1
    prev_xp = None

    # 2. Monta a lista de histórico em memória
    for index, user in enumerate(ranking):
        # Opcional e elegante: Trata empates de XP mantendo a mesma posição de ranking
        if prev_xp is not None and user.total_xp < prev_xp:
            current_position = index + 1

        prev_xp = user.total_xp

        history = LeagueHistory(
            user_id=user.id,
            season_month=season_month,
            league=user.current_league,
            final_position=current_position,
            total_xp=user.total_xp or 0,
        )
        history_records.append(history)

    try:
        # ⚡ OTIMIZAÇÃO 1: Bulk Insert do histórico de uma só vez
        db.add_all(history_records)

        # ⚡ OTIMIZAÇÃO 2: Bulk Update (Zera o XP de TODOS os usuários em uma única query SQL!)
        db.query(XP).update({XP.total_xp: 0}, synchronize_session=False)

        # ⚠️ ALERTA: Removi o WeeklyXP.delete() daqui de dentro.
        # É altamente recomendável deixar a limpeza do XP semanal exclusivamente
        # no arquivo 'close_week' para não bugar o progresso dos alunos no meio do mês!

        db.commit()
        print(
            f" [SUCCESS] Temporada {season_month} encerrada. {len(ranking)} usuários arquivados."
        )

    except Exception as e:
        db.rollback()
        print(f" [ERROR] Falha ao fechar temporada {season_month}: {str(e)}")
        raise e
