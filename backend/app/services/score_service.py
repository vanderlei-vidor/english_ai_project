import json
import re


def calculate_score(messages):
    total_user_messages = 0
    errors = 0

    for i in range(len(messages) - 1):
        current_msg = messages[i]
        next_msg = messages[i + 1]

        if current_msg.sender == "user" and next_msg.sender == "ai":
            total_user_messages += 1

            try:
                # ⚡ Blindagem contra vazamento de texto da IA nos logs históricos
                raw_content = next_msg.content.strip()
                json_match = re.search(r"(\{.*\}).*", raw_content, re.DOTALL)
                clean_text = json_match.group(1) if json_match else raw_content

                ai_json = json.loads(clean_text)
                correction = ai_json.get("correction")

                # 🚨 CORREÇÃO CRÍTICA: Ignora a nossa string de sucesso "Correct! ✨"
                # Só computa erro se o campo tiver um erro real apontado pela IA
                if correction and correction != "" and "Correct!" not in correction:
                    errors += 1

            except Exception:
                # Se o JSON estiver completamente corrompido, não pune o usuário
                pass

    if total_user_messages == 0:
        return 100

    accuracy = 100 - int((errors / total_user_messages) * 100)
    return max(0, accuracy)


def calculate_global_score(progress_records):
    if not progress_records:
        return 0

    total = sum(p.score for p in progress_records)
    return int(total / len(progress_records))


def get_level(score: int):
    if score < 40:
        return {"code": "A1", "label": "Beginner"}
    elif score < 60:
        return {"code": "A2", "label": "Elementary"}
    elif score < 75:
        return {"code": "B1", "label": "Intermediate"}
    elif score < 85:
        return {"code": "B2", "label": "Upper Intermediate"}
    elif score < 95:
        return {"code": "C1", "label": "Advanced"}
    else:
        return {"code": "C2", "label": "Proficient"}


def get_next_level(current_score: int):
    # Faixas de pontuação: (Mínimo para entrar, Código do Nível, Alvo para o Próximo)
    levels = [
        (0, "A1", 40),
        (40, "A2", 60),
        (60, "B1", 75),
        (75, "B2", 85),
        (85, "C1", 95),
        (95, "C2", 100),
    ]

    for min_score, code, next_threshold in levels:
        if current_score < next_threshold:
            # ⚡ MATEMÁTICA PRECISA: Calcula o progresso relativo DENTRO do nível atual
            range_size = next_threshold - min_score
            user_progress = current_score - min_score

            # Evita divisões por zero e garante valores consistentes
            progress = int((user_progress / range_size) * 100) if range_size > 0 else 0

            return {
                "target_level": code,
                "required_score": next_threshold,
                "progress_percentage": min(max(progress, 0), 100),
            }

    return {"target_level": "C2", "required_score": 100, "progress_percentage": 100}
