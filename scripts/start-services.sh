#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[services-action] %s\n' "$*" >&2
}

die() {
  printf '[services-action] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found in PATH"
}

find_free_port() {
  local start_port=$1
  local port="$start_port"
  while ss -ltn "( sport = :$port )" >/dev/null 2>&1; do
    port=$((port + 1))
    if (( port > 65535 )); then
      die "No available ports starting from $start_port"
    fi
  done
  printf '%s' "$port"
}

write_env() {
  local key=$1
  local value=$2
  printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
}

append_output() {
  local key=$1
  local value=$2
  printf '%s=%s\n' "$key" "$value" >> "$OUTPUT_FILE"
}

ensure_env_files() {
  : > "$STATE_FILE"
  : > "$ENV_FILE"
  : > "$OUTPUT_FILE"
}

start_postgresql() {
  local version="${POSTGRES_VERSION:-16}"
  local base_port="${POSTGRES_PORT_BASE:-55432}"
  local password="${POSTGRES_PASSWORD:-postgres}"
  local host_port
  host_port=$(find_free_port "$base_port")

  local container="xithex-${GITHUB_RUN_ID:-manual}-${GITHUB_JOB:-job}-postgres"
  log "Starting PostgreSQL ($version) as container $container on port $host_port"

  podman rm -f "$container" >/dev/null 2>&1 || true

  local run_args=(
    --detach
    --name "$container"
    --env "POSTGRES_PASSWORD=$password"
    --env "POSTGRES_USER=postgres"
    --env "POSTGRES_DB=postgres"
    --publish "${host_port}:5432"
  )

  if [[ -n "${NETWORK:-}" ]]; then
    run_args+=(--network "$NETWORK")
  fi

  podman run "${run_args[@]}" "docker.io/library/postgres:${version}" \
    -c listen_addresses='*' \
    -c max_connections=200 >/dev/null

  echo "$container" >> "$STATE_FILE"

  for attempt in {1..30}; do
    if podman exec "$container" pg_isready -U postgres >/dev/null 2>&1; then
      break
    fi
    sleep 2
    if (( attempt == 30 )); then
      podman logs "$container" || true
      die "PostgreSQL container failed to become ready"
    fi
  done

  local url="postgresql://postgres:${password}@127.0.0.1:${host_port}/postgres"
  write_env DATABASE_URL "$url"
  write_env PGHOST 127.0.0.1
  write_env PGUSER postgres
  write_env PGPASSWORD "$password"
  write_env PGPORT "$host_port"

  append_output database-url "$url"
  append_output postgres-port "$host_port"
}

start_redis() {
  local version="${REDIS_VERSION:-7-alpine}"
  local base_port="${REDIS_PORT_BASE:-16379}"
  local host_port
  host_port=$(find_free_port "$base_port")

  local container="xithex-${GITHUB_RUN_ID:-manual}-${GITHUB_JOB:-job}-redis"
  log "Starting Redis ($version) as container $container on port $host_port"

  podman rm -f "$container" >/dev/null 2>&1 || true

  local run_args=(
    --detach
    --name "$container"
    --publish "${host_port}:6379"
  )

  if [[ -n "${NETWORK:-}" ]]; then
    run_args+=(--network "$NETWORK")
  fi

  podman run "${run_args[@]}" "docker.io/library/redis:${version}" >/dev/null

  echo "$container" >> "$STATE_FILE"

  for attempt in {1..30}; do
    if podman exec "$container" redis-cli ping >/dev/null 2>&1; then
      break
    fi
    sleep 2
    if (( attempt == 30 )); then
      podman logs "$container" || true
      die "Redis container failed to become ready"
    fi
  done

  local url="redis://127.0.0.1:${host_port}/0"
  write_env REDIS_URL "$url"
  write_env CACHE_URL "redis://127.0.0.1:${host_port}/1"
  write_env CELERY_BROKER_URL "redis://127.0.0.1:${host_port}/2"
  write_env CELERY_RESULT_BACKEND "redis://127.0.0.1:${host_port}/3"

  append_output redis-url "$url"
  append_output redis-port "$host_port"
}

main() {
  require_command podman
  require_command ss

  if [[ -z "${REQUESTED_SERVICES:-}" ]]; then
    die "No services requested. Provide at least one service name."
  fi

  ensure_env_files

  local requested normalised
  requested=$(echo "$REQUESTED_SERVICES" | tr ',' ' ')

  for svc in $requested; do
    normalised=$(echo "$svc" | tr '[:upper:]' '[:lower:]')
    case "$normalised" in
      postgres|postgresql)
        start_postgresql
        ;;
      redis)
        start_redis
        ;;
      "")
        ;;
      *)
        die "Unsupported service '$svc'. Supported services: postgresql, redis"
        ;;
    esac
  done
}

main "$@"
