from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes.chat import router as chat_router
from app.routes.user import router as user_router

# Customização dos metadados da API para o Swagger Docs (/docs)
app = FastAPI(
    title="English AI Backend",
    description="API Engine para o aplicativo de aprendizado de inglês impulsionado por IA.",
    version="1.0.0",
)

# 🌐 CONFIGURAÇÃO DE CORS (Crucial para o Flutter se conectar)
# Permite que o seu app mobile ou web faça requisições para a API sem tomar bloqueio de segurança
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "*"
    ],  # Em produção, você pode trocar ["*"] pelas URLs específicas do seu app
    allow_credentials=True,
    allow_methods=["*"],  # Permite GET, POST, PUT, DELETE, etc.
    allow_headers=["*"],  # Permite qualquer cabeçalho (como tokens de autenticação)
)

# 📁 INCLUSÃO DAS ROTAS ORGANIZADAS
# O prefix ajuda a versionar a API e as tags separam os blocos organizadamente no /docs
app.include_router(chat_router, tags=["Chat & AI Interaction"])
app.include_router(user_router, tags=["User Management & Leagues"])


@app.get("/", tags=["System Health"])
def root():
    return {"status": "online", "message": "English AI Backend Running Successfully"}
