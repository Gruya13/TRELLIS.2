import time
import subprocess
import requests
import os

# Konfiguracija
IDLE_THRESHOLD_MINUTES = 30
VRAM_IDLE_THRESHOLD_MB = 1000  # Ako je zauzeće VRAM-a manje od 1GB, smatra se da je idle
API_KEY = os.environ.get("RUNPOD_API_KEY")
POD_ID = os.environ.get("RUNPOD_POD_ID")

def get_vram_usage():
    try:
        result = subprocess.check_output(['nvidia-smi', '--query-gpu=memory.used', '--format=csv,nounits,noheader'])
        return int(result.decode('utf-8').strip())
    except Exception as e:
        print(f"Greška pri čitanju GPU: {e}")
        return 99999 # Ne gasi ako ne možeš da pročitaš

def terminate_self():
    print("Inaktivnost detektovana. Gasim instancu...")
    url = f"https://api.runpod.io/g6/stable-diffusion/v1/pods/{POD_ID}/terminate"
    headers = {"Authorization": f"Bearer {API_KEY}"}
    requests.post(url, headers=headers)

idle_time = 0
while True:
    vram = get_vram_usage()
    if vram < VRAM_IDLE_THRESHOLD_MB:
        idle_time += 1
    else:
        idle_time = 0 # Resetuj tajmer ako se GPU koristi
        
    if idle_time >= IDLE_THRESHOLD_MINUTES:
        terminate_self()
        break
        
    time.sleep(60) # Proveravaj svake minute
