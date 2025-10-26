#!/usr/bin/env bash
source "$(dirname "$(readlink -f "$0")")/include.bash"

if [[ $# -lt 1 ]]; then
  log_error "Usage: $0 <path to git repo>"
  exit 1
fi

GIT_REPO_PATH="$1"
shift || true

GIT_REPO_PATH="$(cd "$(pwd)/${GIT_REPO_PATH}" && pwd)";

cd "${GIT_REPO_PATH}";

git remote set-url origin "$(git remote get-url origin | sed -E 's#https://([^/]+)/([^/]+)/([^/]+)#git@\1:\2/\3#')"
