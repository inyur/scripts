#!/usr/bin/env bash

# This file should be included in other files by command:
# source "$(dirname "$(readlink -f "$0")")/include.bash"

set -euo pipefail # Fail on first error
shopt -s expand_aliases
set -o allexport # Enable exports all defined variables
# set -xv # Enable debug commands

export SCRIPT=$(readlink -f "$0")
export SCRIPT_PATH=$(dirname "$SCRIPT")

# --- Цвета для уведомлений ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_info()  { printf "${CYAN}[%s] ℹ️ %s${RESET}\n" "$(date -u '+%H:%M:%S')" "$1"; }
log_warn()  { printf "${YELLOW}[%s] ⚠️ %s${RESET}\n" "$(date -u '+%H:%M:%S')" "$1"; }
log_error() { printf "${RED}[%s] ❌ %s${RESET}\n" "$(date -u '+%H:%M:%S')" "$1"; }
log_done()  { printf "${GREEN}[%s] ✅ %s${RESET}\n" "$(date -u '+%H:%M:%S')" "$1"; }
