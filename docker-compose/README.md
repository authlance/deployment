# Duna Local Stack (Docker Compose)

This stack bootstraps MySQL, ORY Kratos + Hydra (migrations then services + Kratos courier), and the backend services (authlance + licenseoperator). The Loop/SaaS web tier now runs on the host but shares the same configs and databases rendered from this compose folder, so everything stays in sync via the `.env`.

## What this provides
- Centralized configuration via `.env`
- Templates for ORY Kratos/Hydra and application configs rendered with environment variables
- Proper startup order: MySQL → templates → Kratos migrate → Kratos serve (+ courier) → Hydra migrate → Hydra serve → app services
- Health checks for MySQL, Kratos, and Hydra

## Prerequisites
- Docker Desktop with Compose v2
- macOS/Linux (commands use POSIX shell)
- S3-compatible storage for file uploads (MinIO, AWS S3, etc.)
- Stripe account for subscription management and webhooks

## Quick start
1. Copy `.env.template` to `.env`. Override secrets and other values as needed:
   ```bash
   cp .env.template .env
   ```
2. (Optional but recommended) Register the Stripe webhook before the stack starts so the backend already listens to the right events:
   - Render the application config volume. This populates `app_auth_config` (mounted as `/app/config/config.yaml` inside the auth container):
     ```bash
     docker compose run --rm ory-templates
     ```
   - Run the webhook helper inside the auth image while mounting that rendered config:
     ```bash
     docker compose run --rm --no-deps authlance ./authlance stripe-webhook --config /app/config/config.yaml
     ```
     The command creates the required webhook subscriptions and prints the webhook secret **only** when a webhook is created. If the webhook already exists, retrieve the secret from your Stripe dashboard. Running this helper later is safe; it simply ensures the webhook listens to the required events.
3. Start the backend stack (MySQL + ORY + auth + licenseoperator + nginx):
   ```bash
   ./start.sh
   ```
4. Run the Loop/Scaffold app on your host (outside Docker) using the same DSN/NATS credentials from `.env` so it can talk to the containers. A typical `.env.local` section for Loop looks like:
   ```env
   DATABASE_URL=mysql://duna:secret1234@127.0.0.1:3307/duna-loop
   NATS_URL=nats://localhost:4222
   ```
5. Access the stack via nginx once the containers are healthy.

Services will be available on:
- MySQL: localhost:3307
- Aggregator nginx: HTTP 8080, HTTPS 8443 (configurable)
  - Override the published ports by editing `NGINX_LOCAL_PORT` and `NGINX_HTTPS_PORT` in `.env` before running `./start.sh`.

Kratos and Hydra are internal-only (no host ports published).

## Template rendering
The `ory-templates` job renders templates from `./templates` into named volumes using `envsubst`, driven entirely by `.env`. Rendered outputs are mounted by Kratos, Hydra, and the application services.

Template inputs:
- ORY Kratos: `templates/ory/kratos/kratos.yml.template`, `identity.schema.json.template`, `mail.api.request.jsonnet.template`, `register.api.request.jsonnet.template`
- ORY Hydra:  `templates/ory/hydra/config.yaml.template`

Rendered to named volumes:
- Kratos → `ory_kratos_config` mounted at `/etc/kratos`
- Hydra  → `ory_hydra_config` mounted at `/etc/hydra`

Update `.env` to customize values (DSN, URLs, secrets, mail sender, webhooks, etc.).

## Application config templates
Besides ORY, the stack also templates application configs. These are rendered and mounted as read-only volumes, and each service points to the rendered file.

Templates:
- Authlance (backend/auth): `templates/app/auth/config.yaml.template` → rendered to `app_auth_config` volume and mounted at `/config/auth/config.yaml`
- Licenseoperator: `templates/app/license/config.yaml.template` (+ `trialLicense`) → rendered to `app_license_config` volume and mounted at `/config/license/config.yaml`
- Loop scaffold: `templates/app/loop-scaffold/config.json.template` is provided for convenience; render it manually with `envsubst` when you need to refresh the host app config (Compose does not run this template automatically).

Drive all values via `.env`. Common keys include database DSNs/creds, seeded admin user info, service URLs, JWT/secrets, Stripe, NATS, S3, license files, and CORS origins shared with the host Loop app.

Authlance looks for `/app/config/authlance.lic` inside its container. Drop your license file at `deployment/docker-compose/licenses/authlance.lic` (or point `AUTH_LICENSE_FILE` to another path) before running `./start.sh`; the `ory-templates` job copies it into the rendered config volume automatically.

### Loop/SaaS outside Docker
- The Loop scaffold is intentionally not part of this compose stack to keep frontend iteration fast.
- Point it at the compose MySQL (`localhost:3307`) and NATS (`localhost:4222`) using the credentials already exported in `deployment/docker-compose/.env`.
- Run `envsubst < templates/app/loop-scaffold/config.json.template > loop-scaffold/app-config.json` from this `deployment/docker-compose` directory whenever you change `.env` to keep the host config in sync (or copy/paste values manually). Copy the rendered `loop-scaffold/app-config.json` to where you run the Loop app is up to you (locally, another container, etc.).
- Hydra runs with the `--dev` flag so HTTP issuer URLs work locally; never use this compose stack as-is in production. To run in production, deploy each component separately with hardened configs and TLS.

## One-command startup
Use the provided helper script to bring the backend stack up:

```bash
./start.sh
```

What it does:
- Ensures `.env` exists (copies from `.env.template` if missing)
- Pulls required images (controlled via `.env`)
- Brings the stack up in the correct order (MySQL → templates → ORY migrations → services → apps)

To re-render templates without restarting everything:

```bash
docker compose up --no-deps --force-recreate ory-templates
```

To get fresh configs into the running app containers after changing `.env` or any template:
1. Stop the services that consume the config volumes (typically auth and license):
   ```bash
   docker compose stop authlance licenseoperator
   ```
2. Re-render the templates as shown above.
3. Start the services again so they remount the updated files:
   ```bash
   docker compose up -d authlance licenseoperator
   ```

To stop the stack:

```bash
docker compose down
```

## HTTPS (TLS) for nginx proxy
The aggregator nginx supports TLS termination.

- Place your certificate and key in `./nginx/certs/` named `server.crt` and `server.key`.
- HTTPS is exposed on `${NGINX_HTTPS_PORT:-8443}` (defaults to 8443), HTTP on `${NGINX_LOCAL_PORT:-8080}`.
- HTTP requests are redirected to HTTPS by default.

Create a self-signed certificate for local development:

openssl req -x509 -newkey rsa:2048 -keyout deployment/docker-compose/nginx/certs/server.key -out deployment/docker-compose/nginx/certs/server.crt -sha256 -days 365 -nodes -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

Or use mkcert (browser-trusted locally):

mkcert -install
mkcert localhost 127.0.0.1 ::1
mv localhost+2-key.pem deployment/docker-compose/nginx/certs/server.key
mv localhost+2.pem deployment/docker-compose/nginx/certs/server.crt

## Routing map (via nginx)

These routes are aligned with `proxy/cmd/proxy/config/config.yaml`:

- `/` → loop-scaffold (Loop React) service 
- `/authlance/loop` → loop-scaffold (Loop Express backend) service
- `/authlance/license` → License operator service
- `/authlance` → Auth service

Notes:
- Kratos and Hydra endpoints are not exposed through nginx and have no host ports. They are only reachable by other services in the Docker network.
- Public access should go through HTTPS on `${NGINX_HTTPS_PORT:-8443}`; HTTP on `${NGINX_LOCAL_PORT:-8080}` redirects to HTTPS.
