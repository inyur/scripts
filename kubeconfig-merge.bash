#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/include.bash"

if [[ $# -lt 1 ]]; then
  log_error "Usage: $0 <path to kubeconfig>"
  exit 1
fi

KUBE_CONFIG="$1"
shift || true

if ! [ -e "${KUBE_CONFIG}" ]; then
  log_error "${KUBE_CONFIG} file not found"
fi

TMP_CONFIG=$(mktemp)

KUBECONFIG=~/.kube/config:${KUBE_CONFIG}

kubectl config view --flatten > ${TMP_CONFIG}

mv "${TMP_CONFIG}" ~/.kube/config

log_done "${KUBE_CONFIG} merged successfully"
