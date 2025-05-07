# ── STAGE 1: build venv & deps ────────────────────────────────────────
FROM python:3.10-slim AS builder
WORKDIR /app

# build-time dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3-venv build-essential ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# create & populate a self-contained venv
RUN python3 -m venv /venv --copies \
 && /venv/bin/pip install --upgrade pip

COPY requirements.txt .
# install CUDA-compatible PyTorch and your other Python deps
RUN /venv/bin/pip install \
      torch torchvision torchaudio \
      --index-url https://download.pytorch.org/whl/cu118 \
 && /venv/bin/pip install -r requirements.txt

# ── STAGE 2: runtime with CUDA libs ───────────────────────────────────
FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

# ensure a fallback system Python exists in case any scripts still require it
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# copy the fully self-contained venv from builder
COPY --from=builder /venv /venv

# copy your application code and any adapters
COPY app.py coding_agent.py ./  
COPY output/qlora-deepseek/adapters /app/output/qlora-deepseek/adapters

# so that "/venv/bin/streamlit" and "/venv/bin/python3" are on PATH
ENV PATH="/venv/bin:${PATH}" \
    HF_HOME=/app/hf_cache \
    TRANSFORMERS_CACHE=/app/cache \
    PYTHONUNBUFFERED=1

EXPOSE 8501

# launch your Streamlit app
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
