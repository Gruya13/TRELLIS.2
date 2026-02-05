# Use NVIDIA CUDA base image
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Set non-interactive mode and labels
ENV DEBIAN_FRONTEND=noninteractive
LABEL maintainer="antigravity"

# Optimization for RunPod GPUs (A100, RTX 30/40, H100)
# This ensures CUDA kernels are pre-compiled for these architectures
ENV TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"
ENV FORCE_CUDA="1"
ENV MAX_JOBS=1

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

# Copy specialized local packages if any (o-voxel is in subfolder)
# Install EasternJournalist/utils3d
RUN pip install git+https://github.com/EasternJournalist/utils3d.git@9a4eb15e4021b67b12c460c7057d642626897ec8

# --- Install specialized CUDA extensions ---

# 1. flash-attn
# Pre-downloading packaging and ninja which are often required for flash-attn
RUN pip install packaging ninja
# Using MAX_JOBS=1 to avoid OOM on CI runners during compilation
RUN MAX_JOBS=1 pip install flash-attn==2.7.3 --no-build-isolation

# 2. nvdiffrast
RUN git clone https://github.com/NVlabs/nvdiffrast.git /tmp/nvdiffrast && \
    pip install /tmp/nvdiffrast --no-build-isolation

# 3. nvdiffrec (renderutils branch as per setup.sh)
RUN git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git /tmp/nvdiffrec && \
    pip install /tmp/nvdiffrec --no-build-isolation

# 4. CuMesh
RUN git clone --recursive https://github.com/JeffreyXiang/CuMesh.git /tmp/CuMesh && \
    pip install /tmp/CuMesh --no-build-isolation

# 5. FlexGEMM
RUN git clone --recursive https://github.com/JeffreyXiang/FlexGEMM.git /tmp/FlexGEMM && \
    pip install /tmp/FlexGEMM --no-build-isolation

# 6. o-voxel (using the one in the repo)
RUN pip install ./o-voxel --no-build-isolation

# Copy the RunPod handler
COPY runpod_handler.py /app/runpod_handler.py

# Pre-download models to the Docker image (optional but recommended for fast start)
# This will trigger the download during build phase
RUN python3 -c "from trellis2.pipelines import Trellis2ImageTo3DPipeline; Trellis2ImageTo3DPipeline.from_pretrained('microsoft/TRELLIS.2-4B')"

# Set environment variables
ENV PYTHONPATH="/app:${PYTHONPATH}"
ENV PYTHONUNBUFFERED=1

# Run handler
CMD ["python", "runpod_handler.py"]
