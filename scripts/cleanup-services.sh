#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${STATE_FILE:-}"

if [[ -z "$STATE_FILE" || ! -f "$STATE_FILE" ]]; then
  exit 0
fi

while IFS= read -r container; do
  [[ -z "$container" ]] && continue
  podman rm -f "$container" >/dev/null 2>&1 || true
done < "$STATE_FILE"
