import gradio as gr
import requests
import base64
import time
import os
from PIL import Image
from io import BytesIO

# --- KONFIGURACIJA ---
RUNPOD_ENDPOINT_ID = "tvoj_endpoint_id"
RUNPOD_API_KEY = "tvoj_api_key"

def generate_3d(image, seed, ss_guidance, ss_steps, slat_guidance, slat_steps, texture_size):
    if image is None:
        return None, "Molim vas, otpremite sliku."
    
    # 1. Konvertuj sliku u base64
    buffered = BytesIO()
    image.save(buffered, format="PNG")
    img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
    
    # 2. Pošalji zahtev RunPod-u
    url = f"https://api.runpod.ai/v2/{RUNPOD_ENDPOINT_ID}/run"
    headers = {
        "Authorization": f"Bearer {RUNPOD_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "input": {
            "image": img_str,
            "seed": seed,
            "ss_guidance_scale": ss_guidance,
            "ss_steps": ss_steps,
            "slat_guidance_scale": slat_guidance,
            "slat_steps": slat_steps,
            "texture_size": texture_size
        }
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers)
        job_id = response.json().get("id")
        
        if not job_id:
            return None, f"Greška: {response.text}"
        
        status_url = f"https://api.runpod.ai/v2/{RUNPOD_ENDPOINT_ID}/status/{job_id}"
        
        while True:
            status_response = requests.get(status_url, headers=headers)
            status_data = status_response.json()
            
            if status_data["status"] == "COMPLETED":
                output = status_data["output"]
                if "glb_url" in output:
                    glb_res = requests.get(output["glb_url"])
                    with open("latest_output.glb", "wb") as f:
                        f.write(glb_res.content)
                    return "latest_output.glb", f"Gotovo! (Seed: {seed})"
                elif "glb_b64" in output:
                    glb_data = base64.b64decode(output["glb_b64"])
                    with open("latest_output.glb", "wb") as f:
                        f.write(glb_data)
                    return "latest_output.glb", f"Gotovo! (Seed: {seed})"
                return None, "Nema izlaza."
            
            elif status_data["status"] == "FAILED":
                return None, f"Greška: {status_data.get('error')}"
            
            time.sleep(2)
            
    except Exception as e:
        return None, f"Greška: {str(e)}"

# --- PRO GRADIO UI ---
with gr.Blocks(title="TRELLIS.2 Master") as demo:
    gr.Markdown("# 🏆 TRELLIS.2 PRO Kontrolni Panel")
    
    with gr.Row():
        with gr.Column(scale=1):
            input_img = gr.Image(type="pil", label="Ulazna slika")
            
            with gr.Accordion("Napredna podešavanja", open=False):
                seed = gr.Number(value=-1, label="Seed", precision=0, info="Seme (Seed) omogućava ponavljanje iste generacije. -1 za nasumično.")
                ss_guidance = gr.Slider(1.0, 15.0, value=7.5, step=0.5, label="SS Guidance Scale", info="Skala vođenja strukture. Veće vrednosti vernije prate oblik ulazne slike.")
                ss_steps = gr.Slider(1, 50, value=12, step=1, label="SS Steps", info="Broj koraka za generisanje osnovne strukture (Sparse Structure).")
                slat_guidance = gr.Slider(1.0, 10.0, value=3.0, step=0.5, label="SLAT Guidance Scale", info="Skala vođenja detalja i tekstura.")
                slat_steps = gr.Slider(1, 50, value=12, step=1, label="SLAT Steps", info="Broj koraka za generisanje detaljnih latentsa (Structured Latent).")
                tex_size = gr.Radio([1024, 2048, 4096], value=2048, label="Rezolucija tekstura", info="Veličina izlaznih tekstura u pikselima.")
            
            btn = gr.Button("GENERISI 3D MODEL", variant="primary")
            
        with gr.Column(scale=1):
            output_3d = gr.Model3D(label="3D Rezultat")
            status_text = gr.Textbox(label="Info o procesu")

    btn.click(
        fn=generate_3d, 
        inputs=[input_img, seed, ss_guidance, ss_steps, slat_guidance, slat_steps, tex_size], 
        outputs=[output_3d, status_text]
    )

if __name__ == "__main__":
    demo.launch()
