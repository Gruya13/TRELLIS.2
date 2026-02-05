import os
import torch
import cv2
import imageio
import base64
import runpod
import requests
import boto3
from botocore.exceptions import NoCredentialsError
from PIL import Image
from io import BytesIO
from trellis2.pipelines import Trellis2ImageTo3DPipeline
from trellis2.utils import render_utils
from trellis2.renderers import EnvMap
import o_voxel
import numpy as np

# Set environment variables for GPU optimization
os.environ['OPENCV_IO_ENABLE_OPENEXR'] = '1'
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"

# Global variables for model caching
pipeline = None
envmap = None

# Configurable model path (can be a Network Volume or local path)
DEFAULT_MODEL_PATH = os.environ.get('MODEL_PATH', 'microsoft/TRELLIS.2-4B')

# S3 Configuration from Environment Variables
S3_ACCESS_KEY = os.environ.get('S3_ACCESS_KEY_ID')
S3_SECRET_KEY = os.environ.get('S3_SECRET_ACCESS_KEY')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
S3_ENDPOINT_URL = os.environ.get('S3_ENDPOINT_URL') # Optional for R2/B2/MinIO
S3_REGION = os.environ.get('S3_REGION', 'us-east-1')

def upload_to_s3(file_data, file_name, content_type='application/octet-stream'):
    if not all([S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET_NAME]):
        print("S3 credentials not fully provided. Skipping upload.")
        return None

    try:
        s3 = boto3.client(
            's3',
            aws_access_key_id=S3_ACCESS_KEY,
            aws_secret_access_key=S3_SECRET_KEY,
            endpoint_url=S3_ENDPOINT_URL,
            region_name=S3_REGION
        )
        s3.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=file_name,
            Body=file_data,
            ContentType=content_type
        )
        
        # Generate URL
        if S3_ENDPOINT_URL:
            url = f"{S3_ENDPOINT_URL.rstrip('/')}/{S3_BUCKET_NAME}/{file_name}"
        else:
            url = f"https://{S3_BUCKET_NAME}.s3.{S3_REGION}.amazonaws.com/{file_name}"
        return url
    except Exception as e:
        print(f"Error uploading to S3: {e}")
        return None

def load_models():
    global pipeline, envmap
    if pipeline is None:
        print(f"Loading TRELLIS.2-4B model from {DEFAULT_MODEL_PATH}...")
        pipeline = Trellis2ImageTo3DPipeline.from_pretrained(DEFAULT_MODEL_PATH)
        pipeline.cuda()
    
    if envmap is None:
        print("Loading environment map...")
        # Note: You might want to provide a default HDRI or download one
        # For now, we'll create a neutral one or use the one from assets if available
        hdri_path = 'assets/hdri/forest.exr'
        if os.path.exists(hdri_path):
            hdri = cv2.imread(hdri_path, cv2.IMREAD_UNCHANGED)
            hdri = cv2.cvtColor(hdri, cv2.COLOR_BGR2RGB)
        else:
            # Create a simple white environment if none exists
            hdri = np.ones((512, 1024, 3), dtype=np.float32)
            
        envmap = EnvMap(torch.tensor(hdri, dtype=torch.float32, device='cuda'))

def handler(job):
    """
    RunPod handler function
    Input: { "input": { "image": "base64_string_or_url", "texture_size": 4096 } }
    """
    job_input = job["input"]
    image_src = job_input.get("image")
    texture_size = job_input.get("texture_size", 2048) # Default to 2048 for better performance on serverless
    
    if not image_src:
        return {"error": "No image input provided"}

    try:
        # 1. Load Image
        if image_src.startswith("http"):
            response = requests.get(image_src)
            image = Image.open(BytesIO(response.content))
        else:
            image_data = base64.b64decode(image_src)
            image = Image.open(BytesIO(image_data))
        
        load_models()

        # 2. Run Inference
        print("Generating 3D model...")
        outputs = pipeline.run(image)
        mesh = outputs[0]
        mesh.simplify(16777216) # nvdiffrast limit

        # 3. Export to GLB
        print("Exporting GLB...")
        glb = o_voxel.postprocess.to_glb(
            vertices            =   mesh.vertices,
            faces               =   mesh.faces,
            attr_volume         =   mesh.attrs,
            coords              =   mesh.coords,
            attr_layout         =   mesh.layout,
            voxel_size          =   mesh.voxel_size,
            aabb                =   [[-0.5, -0.5, -0.5], [0.5, 0.5, 0.5]],
            decimation_target   =   1000000,
            texture_size        =   texture_size,
            remesh              =   True,
            remesh_band         =   1,
            remesh_project      =   0,
            verbose             =   False
        )
        
        glb_data = BytesIO()
        glb.export(glb_data, format='glb', extension_webp=True)
        glb_bytes = glb_data.getvalue()

        # 4. Handle Output (S3 or Base64)
        result = {}
        file_name = f"output_{job['id']}.glb"
        
        s3_url = upload_to_s3(glb_bytes, file_name, 'model/gltf-binary')
        if s3_url:
            result["glb_url"] = s3_url
        else:
            # Fallback to base64 if S3 is not configured or fails
            result["glb_b64"] = base64.b64encode(glb_bytes).decode('utf-8')

        return result

    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    load_models() # Warm up the model on start
    runpod.serverless.start({"handler": handler})
