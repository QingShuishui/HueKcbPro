FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml /app/pyproject.toml
COPY app /app/app
COPY site /app/site
COPY alembic.ini /app/alembic.ini
COPY alembic /app/alembic
COPY README.md /app/README.md
RUN pip install --no-cache-dir .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
