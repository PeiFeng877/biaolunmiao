.PHONY: run migrate test lint seed reset-data reset-and-seed

run:
	uv run uvicorn app.main:app --reload --port 8000

migrate:
	uv run alembic upgrade head

test:
	uv run pytest

lint:
	uv run ruff check .

seed:
	uv run python -m scripts.seed_data --mode seed

reset-data:
	uv run python -m scripts.seed_data --mode reset

reset-and-seed:
	uv run python -m scripts.seed_data --mode reset-seed
