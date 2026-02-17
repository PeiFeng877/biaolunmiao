.PHONY: run migrate test lint

run:
	uvicorn app.main:app --reload --port 8000

migrate:
	alembic upgrade head

test:
	pytest

lint:
	ruff check .
