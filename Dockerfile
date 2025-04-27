# ── STAGE 1: build venv & deps ────────────────────────────────────────────────
FROM python:3.10-slim AS builder
WORKDIR /app

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DEFAULT_TIMEOUT=1000

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates build-essential \
 && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /venv \
 && /venv/bin/pip install --upgrade pip

COPY requirements.txt .
RUN /venv/bin/pip install \
      torch torchvision torchaudio --no-cache-dir \
 && /venv/bin/pip install -r requirements.txt

# ── STAGE 2: package runtime ─────────────────────────────────────────────────
FROM python:3.10-slim
WORKDIR /app

# bring in the venv
COPY --from=builder /venv /venv

# copy *all* your application files
COPY . .

ENV PATH="/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

EXPOSE 8501

CMD ["streamlit", "run", "app.py", \
     "--server.port=8501", "--server.address=0.0.0.0"]
