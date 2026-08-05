# docker-ci-lab

Proyecto mínimo para practicar **CI + gate de CVEs + webhook de deploy** (mismo patrón que Coolify, pero el “deploy” lo simulamos con [webhook.site](https://webhook.site)).

## Qué incluye

- NestJS chico con `GET /api/health`
- Nest **pineado a 11.1.28** (versión sin CVEs fixeables; antes estaba en 11.1.12 a propósito para ver el gate cortar)
- Dockerfile multi-stage + `HEALTHCHECK` a `/api/health`
- Runner sin `npm` ni `yarn` (ver "Endurecimiento del runner")
- GitHub Actions: build → **Trivy** (Critical/High *fixeables*) → `curl` al webhook

## Endurecimiento del runner

El primer run del CI falló con **1 Critical + 12 High fixeables**, que venían de dos lugares distintos:

| Origen | Paquetes | Cómo se arregla |
|---|---|---|
| Dependencias de la app | `multer 2.0.2`, `path-to-regexp 8.3.0` | subir `@nestjs/*` a 11.1.28 (trae `multer 2.2.0` y `path-to-regexp 8.4.2`) |
| `npm`/`yarn` incluidos en `node:22-slim` | `tar` (el Critical), `brace-expansion`, `sigstore`, `picomatch`, `ip-address` | borrarlos del runner |

Lo segundo es lo interesante: esos paquetes viven en `/usr/local/lib/node_modules/npm`, no en tu
código. Como el contenedor arranca con `node dist/main.js`, npm y yarn nunca se usan en runtime,
así que se eliminan en la etapa runner. El escaneo pasó de 426 a 240 paquetes y de 13 CVEs a 0.

Ojo con una trampa: `docker images` sigue mostrando casi el mismo tamaño, porque borrar en una capa
posterior no achica las capas anteriores — solo oculta los archivos en el filesystem final. Alcanza
para el scanner (que lee el filesystem final), pero si querés bajar el peso real necesitás otra base.

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
