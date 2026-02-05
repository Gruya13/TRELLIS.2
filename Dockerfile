# Use NVIDIA CUDA base image
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Set non-interactive mode and labels
ENV DEBIAN_FRONTEND=noninteractive
LABEL maintainer="antigravity"

# Optimization for RunPod GPUs (A100, RTX 30/40, H100)
ENV TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"
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
RUN pip install --upgrade pip

# Install PyTorch with CUDA 12.4 support
RUN pip install torch==2.6.0 torchvision==0.21.0 --index-url https://download.pytorch.org/whl/cu124

# Set working directory
WORKDIR /app

# Clone TRELLIS.2 repository
RUN git clone -b main https://github.com/microsoft/TRELLIS.2.git . && \
    git submodule update --init --recursive

# Install Python dependencies
RUN pip install imageio imageio-ffmpeg tqdm easydict opencv-python-headless trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard kornia timm runpod==1.7.7 requests Pillow boto3

# Install EasternJournalist/utils3d
RUN pip install git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8

# --- Install specialized CUDA extensions ---
# We use a single RUN command to keep the image clean and avoid intermediate layers hitting disk limits
RUN pip install packaging ninja setuptools wheel && \
    # 1. flash-attn
    MAX_JOBS=1 pip install flash-attn==2.7.3 --no-build-isolation && \
    # 2. nvdiffrast
    git clone https://github.com/NVlabs/nvdiffrast.git /tmp/nvdiffrast && \
    cd /tmp/nvdiffrast && MAX_JOBS=1 pip install . --no-build-isolation && \
    # 3. nvdiffrec
    git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git /tmp/nvdiffrec && \
    cd /tmp/nvdiffrec && MAX_JOBS=1 pip install . --no-build-isolation && \
    # 4. CuMesh
    git clone --recursive https://github.com/JeffreyXiang/CuMesh.git /tmp/CuMesh && \
    cd /tmp/CuMesh && NVCC_FLAGS="--extended-lambda" MAX_JOBS=1 pip install . --no-build-isolation && \
    # 5. FlexGEMM
    git clone --recursive https://github.com/JeffreyXiang/FlexGEMM.git /tmp/FlexGEMM && \
    cd /tmp/FlexGEMM && MAX_JOBS=1 pip install . --no-build-isolation && \
    # 6. o-voxel
    cd /app && MAX_JOBS=1 pip install ./o-voxel --no-build-isolation && \
    # Clean up /tmp to save space
    rm -rf /tmp/*

# Copy the RunPod handler
COPY runpod_handler.py /app/runpod_handler.py

# --- IMPORTANT CHANGE ---
# We are REMOVING the pre-download from the Dockerfile build process.
# GitHub Actions runners only have ~14GB of free space.
# 16GB of weights PLUS Docker layers exceeds this limit, causing the build to fail.
# Instead, the handler will download the weights on the FIRST run or use a Network Volume.

# Set environment variables
ENV PYTHONPATH="/app"
ENV PYTHONUNBUFFERED=1

# Run handler
CMD ["python", "runpod_handler.py"]
