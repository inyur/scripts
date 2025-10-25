#!/usr/bin/env bash
# ============================================================
# Git Submodule Helper Script
# ------------------------------------------------------------
# Этот скрипт инициализирует и обновляет git submodules.
# Предназначен для включения в скрипт make.sh в корне репы

: <<'PARENT_SCRIPT'
##############
# Пример включения в начале скрипта
##############

!/usr/bin/env bash
set -euo pipefail
[ -e "$(dirname "$(readlink -f "$0")")/scripts/make.bash" ] \
  || git submodule update --init scripts
source "$(dirname "$(readlink -f "$0")")/scripts/make.bash"

##############
# КОНЕЦ примера включения в начале скрипта
##############
PARENT_SCRIPT

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/include.bash"


# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash/14203146#14203146
while [[ $# -gt 0 ]]; do
  case "$1" in
  init)
    cd "${SCRIPT_PATH}" || exit 1
    log_info "Pulling latest root repository changes..."
    git pull --no-edit
    log_info "Initializing and updating all submodules..."
    git config -f .gitmodules --get-regexp '^submodule\..*\.url$' |
      awk '{print $1}' | sed 's/^submodule\.//; s/\.url$//' |
      while read -r sub; do
        log_info "Updating submodule '$sub'"
        git submodule update --init --remote --recursive "$sub"
      done
    log_info "Checking for orphaned submodules..."
    # shellcheck disable=SC2045
    for m in $(ls .git/modules 2>/dev/null); do
      if ! grep -q "$m" .gitmodules 2>/dev/null; then
        log_warn "🧹 Orphaned submodule found: $m"
      fi
    done
    log_done "All submodules are initialized and up to date ✅"

    exit 0
    ;;

  -* | --*)
    echo "Unknown option $1"
    exit 1
    ;;
  *)

    echo "Unknown positional argument $1"
    exit 1
    ;;
  esac
done

checkout_submodule_branch() {
  log_info "Inspect submodule $name"
  local name="$1";
  local branch=$(git config -f "${SCRIPT_PATH}/.gitmodules" submodule.$name.branch)
  local path=$(git config -f "${SCRIPT_PATH}/.gitmodules" submodule.$name.path)

  # if branch is not empty, checkout and pull
  if [ -n "$branch" ]; then
    log_info "Checkout submodule $name:$branch"
    (echo "${SCRIPT_PATH}/$path"; cd ${SCRIPT_PATH}/$path && git checkout "$branch" && git pull --no-edit)
  fi
}
