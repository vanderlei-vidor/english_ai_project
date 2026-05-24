from sqlalchemy import Column, String, Integer, ForeignKey
from app.core.database import Base
import uuid


class Progress(Base):
    __tablename__ = "progress"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    conversation_id = Column(String, ForeignKey("conversations.id"), nullable=False)
    score = Column(Integer, nullable=False)