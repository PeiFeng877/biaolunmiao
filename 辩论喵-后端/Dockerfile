FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV HTTP_PROXY=
ENV HTTPS_PROXY=
ENV http_proxy=
ENV https_proxy=
ENV ALL_PROXY=
ENV all_proxy=
ENV NO_PROXY=
ENV no_proxy=

WORKDIR /app

COPY app /app/app
COPY alembic /app/alembic
COPY alembic.ini /app/alembic.ini
COPY scripts /app/scripts

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN pip install --isolated --no-cache-dir \
  "fastapi>=0.115.0" \
  "uvicorn[standard]>=0.30.0" \
  "sqlalchemy>=2.0.36" \
  "alembic>=1.14.0" \
  "psycopg2-binary>=2.9.10" \
  "python-jose[cryptography]>=3.3.0" \
  "passlib[bcrypt]>=1.7.4" \
  "pydantic-settings>=2.6.1" \
  "python-multipart>=0.0.20"

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
