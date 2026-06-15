# === Stage 1: Build & Dependências ===
FROM python:3.11-slim AS builder

WORKDIR /app

# Instalar dependências do sistema se necessário (psycopg2-binary geralmente não precisa de build-essential, 
# mas se precisasse, instalaríamos aqui e removeríamos depois)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copiar apenas os requisitos para aproveitar o cache de camadas do Docker
COPY requirements.txt .

# Instalar as dependências gerando wheels em um diretório temporário para otimizar o tamanho final
RUN pip install --no-cache-dir --user -r requirements.txt


# === Stage 2: Runtime Final (Imagem Limpa e Segura) ===
FROM python:3.11-slim AS runner

WORKDIR /app

# Garantir que o path dos pacotes do usuário instalados no stage anterior esteja visível
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# Variáveis de ambiente exigidas pelo runtime do Lift (Placeholders/Defaults)
ENV DATABASE_URL="postgresql://user:password@localhost:5432/lift_db"
ENV API_KEY="replace_me_in_production_cluster"

# Criar um usuário não-root (non-root) para segurança (atendendo ao compliance do Strickland)
RUN useradd -u 10001 -m appuser

# Copiar os pacotes instalados do estágio de build para o usuário local
COPY --from=builder /root/.local /home/appuser/.local

# Copiar apenas o código necessário da aplicação (ignora o /tests devido ao .dockerignore)
COPY app.py .
COPY lib/ ./lib/

# Ajustar permissões da pasta de trabalho para o usuário não-root
RUN chown -R appuser:appuser /app

# Mudar explicitamente para o usuário não-root antes de rodar a aplicação
USER 10001

# Expor a porta interna documentada do Lift
EXPOSE 8080

# Comando de inicialização homologado para produção na Hill Valley Tech
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "app:app"]