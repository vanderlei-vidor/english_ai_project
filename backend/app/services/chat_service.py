import os
import json
import time
import re
import requests
from dotenv import load_dotenv
from app.services.memory_utils import get_top_errors, get_top_topics
from app.services.exercise_engine import should_generate_exercise, choose_exercise_type

# Carrega as configurações do .env para não deixar nada hardcoded
load_dotenv()

LM_STUDIO_URL = os.getenv("LM_STUDIO_URL", "http://localhost:1234/v1/chat/completions")
MODEL_NAME = os.getenv("LM_STUDIO_MODEL", "qwen2.5-7b-instruct")

SYSTEM_INSTRUCTION = """
You are an expert, highly strict English tutor AI for a mobile language learning app. Always return a single, valid JSON object matching the requested schema.
CRITICAL: Never output any conversational text, greetings, markdown block ticks (like ```json), or explanations BEFORE or AFTER the JSON block.

CRITICAL CORRECTION AND GRADING RULES:
1. Analyze the VERY LAST user message in the conversation history for any grammatical, syntax, spelling, or structure errors.
2. Be extremely rigid! Casual spoken errors like "he don't" instead of "he doesn't", missing articles ("a", "an", "the"), or wrong prepositions MUST be caught.
3. If the user's sentence contains any mistake:
   - "correction": Provide the full, grammatically corrected sentence.
   - "explanation_pt": Explain the specific mistake and state the rule clearly in Portuguese.
   - "example": Provide a brand-new, clean example sentence demonstrating this correct rule.
4. If and ONLY if the user's sentence is 100% grammatically perfect:
   - You MUST return exactly: "correction": "Correct! ✨", "explanation_pt": "Sua frase está totalmente correta! Excelente trabalho. 🥳", and "example": "".
5. Never rewrite an already correct sentence into a different style. If it is correct, accept it.

EXERCISE FORMAT AUTHORITY:
The exercise MUST exactly follow the selected format and MUST be an unsolved challenge. NEVER provide the answer inside the exercise string.

- multiple_choice: MUST contain answer options.
  Valid: "Yesterday I _____ a new server. (a) buy (b) bought"
  Invalid: "Yesterday I bought a new server."

- fill_blank: MUST contain a blank space (_____) and NO options.
  Valid: "Yesterday I _____ to the repository."

- verb_transformation: Provide a sentence in the present/base form and ask the user to transform the specific verb. NEVER give the verb already transformed.
  Valid: "Change the verb to past tense: I (to deploy) the application yesterday."

- sentence_reordering: Provide shuffled words separated by slashes.
  Valid: "Reorder: yesterday / deployed / I / the / app"

- sentence_correction: Provide an incorrect sentence and ask them to fix it.
  Valid: "Correct the sentence: I code a new script yesterday."

ADAPTIVE LEARNING & THEME RULES:
- Focus the exercise and examples strictly on the requested "MANDATORY TARGET SKILL".
- Adapt all language complexity to the user's English level.
- Exercises MUST be contextually based on the "Exercise Theme". Do not create generic exercises.
  * If Theme is anime: use anime characters/plots (e.g., Naruto, Luffy, Konoha).
  * If Theme is technology: use software, AI, coding, servers, computers, or apps context. NEVER use anime characters or games here.
- "conversation_reply" MUST NEVER BE EMPTY. Always write a natural, friendly response in English reacting directly to the user's message.

Expected Output Format (Strict JSON):
{{
  "correction": "string",
  "explanation_pt": "string",
  "example": "string",
  "exercise": "string",
  "conversation_reply": "string"
}}
"""


def generate_response(messages: list, memory_data: dict) -> dict:
    # 1️⃣ Extração e tratamento seguro de dados da memória
    english_level = memory_data.get("english_level", "A2")

    favorite_topics = memory_data.get("favorite_topics", {})
    if not isinstance(favorite_topics, dict):
        favorite_topics = {}
    top_topics = get_top_topics(favorite_topics)
    theme = top_topics[0] if top_topics else "general"

    weak_skills = memory_data.get("weak_skills", {})
    if not isinstance(weak_skills, dict):
        weak_skills = {}
    top_weak_skills = get_top_errors(weak_skills)

    top_errors = get_top_errors(memory_data.get("common_errors", {}))
    exercise_focus = (
        top_weak_skills[0]
        if top_weak_skills
        else (top_errors[0] if top_errors else "past_tense")
    )

    exercise_type = choose_exercise_type(memory_data)
    exercise_required = len(weak_skills) > 0 or should_generate_exercise(memory_data)

    # 2️⃣ Geração inteligente e dinâmica de templates com base no TEMA real
    exercise_example = ""
    if theme == "technology":
        templates = {
            "multiple_choice": "Yesterday I _____ the code. (a) push (b) pushed",
            "fill_blank": "Yesterday the server _____ down unexpectedly.",
            "sentence_reordering": "Reorder: yesterday / deployed / I / the / app",
            "sentence_correction": "Correct the sentence: I code a new script yesterday.",
            "verb_transformation": "Change the verb to past tense: Python (to update) its libraries yesterday.",
        }
        exercise_example = templates.get(exercise_type, "")
    else:
        # Fallback padrão / Tema de Anime (Naruto)
        templates = {
            "multiple_choice": "Yesterday Naruto _____ to Konoha. (a) go (b) went",
            "fill_blank": "Yesterday Naruto _____ to Konoha.",
            "sentence_reordering": "Reorder: yesterday / Naruto / went / Konoha / to",
            "sentence_correction": "Correct the sentence: Naruto go to Konoha yesterday.",
            "verb_transformation": "Change the verb to past tense: Naruto (to go) to Konoha yesterday.",
        }
        exercise_example = templates.get(exercise_type, "")

    learning_profile = (
        f"casual learner interested in {', '.join(top_topics)}"
        if top_topics
        else "general English learner"
    )

    # 🔥 Mapeamento visual limpo para debug no console do backend
    print("\n=== DEBUG BACKEND DATA ===")
    print(f"LEVEL:         {english_level}")
    print(f"EXERCISE TYPE: {exercise_type}")
    print(f"THEME:         {theme}")
    print(f"TARGET SKILL:  {exercise_focus}")
    print(f"WEAK SKILLS:   {weak_skills}")
    print("==========================\n")

    # 3️⃣ Construção do bloco de contexto dinâmico (Injetado no Sistema)
    memory_context = f"""
### DYNAMIC USER CONTEXT ###
English Level: {english_level}
Exercise Format Required: {exercise_type}
MANDATORY EXERCISE FORMAT TEMPLATE: {exercise_example}
Learning Classification: {learning_profile}
Exercise Required Right Now: {"YES" if exercise_required else "NO"}

MANDATORY TARGET SKILL: {exercise_focus}
Weak Skills List: {", ".join(top_weak_skills) if top_weak_skills else "None"}
Most Frequent Mistakes: {", ".join(top_errors) if top_errors else "None"}

Exercise Theme: {theme}
Favorite Topics: {", ".join(top_topics) if top_topics else "None"}
Conversation Style: {memory_data.get("conversation_style", "casual")}
"""

    dynamic_system_instruction = (
        SYSTEM_INSTRUCTION.strip() + "\n" + memory_context.strip()
    )

    full_messages = [
        {"role": "system", "content": dynamic_system_instruction}
    ] + messages

    payload = {
        "model": MODEL_NAME,
        "messages": full_messages,
        "temperature": 0.2,
        "max_tokens": 600,
        #"response_format": {
         #   "type": "json_object"
       # },  # Força o Qwen 2.5 a responder em modo JSON nativo
    }

    # 4️⃣ Envio da Requisição com medição de performance
    try:
        print("=== SENDING TO LM STUDIO ===")
        start_time = time.time()
        response = requests.post(LM_STUDIO_URL, json=payload, timeout=45)

        if response.status_code != 200:
            return {
                "error": f"LM Studio error status: {response.status_code}",
                "raw": response.text,
            }

        elapsed = time.time() - start_time
        print(f"LM STUDIO RESPONSE TIME: {elapsed:.2f}s")
        result = response.json()

    except Exception as e:
        return {"error": f"Request failed: {str(e)}"}

    if not result or "choices" not in result:
        return {"error": "Invalid response structure from LM Studio", "raw": result}

    raw_text = result["choices"][0]["message"]["content"].strip()

    # 5️⃣ Extrator Regex Não-Guloso Avançado + Sanetização de Markdown
    # Remove cercas de código geradas acidentalmente antes de aplicar o regex
    clean_text = raw_text.replace("```json", "").replace("```", "").strip()

    json_match = re.search(r"(\{.*?\})", clean_text, re.DOTALL)
    if json_match:
        clean_text = json_match.group(1)

    # 6️⃣ Validação e Normalização do Dicionário de Saída
    try:
        response_json = json.loads(clean_text)

        # Garante fallbacks para chaves vazias ou ausentes
        if not response_json.get("conversation_reply"):
            response_json["conversation_reply"] = (
                "That's interesting! Let's keep practicing."
            )

        # Se a IA pulou a correção mas ela era necessária, ou se veio vazia por acerto:
        if not response_json.get("correction"):
            response_json["correction"] = "Correct! ✨"
            response_json["explanation_pt"] = (
                "Sua frase está totalmente correta! Excelente trabalho. 🥳"
            )
            response_json["example"] = ""

        elif response_json.get("correction") and not response_json.get(
            "explanation_pt"
        ):
            response_json["explanation_pt"] = (
                "Observe a estrutura acima para compreender a correção."
            )

        # Controla se o exercício deve ou não ser exibido ao usuário final
        if not exercise_required:
            response_json["exercise"] = ""
        else:
            exercise = response_json.get("exercise", "")
            if not isinstance(exercise, str) or exercise.strip() == "":
                response_json["exercise"] = f"Let's practice! {exercise_example}"

        return response_json

    except json.JSONDecodeError:
        # Recuperação graciosa de desastre (Garante que a conversa no Flutter não trave)
        print(f"❌ Erro Crítico de Parse no JSON. Texto Bruto: {raw_text}")
        return {
            "correction": "Correct! ✨",
            "explanation_pt": "Análise gramatical indisponível para esta mensagem.",
            "example": "",
            "exercise": "",
            "conversation_reply": raw_text
            if len(raw_text) < 150
            else "I understood you perfectly! Let's continue chatting.",
        }
