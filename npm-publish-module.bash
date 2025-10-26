#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/include.bash"

# defaults
NPM_MODULE_PATH="./"
DONT_PUBLISH_SOURCEMAPS=""
DRY_RUN="${DRY_RUN:-}"
DONT_PUBLISH="${DONT_PUBLISH:-}"

# Parse args: accept flags anywhere; if an arg doesn't start with '-', treat it as path (first such)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dont-publish-sourcemaps)
      DONT_PUBLISH_SOURCEMAPS="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --dont-publish)
      DONT_PUBLISH="true"
      shift
      ;;
    --) # end of flags
      shift
      break
      ;;
    -*) # unknown short/long flag — keep or warn
      echo "Warning: unknown option '$1' (ignored)"
      shift
      ;;
    *) # positional: first non-flag is module path
      if [[ "${NPM_MODULE_PATH}" == "./" ]]; then
        NPM_MODULE_PATH="$1"
      else
        # extra positional args ignored
        echo "Warning: extra positional arg '$1' ignored"
      fi
      shift
      ;;
  esac
done

# Hides corejs banners
export ADBLOCK="true"
# Hides corejs banners
export DISABLE_OPENCOLLECTIVE="true"

NPM_MODULE_PATH="$(cd "$(pwd)/${NPM_MODULE_PATH}" && pwd)";

if [ ! -e "${NPM_MODULE_PATH}/package.json" ]; then
  log_error "Error: package.json not found in path '${NPM_MODULE_PATH}'"
  exit 1
fi

# shellcheck disable=SC2164
cd "${NPM_MODULE_PATH}"

echo "### Bump version"
VER_IN_PKG_JSON=$(npm pkg get version | tr -d '"')
echo "$VER_IN_PKG_JSON"
NAME_IN_PKG_JSON=$(npm pkg get name | tr -d '"')
echo "$NAME_IN_PKG_JSON"

# Inspect versions
IN_REGISTRY=$(npm view "${NAME_IN_PKG_JSON}@^${VER_IN_PKG_JSON}" >/dev/null 2>&1 && echo true || echo "")
[[ "${IN_REGISTRY}" ]] &&
  echo "Found ver ${VER_IN_PKG_JSON} in registry" ||
  echo "NOT Found ver ${VER_IN_PKG_JSON} in registry"
if [[ "${IN_REGISTRY}" ]]; then
  VER_IN_REGISTRY=$(npm view "${NAME_IN_PKG_JSON}@^${VER_IN_PKG_JSON}" version --json)
  # Remove new lines and spaces
  VER_IN_REGISTRY=$(echo "$VER_IN_REGISTRY" | tr -d '\n\r ')
  # normalize array
  if ! [[ "${VER_IN_REGISTRY}" =~ \[.+\] ]]; then
    VER_IN_REGISTRY="[${VER_IN_REGISTRY}]"
  fi
  VER_IN_REGISTRY=${VER_IN_REGISTRY/[/}
  VER_IN_REGISTRY=${VER_IN_REGISTRY/]/}
  VER_IN_REGISTRY=${VER_IN_REGISTRY//\"/}
  VER_IN_REGISTRY=${VER_IN_REGISTRY//','/$'\n'}
  VER_IN_REGISTRY=$(echo "$VER_IN_REGISTRY" | sort -V)
  VER_IN_REGISTRY=$(echo "$VER_IN_REGISTRY" | tail -n1)
  npm pkg set version="${VER_IN_REGISTRY}"
  # echo "Setted version: ${VER_IN_REGISTRY}"
  if [[ "${CI_COMMIT_REF_NAME:-master}" == "${CI_DEFAULT_BRANCH:-master}" ]]; then
    npm version patch --no-git-tag-version
  fi
fi
if [[ "${CI_COMMIT_REF_NAME:-master}" != "${CI_DEFAULT_BRANCH:-master}" ]]; then
  VER_IN_PKG_JSON=$(npm pkg get version | tr -d '"')
  echo "Inspect version ${VER_IN_PKG_JSON}"
  if ! [[ "${VER_IN_PKG_JSON}" =~ .+\..+\..+-.+ ]]; then # 1.0.22-beta.0
    echo "Initial bump to beta version"
    npm version prerelease --preid="${CI_COMMIT_REF_SLUG}" --no-git-tag-version
    VER_IN_PKG_JSON=$(npm pkg get version | tr -d '"')
  else
    echo "Do not bump to beta version, because already beta version in pkg json"
  fi
  # Here we 'npm view' beta version and grep, because npm will return any beta versions by this pkg version
  IN_REGISTRY=$(npm view "${NAME_IN_PKG_JSON}@^${VER_IN_PKG_JSON}" version --json | grep "$(echo "${VER_IN_PKG_JSON}" | sed 's/[0-9]\+$//')" >/dev/null 2>&1 && echo true || echo "")
  # export IN_REGISTRY=1
  [[ "${IN_REGISTRY}" ]] &&
    echo "Found ver ${VER_IN_PKG_JSON} in registry" ||
    echo "NOT Found ver ${VER_IN_PKG_JSON} in registry"
  if [[ "${IN_REGISTRY}" ]]; then
    VER_IN_REGISTRY=$(npm view "${NAME_IN_PKG_JSON}@^${VER_IN_PKG_JSON}" version --json)
    # VER_IN_REGISTRY="[1.0.22-${CI_COMMIT_REF_SLUG}.0, 1.0.22-${CI_COMMIT_REF_SLUG}.1]"
    # Remove new lines and spaces
    VER_IN_REGISTRY=$(echo "$VER_IN_REGISTRY" | tr -d '\n\r ')
    # normalize array
    if ! [[ "${VER_IN_REGISTRY}" =~ \[.+\] ]]; then
      VER_IN_REGISTRY="[${VER_IN_REGISTRY}]"
    fi
    VER_IN_REGISTRY=${VER_IN_REGISTRY/[/}
    VER_IN_REGISTRY=${VER_IN_REGISTRY/]/}
    VER_IN_REGISTRY=${VER_IN_REGISTRY//\"/}
    VER_IN_REGISTRY=${VER_IN_REGISTRY//','/$'\n'}

    # https://stackoverflow.com/questions/48131243/remove-digits-from-end-of-string
    VER_IN_REGISTRY=$(echo "$VER_IN_REGISTRY" | grep "$(echo "${VER_IN_PKG_JSON}" | sed 's/[0-9]\+$//')")

    VER_IN_REGISTRY=$(echo "$VER_IN_REGISTRY" | sort -V)
    VER_IN_REGISTRY=$(echo "$VER_IN_REGISTRY" | tail -n1)
    npm pkg set version="${VER_IN_REGISTRY}"
    # echo "Setted version: ${VER_IN_REGISTRY}"
    npm version prerelease --preid="${CI_COMMIT_REF_SLUG}" --no-git-tag-version
  fi
fi

NPM_PUBLISH_PARAMS_ARR=(--verbose)

if grep -q '"publishConfig"[[:space:]]*:[[:space:]]*{[[:space:]]*"access"[[:space:]]*:[[:space:]]*"public"' "${NPM_MODULE_PATH}/package.json"; then
  NPM_PUBLISH_PARAMS_ARR+=(--access public);
fi

[ ! -e "${NPM_MODULE_PATH}/node_modules" ] && npm ci

# Build
# https://stackoverflow.com/questions/50683885/how-to-check-if-npm-script-exists/50684147#50684147
npm run build --if-present

if [[ "${DONT_PUBLISH_SOURCEMAPS}" == "true" ]]; then
  log_info "Removing sourcemap files (*.map)..."
  find "${NPM_MODULE_PATH}/dist" -type f -name "*.map" -print -delete 2>/dev/null || true
fi

# Publish
if [[ -z ${DRY_RUN:-} && -z ${DONT_PUBLISH:-} ]]; then
  npm publish "${NPM_PUBLISH_PARAMS_ARR[@]}"
fi
