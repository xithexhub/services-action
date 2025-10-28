# Xithex Services Action

Composite GitHub Action for Xithex self-hosted runners that starts ephemeral
PostgreSQL and Redis containers via Podman. It replaces the legacy
`nix-services-action` so our CI pipelines stay Nix-free.

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

## Requirements

- Self-hosted runner with Podman and `ss` installed (our standard pool already
  provides both).
- The runner user must be able to run `podman` without `sudo`.

## Cleanup

Containers are automatically removed in the final step of the action (`if:
always()`), even if earlier steps fail.
