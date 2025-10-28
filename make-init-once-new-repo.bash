#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/include.bash"

REPO_ROOT=$(git rev-parse --show-toplevel)

git submodule add git@github.com:inyur/scripts.git ${REPO_ROOT}/.devops/scripts

cat <<EOF > ${REPO_ROOT}/make.bash
#!/usr/bin/env bash
set -euo pipefail
[ -e "$(dirname "$(readlink -f "$0")")/.devops/scripts/make.bash" ] \
  || git submodule update --init .devops/scripts
source "$(dirname "$(readlink -f "$0")")/.devops/scripts/make.bash"
EOF

chmod +x ${REPO_ROOT}/make.bash
