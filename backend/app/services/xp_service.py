import math


def calculate_xp(score: int, had_error: bool, current_streak: int) -> int:
    xp = 5  # XP Base por simplesmente tentar e enviar a mensagem

    # 🎯 Ajuste de Precisão utilizando o score que estava esquecido
    if score == 100:
        xp += 15  # Bônus de mestre: Resposta perfeita!
    elif not had_error:
        xp += 10  # Resposta correta padrão
    else:
        xp += 2  # Teve erros, mas ganha um incentivo por ter tentado

    # 🚨 TETO DE SEGURANÇA (Anti-Inflação):
    # Limita o bônus de streak a no máximo +10 ou +15 XP para não quebrar a árvore de níveis
    # se o usuário tiver uma ofensiva gigantesca (ex: 200 dias).
    streak_bonus = min(current_streak, 10)
    xp += streak_bonus

    return xp


def xp_needed_for_level(level: int) -> int:
    if level <= 1:
        return 0
    return int(100 * ((level - 1) ** 2))


def get_level_from_xp(total_xp: int):
    # Garante que o XP não seja negativo por segurança
    total_xp = max(0, total_xp)

    # ⚡ OTIMIZAÇÃO MATEMÁTICA: Aplica a operação inversa da fórmula quadrática.
    # Em vez de um loop 'while', descobrimos o nível exato com uma raiz quadrada!
    # Fórmula inversa: level = 1 + sqrt(total_xp / 100)
    level = int(1 + math.sqrt(total_xp / 100))

    current_level_xp_floor = xp_needed_for_level(level)
    next_level_xp = xp_needed_for_level(level + 1)

    xp_into_level = total_xp - current_level_xp_floor
    xp_required_this_level = next_level_xp - current_level_xp_floor

    # Evita divisão por zero se houver alguma inconsistência
    if xp_required_this_level > 0:
        progress_percentage = int((xp_into_level / xp_required_this_level) * 100)
    else:
        progress_percentage = 0

    return {
        "level": level,
        "current_xp": total_xp,
        "next_level_xp": next_level_xp,
        "progress_percentage": min(max(progress_percentage, 0), 100),
    }
