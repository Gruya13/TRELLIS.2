#!/bin/bash
set -e

echo "🚀 Započinjem automatizovanu instalaciju TRELLIS.2 na RunPod..."

# 1. Ulazak u workspace i kloniranje
cd /workspace
if [ ! -d "TRELLIS.2" ]; then
    git clone https://github.com/Gruya13/TRELLIS.2.git
fi
cd TRELLIS.2

# 2. Kreiranje venv-a (Čista instalacija)
if [ -d "venv" ]; then
    echo "🗑️ Brišem staro virtuelno okruženje..."
    rm -rf venv
fi

echo "📦 Kreiram novo virtuelno okruženje..."
python -m venv venv
source venv/bin/activate

# 3. Instalacija sistemskih zavisnosti (za svaki slučaj)
apt-get update && apt-get install -y ffmpeg libsm6 libxext6 libgl1 libjpeg-dev ninja-build wget

# 4. Instalacija PyTorch-a i osnovnih paketa
echo "🔥 Podešavam zavisnosti..."
pip install --upgrade pip
pip install setuptools wheel

# Koristimo TMPDIR na istom disku (workspace) da izbegnemo Cross-device link error
mkdir -p /workspace/tmp
export TMPDIR=/workspace/tmp

# Instalacija zavisnosti (bez forsiranja stare verzije torcha ako već postoji noviji)
pip install imageio imageio-ffmpeg tqdm easydict opencv-python-headless trimesh transformers gradio==6.0.1 tensorboard pandas lpips zstandard kornia timm runpod==1.7.7 requests Pillow boto3 packaging ninja

# 5. Instalacija CUDA ekstenzija
echo "🛠️ Kompajliram CUDA ekstenzije..."
export TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"
export MAX_JOBS=4

# Specifična instalacija flash-attn preko gotovog wheel-a da izbegnemo build probleme
echo "--- flash-attn ---"
pip install flash_attn-2.7.3+cu12torch2.6cxx11abiFALSE-cp312-cp312-linux_x86_64.whl || \
pip install https://github.com/Dao-AILab/flash-attention/releases/download/v2.7.3/flash_attn-2.7.3+cu12torch2.6cxx11abiFALSE-cp312-cp312-linux_x86_64.whl

echo "--- nvdiffrast ---"
git clone https://github.com/NVlabs/nvdiffrast.git /tmp/nvdiffrast || true
pip install /tmp/nvdiffrast --no-build-isolation

echo "--- nvdiffrec ---"
git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git /tmp/nvdiffrec || true
pip install /tmp/nvdiffrec --no-build-isolation

echo "--- CuMesh ---"
git clone --recursive https://github.com/JeffreyXiang/CuMesh.git /tmp/CuMesh || true
cd /tmp/CuMesh
export NVCC_APPEND_FLAGS="--extended-lambda"
export NVCC_PREPEND_FLAGS="--extended-lambda"
pip install . -v --no-cache-dir --no-build-isolation
cd /workspace/TRELLIS.2

echo "--- FlexGEMM ---"
git clone --recursive https://github.com/JeffreyXiang/FlexGEMM.git /tmp/FlexGEMM || true
pip install /tmp/FlexGEMM --no-build-isolation

echo "--- o-voxel ---"
pip install ./o-voxel --no-build-isolation

# 6. Preuzimanje modela
echo "🧠 Preuzimam i čuvam model weights na mrežni disk..."
mkdir -p /workspace/weights
python -c "
import os
from trellis2.pipelines import Trellis2ImageTo3DPipeline
path = '/workspace/weights/TRELLIS.2-4B'
if not os.path.exists(path):
    pipeline = Trellis2ImageTo3DPipeline.from_pretrained('microsoft/TRELLIS.2-4B')
    pipeline.save_pretrained(path)
    print('Model uspešno sačuvan na volume!')
else:
    print('Model već postoji na volume-u.')
"

echo "✅ SVE JE SPREMNO!"
echo "Sada možeš zatvoriti ovaj Pod i napraviti Serverless Endpoint."
