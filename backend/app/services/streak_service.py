from datetime import date, timedelta


def check_and_clean_streak(streak_record, user_today: date = None):
    """
    Rode esta função SEMPRE que o usuário carregar o perfil ou abrir o app.
    Ela limpa o 'Streak Fantasma' caso o usuário tenha ficado dias sem jogar,
    sem esperar que ele faça um exercício para só então resetar.
    """
    if user_today is None:
        user_today = date.today()  # Fallback para a data do servidor

    if not streak_record.last_study_date:
        return streak_record

    # Se o último dia de estudo foi ANTES de ontem, a ofensiva já quebrou!
    yesterday = user_today - timedelta(days=1)
    if streak_record.last_study_date < yesterday:
        streak_record.current_streak = 0
        # NOTA: Mantém o 'longest_streak' intacto porque é o recorde dele!

    return streak_record


def update_streak(streak_record, user_today: date = None):
    """
    Rode esta função APENAS quando o usuário concluir um exercício com sucesso.
    """
    if user_today is None:
        user_today = date.today()

    # 1. Primeira vez na vida que estuda
    if not streak_record.last_study_date:
        streak_record.current_streak = 1
        streak_record.longest_streak = 1
        streak_record.last_study_date = user_today
        return streak_record

    # 2. Se já estudou hoje, não faz nada (proteção contra duplo clique)
    if streak_record.last_study_date == user_today:
        return streak_record

    # 3. Se estudou ontem → continua e esquenta a ofensiva
    yesterday = user_today - timedelta(days=1)
    if streak_record.last_study_date == yesterday:
        streak_record.current_streak += 1

        if streak_record.current_streak > streak_record.longest_streak:
            streak_record.longest_streak = streak_record.current_streak
    else:
        # 4. Se quebrou (segurança caso a função de checagem não tenha rodado)
        streak_record.current_streak = 1

    # Atualiza o carimbo para o dia atual do usuário
    streak_record.last_study_date = user_today

    return streak_record
