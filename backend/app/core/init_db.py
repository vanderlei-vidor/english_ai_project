from app.core.database import engine, Base

# 🔥 IMPORT DE TODOS OS MODELOS DO SEU APP (Crucial para o SQLAlchemy criar as tabelas)
from app.models.user import User
from app.models.conversation import Conversation
from app.models.message import Message
from app.models.progress import Progress
from app.models.user_memory import UserMemory
from app.models.badge import Badge
from app.models.streak import Streak
from app.models.system_state import SystemState
from app.models.user_badge import UserBadge
from app.models.weekly_results import WeeklyResult
from app.models.weekly_xp import WeeklyXP
from app.models.xp import XP
from app.models.league_history import LeagueHistory


def init():
    print("⏳ Conectando e criando tabelas no PostgreSQL...")
    Base.metadata.create_all(bind=engine)
    print("🔥 Todas as tabelas foram criadas com sucesso no banco!")


if __name__ == "__main__":
    init()
