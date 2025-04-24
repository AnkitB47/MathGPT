FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

WORKDIR /app

# Set environment
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH \
    CUDA_VERSION=11.8 \
    TRANSFORMERS_CACHE=/app/cache \
    HF_HOME=/app/hf_cache \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=off \
    PIP_DEFAULT_TIMEOUT=1000 \
    PIP_RETRIES=25 \
    PATH="/venv/bin:$PATH"

# Install system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-dev python3.10-venv \
    git build-essential cmake curl \
    libgl1-mesa-glx libglib2.0-0 ca-certificates software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment and configure pip
RUN python3 -m venv /venv && \
    . /venv/bin/activate && \
    pip install --upgrade pip && \
    pip config set global.timeout 1000 && \
    pip config set global.retries 25

# Install PyTorch (GPU version)
RUN /venv/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# Copy and install app requirements (including bitsandbytes here!)
COPY requirements.txt .
RUN /venv/bin/pip install -r requirements.txt

# Copy app source
COPY . .

EXPOSE 8501

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
