# Use NVIDIA CUDA base image
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Set non-interactive mode and labels
ENV DEBIAN_FRONTEND=noninteractive
LABEL maintainer="antigravity"

# Podržane arhitekture: 8.0 (A100), 8.6 (RTX 3090, A6000), 8.9 (L40S, RTX 4090), 9.0 (H100)
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV FORCE_CUDA="1"
ENV MAX_JOBS=4
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    python3.10 \
    python3-pip \
    python3-dev \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1-mesa-glx \
    libjpeg-dev \
    ninja-build \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set python3 as default python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch with CUDA 12.4 support
RUN pip install --no-cache-dir torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124

# Set working directory
WORKDIR /app

# Copy local code to the container
COPY . /app

# Initialize submodules if necessary (only if .git exists, otherwise assume code is present)
# access to .git might be restricted by .dockerignore, so better to clone specific submodules or rely on local checkout
# For simplicity, we just COPY everything. If submodules are needed, they should be checked out locally before build OR we clone them here.
# Let's assume the user has the code. But wait, submodules are tricky in COPY.
# Microsoft repo has `submodules`.
# Solution: Clone ONLY submodules or use recursive clone of upstream as fallback?
# Safer: Clone upstream to get submodules, then OVERWRITE with local code.
RUN git clone -b main https://github.com/microsoft/TRELLIS.2.git . && \
    git submodule update --init --recursive && \
    rm -rf .git

# Copy local changes (overwrites upstream code with our modified handler and potential fixes)
COPY . /app

# Install Python dependencies
RUN pip install --no-cache-dir imageio imageio-ffmpeg tqdm easydict opencv-python-headless trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard kornia timm runpod==1.7.7 requests Pillow boto3 packaging ninja

# Install EasternJournalist/utils3d
RUN pip install --no-cache-dir git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8

# --- Specialized CUDA extensions (MOVED TO RUNTIME) ---
# To allow building on standard CI runners, we skip heavy compilations here.
# They will be installed by start.sh on the powerful GPU instance.

RUN echo "CUDA extensions will be installed at runtime."

# Copy the RunPod handler
COPY runpod_handler.py /app/runpod_handler.py

# Set environment variables
ENV PYTHONPATH="/app"
ENV PYTHONUNBUFFERED=1

# Run handler
# Make runtime script executable
RUN chmod +x runtime_install.sh

# Start with runtime installation wrapper
CMD ["bash", "runtime_install.sh"]
