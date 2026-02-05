---
description: Kako build-ovati i deploy-ovati TRELLIS.2 na RunPod Serverless
---

Ovaj vofkflow objašnjava korake za pakovanje TRELLIS.2 modela u Docker i njegovo postavljanje na RunPod.

### 1. Build Docker image-a
Pošto je Dockerfile spreman, pokreni build komandu. Zameni `tvoj-username` svojim Docker Hub korisničkim imenom.

```bash
docker build -t tvoj-username/trellis2-runpod:latest .
```

### 2. Push na Docker Hub
Nakon uspešnog build-a, pošalji image na registry:

```bash
docker push tvoj-username/trellis2-runpod:latest
```

### 3. Podešavanje na RunPod-u
1. Idi na [RunPod Console](https://www.runpod.io/console/serverless).
2. Klikni na **"Endpoints"** -> **"New Endpoint"**.
3. Unesi ime endpoint-a (npr. `trellis2-api`).
4. U polje **"Container Image"** unesi `tvoj-username/trellis2-runpod:latest`.
5. Izaberi GPU (preporučeno: **A100** ili **L40/L4** za optimalne performanse).
6. U sekciji **"Environment Variables"**, dodaj sledeće ključeve da bi S3 radio:
   - `S3_ACCESS_KEY_ID`: Tvoj Access Key.
   - `S3_SECRET_ACCESS_KEY`: Tvoj Secret Key.
   - `S3_BUCKET_NAME`: Ime bucket-a.
   - `S3_ENDPOINT_URL`: URL tvog provider-a (npr. za Cloudflare R2 ili MinIO).
   - `S3_REGION`: Region (opciono, default je `us-east-1`).
7. Podesi **"Active Workers"** na 0 i **"Max Workers"** po potrebi.
8. Klikni na **"Create"**.

### 4. Testiranje API-ja
Kada endpoint postane aktivan, možeš mu poslati zahtev:

```json
{
  "input": {
    "image": "https://example.com/slika.png",
    "texture_size": 2048
  }
}
```

Endpoint će vratiti `glb` kao base64 string koji možeš sačuvati kao `.glb` fajl.
