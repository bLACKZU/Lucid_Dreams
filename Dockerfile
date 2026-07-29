# syntax=docker/dockerfile:1

FROM python:3.13-slim AS builder

RUN python -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH

COPY app/requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

FROM python:3.13-slim

ENV PATH=/opt/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY app/app.py .

USER 65532

EXPOSE 8080

CMD ["python", "app.py"]
