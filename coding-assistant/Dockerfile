# ── ALL IN ONE: CUDA + Python + venv + RETRYABLE PIP ─────────────────
FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

# 1) Install Python3.10, venv, dev headers, pip, build tools, certs
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3.10 \
      python3.10-venv \
      python3.10-dev \
      python3-distutils \
      python3-pip \
      build-essential \
      ca-certificates \
 && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
 && rm -rf /var/lib/apt/lists/*

# 2) Create & activate a venv at /venv
RUN python3 -m venv /venv --copies \
 && /venv/bin/pip install --upgrade pip

# 3) Make pip fast & retry on failures
ENV PATH="/venv/bin:${PATH}" \
    PIP_NO_CACHE_DIR=1 \
    PIP_DEFAULT_TIMEOUT=120 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# 4) Install CUDA-compatible PyTorch first, then your other deps
COPY requirements.txt .
RUN pip install \
      --retries 10 \
      --timeout 120 \
      --no-cache-dir \
      torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/cu118

RUN pip install \
      --retries 10 \
      --timeout 120 \
      --no-cache-dir \
      -r requirements.txt

# 5) Copy your code & adapters
COPY app.py coding_agent.py ./
COPY output/qlora-deepseek/adapters /app/output/qlora-deepseek/adapters

# 6) Expose port & launch
EXPOSE 8501
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
