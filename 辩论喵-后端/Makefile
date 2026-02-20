.PHONY: run migrate test lint

run:
	uv run uvicorn app.main:app --reload --port 8000

migrate:
	uv run alembic upgrade head

test:
	uv run pytest

lint:
	uv run ruff check .
