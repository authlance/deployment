#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "No .env found. Creating from .env.template..."
  cp .env.template .env
  echo "Edit .env with your settings, then re-run this script."
fi

COMPOSE_FILES="-f docker-compose.yml"

for arg in "$@"; do
  if [ "$arg" == "--expose-ory" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.expose-ory.yml"
  fi
  if [ "$arg" == "--enable-oidc" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.oidc.yml"
  fi
done

echo "Rendering and starting stack..."
docker compose $COMPOSE_FILES pull --ignore-pull-failures
docker compose $COMPOSE_FILES up -d

echo "Stack starting. Health checks:"
KRATOS_ADMIN_PORT=${KRATOS_ADMIN_PORT:-4434}
HYDRA_ADMIN_PORT=${HYDRA_ADMIN_PORT:-4445}
MYSQL_LOCAL_PORT=${MYSQL_LOCAL_PORT:-3307}
echo "- Kratos admin: http://localhost:${KRATOS_ADMIN_PORT}/health/ready"
echo "- Hydra admin:  http://localhost:${HYDRA_ADMIN_PORT}/health/ready"
echo "- MySQL:        127.0.0.1:${MYSQL_LOCAL_PORT}"
