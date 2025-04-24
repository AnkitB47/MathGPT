FROM ubuntu:22.04

WORKDIR /app

# Environment variables
ENV TRANSFORMERS_CACHE=/app/cache \
    HF_HOME=/app/hf_cache \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=off \
    PIP_DEFAULT_TIMEOUT=1000 \
    PIP_RETRIES=25 \
    PATH="/venv/bin:$PATH"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-dev python3.10-venv \
    git build-essential cmake curl \
    libgl1-mesa-glx libglib2.0-0 ca-certificates software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Set up virtual environment and pip
RUN python3 -m venv /venv && \
    . /venv/bin/activate && \
    pip install --upgrade pip && \
    pip config set global.timeout 1000 && \
    pip config set global.retries 25

# Install PyTorch with fallback (GPU version first, fallback to CPU)
RUN /venv/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 || \
    /venv/bin/pip install torch torchvision torchaudio

# Install app requirements
COPY requirements.txt .
RUN /venv/bin/pip install -r requirements.txt

# Copy source code
COPY . .

# Expose port for Streamlit
EXPOSE 8501

# Run Streamlit
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
