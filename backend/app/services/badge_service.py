import uuid
from app.models.badge import Badge
from app.models.user_badge import UserBadge


def check_and_award_badges(db, user_id, score, streak, xp_total, cefr_code):
    awarded = []
    user_badges_to_create = []

    # ⚡ OTIMIZAÇÃO 1: Puxa todos os IDs de medalhas que o usuário JÁ possui de uma só vez.
    # Usamos um 'set' (conjunto) porque a busca nele em Python é instantânea — O(1) de performance.
    existing_badge_ids = {
        b_id
        for (b_id,) in db.query(UserBadge.badge_id)
        .filter(UserBadge.user_id == user_id)
        .all()
    }

    # 2. Puxa todas as medalhas cadastradas no sistema (geralmente uma tabela pequena)
    all_badges = db.query(Badge).all()

    for badge in all_badges:
        # ⚡ OTIMIZAÇÃO 2: Checagem em memória. Se já tem, pula direto sem ir ao banco.
        if badge.id in existing_badge_ids:
            continue

        # Avaliação de critérios para ganhar a medalha
        is_earned = False

        if badge.category == "streak" and streak >= badge.requirement_value:
            is_earned = True
        elif badge.category == "xp" and xp_total >= badge.requirement_value:
            is_earned = True
        elif badge.category == "cefr" and cefr_code == badge.code:
            is_earned = True
        elif badge.category == "perfect" and score == 100:
            is_earned = True

        # Se passou nos requisitos, prepara para salvar
        if is_earned:
            new_user_badge = UserBadge(
                id=str(uuid.uuid4()), user_id=user_id, badge_id=badge.id
            )
            user_badges_to_create.append(new_user_badge)

            # Monta o retorno com os dados visuais que o Flutter vai usar para o pop-up
            awarded.append(
                {
                    "code": badge.code,
                    "title": badge.title,
                    "description": badge.description,
                    "icon": badge.icon,
                }
            )

    # Se o usuário não ganhou nenhuma medalha nova nesta rodada, encerra cedo sem tocar no banco
    if not user_badges_to_create:
        return []

    try:
        # ⚡ OTIMIZAÇÃO 3: Bulk Insert das novas conquistas e commit atômico
        db.add_all(user_badges_to_create)
        db.commit()
        return awarded

    except Exception as e:
        db.rollback()
        print(f" [ERROR] Falha ao salvar novas medalhas do usuário {user_id}: {str(e)}")
        return []
