#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/include.bash"

REPO_ROOT=$(git rev-parse --show-toplevel)

git submodule add https://github.com/inyur/scripts ${REPO_ROOT}/.devops/scripts

cat <<'EOF' > ${REPO_ROOT}/make.bash
#!/usr/bin/env bash
set -euo pipefail
[ -e "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.devops/scripts/make.bash" ] \
  || git submodule update --init .devops/scripts
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.devops/scripts/make.bash"
EOF

chmod +x ${REPO_ROOT}/make.bash
