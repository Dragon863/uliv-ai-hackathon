FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000 \
    MEADOW_DATA_FILE=/data/jobs.json

WORKDIR /app

RUN useradd --system --create-home --uid 10001 meadow \
    && mkdir -p /data \
    && chown meadow:meadow /data

COPY --chown=meadow:meadow server.py /app/server.py

USER meadow

EXPOSE 8000

CMD ["python", "server.py"]
