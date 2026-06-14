import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

load_dotenv()  # ← ESSA LINHA É FUNDAMENTAL

DATABASE_URL = os.getenv("DATABASE_URL")

# ⚡ OTIMIZAÇÃO: pool_pre_ping impede erros de conexões derrubadas por ociosidade (idle timeouts)
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()
