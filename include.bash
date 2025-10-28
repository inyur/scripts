#!/usr/bin/env bash

: <<'PARENT_SCRIPT'
##############
# This file should be included in other files by command:
# Пример включения в начале скрипта
##############

#!/usr/bin/env bash
THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${THIS_SCRIPT_DIR}/.<fill real path>./include.bash"

##############
# КОНЕЦ примера включения в начале скрипта
##############
PARENT_SCRIPT

#
#

set -euo pipefail # Fail on first error
shopt -s expand_aliases
set -o allexport # Enable exports all defined variables
# set -xv # Enable debug commands

export SCRIPT=$(readlink -f "$0")
export SCRIPT_PATH=$(dirname "$SCRIPT")

#get_script_path() {
#  echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#}

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
