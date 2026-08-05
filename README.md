# docker-ci-lab

Proyecto mínimo para practicar **CI + gate de CVEs + webhook de deploy** (mismo patrón que Coolify, pero el “deploy” lo simulamos con [webhook.site](https://webhook.site)).

## Qué incluye

- NestJS chico con `GET /api/health`
- Nest **pineado a 11.1.12** (misma familia de CVEs que viste en `ticzar-tickets-api`)
- Dockerfile multi-stage + `HEALTHCHECK` a `/api/health`
- GitHub Actions: build → **Trivy** (Critical/High *fixeables*) → `curl` al webhook

## Pasos (vos)

### 1. Crear repo vacío en GitHub
Ej: `docker-ci-lab` (público o privado).

### 2. Init y push (desde esta carpeta)

```bash
cd ~/Documents/siltium/docker-ci-lab
git init
git add .
git commit -m "chore: lab CI CVE gate + health endpoint"
git branch -M main
git remote add origin git@github.com:TU_USER/docker-ci-lab.git
git push -u origin main
```

### 3. webhook.site
1. Abrí https://webhook.site
2. Copiá tu URL única
3. En el repo de GitHub → **Settings → Secrets and variables → Actions**
4. Secret `DEPLOY_WEBHOOK` = esa URL

### 4. Ver el flujo
Cualquier push a `main` o `qa` corre el workflow.

- Si Trivy encuentra Critical/High **con fix** → job rojo → **no** llama al webhook  
- Si pasa → ves el POST en webhook.site

### 5. Probar en local (opcional)

```bash
npm ci
npm run start:dev
# http://localhost:4000/api/health

docker build -t docker-ci-lab:local .
docker run --rm -p 4000:4000 docker-ci-lab:local
```

## Nota sobre Scout vs Trivy

En local usaste `docker scout`. En CI usamos **Trivy** porque no requiere login a Docker Hub y el gate (`--exit-code` / Critical+High fixeables) es el mismo concepto. Después podés cambiar el secret a un webhook real de Coolify/Dokploy sin tocar la lógica.
