#!/bin/bash
set -e

echo ">>> Starting Runtime Installation of CUDA Extensions..."

# 1. flash-attn
if ! python -c "import flash_attn" 2>/dev/null; then
    echo "Installing flash-attn..."
    MAX_JOBS=4 pip install flash-attn==2.7.3 --no-build-isolation
fi

# 2. nvdiffrast
if ! python -c "import nvdiffrast" 2>/dev/null; then
    echo "Installing nvdiffrast..."
    if [ ! -d "/tmp/nvdiffrast" ]; then
        git clone https://github.com/NVlabs/nvdiffrast.git /tmp/nvdiffrast
    fi
    cd /tmp/nvdiffrast && MAX_JOBS=4 pip install . --no-build-isolation
fi

# 3. nvdiffrec (renderutils)
if ! python -c "import nvdiffrec" 2>/dev/null; then
    echo "Installing nvdiffrec..."
    if [ ! -d "/tmp/nvdiffrec" ]; then
        git clone -b renderutils https://github.com/JeffreyXiang/nvdiffrec.git /tmp/nvdiffrec
    fi
    cd /tmp/nvdiffrec && MAX_JOBS=4 pip install . --no-build-isolation
fi

# 4. CuMesh
if ! python -c "import cumesh" 2>/dev/null; then
    echo "Installing CuMesh..."
    if [ ! -d "/tmp/CuMesh" ]; then
        git clone --recursive https://github.com/JeffreyXiang/CuMesh.git /tmp/CuMesh
    fi
    cd /tmp/CuMesh
    export NVCC_FLAGS="--extended-lambda"
    MAX_JOBS=4 pip install . -v --no-build-isolation
fi

# 5. FlexGEMM
if ! python -c "import flexgemm" 2>/dev/null; then
    echo "Installing FlexGEMM..."
    if [ ! -d "/tmp/FlexGEMM" ]; then
        git clone --recursive https://github.com/JeffreyXiang/FlexGEMM.git /tmp/FlexGEMM
    fi
    cd /tmp/FlexGEMM && MAX_JOBS=4 pip install . --no-build-isolation
fi

# 6. o-voxel (local package)
if ! python -c "import o_voxel" 2>/dev/null; then
    echo "Installing o-voxel..."
    cd /app && MAX_JOBS=4 pip install ./o-voxel --no-build-isolation
fi

echo ">>> All CUDA extensions installed successfully!"

# Start the main handler
exec python /app/runpod_handler.py
