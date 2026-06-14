from sqlalchemy import Column, Integer, String, JSON
from app.core.database import Base


class UserMemory(Base):
    __tablename__ = "user_memory"

    id = Column(Integer, primary_key=True)
    user_id = Column(String, unique=True)
    data = Column(JSON)


# O Dicionário de tópicos pode ficar aqui ou em um arquivo de constantes
TOPICS_DATABASE = {
    "technology": ["ai", "technology", "computer"],
    "games": ["game", "games", "minecraft"],
    "anime": ["anime", "naruto", "one piece"],
    "books": ["book", "reading", "author"],
}
