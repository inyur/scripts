#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/include.bash"

if [[ $# -lt 1 ]]; then
  log_error "Usage: $0 <kubesecret name>"
  exit 1
fi

KUBE_SECRET="$1"
shift || true

kubectl get secret ${KUBE_SECRET} -o json | jq '.data | map_values(@base64d)'
