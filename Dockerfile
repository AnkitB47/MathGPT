# Stage 1: Build image
FROM python:3.10-slim AS build

WORKDIR /app

# Set environment variables
ENV TRANSFORMERS_CACHE=/app/cache \
    HF_HOME=/app/hf_cache \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=off \
    PIP_DEFAULT_TIMEOUT=1000 \
    PIP_RETRIES=25 \
    PATH="/venv/bin:$PATH"

# Install system dependencies for building
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl ca-certificates libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set up virtual environment and upgrade pip
RUN python3 -m venv /venv && \
    /venv/bin/pip install --upgrade pip

# Install PyTorch (CPU version)
RUN /venv/bin/pip install torch torchvision torchaudio --no-cache-dir

# Install app dependencies
COPY requirements.txt .
RUN /venv/bin/pip install -r requirements.txt

# Stage 2: Runtime image
FROM python:3.10-slim

WORKDIR /app

# Copy the virtual environment from the build stage
COPY --from=build /venv /venv

# Copy the rest of the application code
COPY . .

# Set environment variables
ENV TRANSFORMERS_CACHE=/app/cache \
    HF_HOME=/app/hf_cache \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=off \
    PIP_DEFAULT_TIMEOUT=1000 \
    PIP_RETRIES=25 \
    PATH="/venv/bin:$PATH"

# Expose the port for Streamlit
EXPOSE 8501

# Run Streamlit
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
