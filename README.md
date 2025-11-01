# Xithex Services Action

Composite GitHub Action for Xithex self-hosted runners that starts ephemeral
PostgreSQL and Redis containers via Podman. It replaces the legacy
Nix-based services action so our CI pipelines stay Nix-free.

## Usage

```yaml
- uses: xithexhub/services-action@v1
  id: services
  with:
    services: postgresql redis
# Environment variables (DATABASE_URL, REDIS_URL, etc.) are exported automatically.
```

The action exposes the following outputs (in addition to exporting the matching
environment variables for subsequent steps):

| Output            | Description                               |
| ----------------- | ----------------------------------------- |
| `database-url`    | PostgreSQL connection string              |
| `postgres-port`   | Host port allocated for PostgreSQL        |
| `redis-url`       | Redis connection string                   |
| `redis-port`      | Host port allocated for Redis             |
| `network`         | Podman network the containers joined      |
| `postgres-container` | Name of the PostgreSQL container       |
| `redis-container` | Name of the Redis container               |

### Inputs

| Input               | Default   | Description                                      |
| ------------------- | --------- | ------------------------------------------------ |
| `services`          | _(none)_  | Whitespace/comma separated list of services      |
| `postgres-version`  | `16`      | Container tag for PostgreSQL                     |
| `postgres-port`     | `55432`   | Base host port (auto-increments if already used) |
| `postgres-password` | `postgres`| Password for the `postgres` user                 |
| `redis-version`     | `7-alpine`| Container tag for Redis                          |
| `redis-port`        | `16379`   | Base host port (auto-increments if already used) |
| `network`           | _(empty)_ | Optional Podman network to join                  |

### Resource limits

PostgreSQL and Redis containers are started with sensible memory caps so they
cannot OOM the runner host. Override these limits by exporting environment
variables before the action step:

| Environment variable           | Default | Description                                         |
| ------------------------------ | ------- | --------------------------------------------------- |
| `POSTGRES_MEMORY_LIMIT`        | `1g`    | Podman `--memory` limit for the PostgreSQL service  |
| `POSTGRES_MEMORY_SWAP_LIMIT`   | _none_  | Optional Podman `--memory-swap` value               |
| `REDIS_MEMORY_LIMIT`           | `256m`  | Podman `--memory` limit for the Redis service       |
| `REDIS_MEMORY_SWAP_LIMIT`      | _none_  | Optional Podman `--memory-swap` value               |

## Requirements

- Self-hosted runner with Podman and `ss` installed (our standard pool already
  provides both).
- The runner user must be able to run `podman` without `sudo`.

## Cleanup

The action records container names (and the optional network) in
`SERVICES_ACTION_STATE_FILE`. Use the accompanying `scripts/cleanup-services.sh`
helper (or your own teardown logic) to remove them once they are no longer
needed.
