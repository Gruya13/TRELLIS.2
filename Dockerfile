# Use NVIDIA CUDA base image
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Set non-interactive mode and labels
ENV DEBIAN_FRONTEND=noninteractive
LABEL maintainer="antigravity"

# REDUKOVANO: Samo A100 (8.0) arhitektura da bi build prošao na slabom CI serveru
ENV TORCH_CUDA_ARCH_LIST="8.0"
ENV FORCE_CUDA="1"
ENV MAX_JOBS=1
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

# Clone TRELLIS.2 repository
RUN git clone -b main https://github.com/microsoft/TRELLIS.2.git . && \
    git submodule update --init --recursive

# Install Python dependencies
RUN pip install --no-cache-dir imageio imageio-ffmpeg tqdm easydict opencv-python-headless trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard kornia timm runpod==1.7.7 requests Pillow boto3 packaging ninja

# Install EasternJournalist/utils3d
RUN pip install --no-cache-dir git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8

# --- Install specialized CUDA extensions ---

# 1. flash-attn
RUN MAX_JOBS=1 pip install --no-cache-dir flash-attn==2.7.3 --no-build-isolation

# 2. nvdiffrast
RUN git clone https://github.com/NVlabs/nvdiffrast.git /tmp/nvdiffrast && \
    cd /tmp/nvdiffrast && MAX_JOBS=1 pip install . --no-cache-dir --no-build-isolation && rm -rf /tmp/nvdiffrast

# 3. nvdiffrec
RUN git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git /tmp/nvdiffrec && \
    cd /tmp/nvdiffrec && MAX_JOBS=1 pip install . --no-cache-dir --no-build-isolation && rm -rf /tmp/nvdiffrec

# 4. CuMesh - Dodate verbose komande za debug
RUN git clone --recursive https://github.com/JeffreyXiang/CuMesh.git /tmp/CuMesh && \
    cd /tmp/CuMesh && \
    export NVCC_FLAGS="--extended-lambda" && \
    MAX_JOBS=1 pip install . -v --no-cache-dir --no-build-isolation && \
    rm -rf /tmp/CuMesh

# 5. FlexGEMM
RUN git clone --recursive https://github.com/JeffreyXiang/FlexGEMM.git /tmp/FlexGEMM && \
    cd /tmp/FlexGEMM && MAX_JOBS=1 pip install . --no-cache-dir --no-build-isolation && rm -rf /tmp/FlexGEMM

# 6. o-voxel
RUN cd /app && MAX_JOBS=1 pip install ./o-voxel --no-cache-dir --no-build-isolation

# Copy the RunPod handler
COPY runpod_handler.py /app/runpod_handler.py

# Set environment variables
ENV PYTHONPATH="/app"
ENV PYTHONUNBUFFERED=1

# Run handler
CMD ["python", "runpod_handler.py"]
