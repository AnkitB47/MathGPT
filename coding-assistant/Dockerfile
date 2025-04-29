# ── STAGE 1: build venv & deps ────────────────────────────────────────
FROM python:3.10-slim AS builder
WORKDIR /app

ENV PIP_NO_CACHE_DIR=1 PIP_DEFAULT_TIMEOUT=1000

# build-time deps
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3-venv python3-pip build-essential ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# create & populate venv
RUN python3 -m venv /venv \
 && /venv/bin/pip install --upgrade pip

COPY requirements.txt .
# install torch+cpu fallback to GPU wheels
RUN /venv/bin/pip install \
      torch torchvision torchaudio \
      --index-url https://download.pytorch.org/whl/cu118 --no-cache-dir \
 && /venv/bin/pip install -r requirements.txt --no-cache-dir

# ── STAGE 2: runtime with CUDA libs ───────────────────────────────────
FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04
WORKDIR /app

# copy venv
COPY --from=builder /venv /venv

# copy just your app & adapters
COPY app.py coding_agent.py ./

# bake in your fine-tuned QLoRA adapters:
COPY output/qlora-deepseek/adapters /app/output/qlora-deepseek/adapters

ENV PATH="/venv/bin:$PATH" \
    HF_HOME=/app/hf_cache \
    TRANSFORMERS_CACHE=/app/cache \
    PYTHONUNBUFFERED=1

EXPOSE 8501
CMD ["streamlit","run","app_full.py","--server.port=8501","--server.address=0.0.0.0"]
