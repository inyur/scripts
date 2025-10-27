#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/include.bash"

if [[ $# -lt 1 ]]; then
  log_error "Usage: $0 <path to Dockerfile> <image name>:<image tag>"
  exit 1
fi

DOCKER_FILEPATH="$1"
shift || true
IMAGE_NAME_AND_TAG="$1"
shift || true

# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash/14203146#14203146
while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      IMAGE_CONTEXT="$2"
      shift 2
      ;;
    --dedicated-builder)
      DEDICATED_BUILDER=YES
      shift 1
    ;;
    --no-local-cache)
      NO_LOCAL_CACHE=YES
      shift 1
    ;;
    --no-push)
      NO_PUSH=YES
      shift 1
      ;;

    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
    echo "Unknown positional argument $1"
      exit 1
    ;;
  esac
done

# Remove last slash if exist
DOCKER_FILEPATH="${DOCKER_FILEPATH%/}"

DOCKER_FILEPATH="$(readlink -f "${DOCKER_FILEPATH}")"

[ -d "${DOCKER_FILEPATH}" ] && DOCKER_FILEPATH="${DOCKER_FILEPATH}/Dockerfile";

if [ ! -e ${DOCKER_FILEPATH} ]; then
  log_error "Dockerfile not found by path ${DOCKER_FILEPATH}"
  exit 1;
fi

[ -z "${IMAGE_CONTEXT:-}" ] && IMAGE_CONTEXT=$(dirname "$(readlink -f "${DOCKER_FILEPATH}")")

IMAGE_NAME="${IMAGE_NAME_AND_TAG%%:*}" # всё до первого :
[ -z "${IMAGE_NAME}" ] && IMAGE_NAME=$(basename "$IMAGE_CONTEXT")
# Если есть :, берём часть после :
IMAGE_TAG="$([[ "$IMAGE_NAME_AND_TAG" == *:* ]] && echo "${IMAGE_NAME_AND_TAG#*:}" || echo "")"

[ -z "${IMAGE_TAG}" ] && IMAGE_TAG=$(git branch --show-current);
[ -z "${IMAGE_TAG}" ] && IMAGE_TAG=${CI_COMMIT_REF_NAME:-};
# Convert to lowercase
IMAGE_TAG=$(echo "$IMAGE_TAG" | tr '[:upper:]' '[:lower:]')
# Replace all invalid characters with hyphen
IMAGE_TAG=${IMAGE_TAG//[^a-z0-9._-]/-}
# Remove leading hyphens or dots
IMAGE_TAG=${IMAGE_TAG##[-.]}
# Remove trailing hyphens or dots
IMAGE_TAG=${IMAGE_TAG%%[-.]}
if [ -z "${IMAGE_TAG}" ]; then
  log_error  "Cant resolve image-tag, need help"
  exit 1
fi

log_info "Dockerfile: ${DOCKER_FILEPATH}"
log_info "Image name: ${IMAGE_NAME}, tag: ${IMAGE_TAG}"

# Wait for docker
# https://gitlab.com/gitlab-org/gitlab-runner/-/issues/27384#note_497228752
#for i in $(seq 1 30); do
  #docker context use default
  #docker info && break
#  echo ""
#  echo "Waiting for docker to start"
#  sleep 1s
#done

BUILDER_NAME="multiarch-builder"
[ -n "${DEDICATED_BUILDER}" ] && BUILDER_NAME="multiarch-builder-$$"

cleanup_called=false
docker_builder_created=false
cleanup() {
  if [ "$cleanup_called" = true ]; then return; fi
  if [ "$docker_builder_created" != true ]; then return; fi
  cleanup_called=true
  [ -n "${DEDICATED_BUILDER}" ] && log_info "Clearing builder ${BUILDER_NAME}..."
  [ -n "${DEDICATED_BUILDER}" ] && (docker buildx rm "$BUILDER_NAME" 2>&1 > /dev/null) || true
}

trap 'cleanup' EXIT SIGHUP SIGINT SIGQUIT SIGTERM ERR

# Build image

# set -xv
which git || apk add --no-cache git
which bash || apk add --no-cache bash

# [[ ! -z "${IMAGE_BUILD_PATH}" ]] && cd $IMAGE_BUILD_PATH

# Assign default value to IMAGE_NAME if empty
#export IMAGE_NAME=${IMAGE_NAME:-$CI_PROJECT_NAME}
#echo "${IMAGE_NAME}"

#[[ ! -z "$USE_PATH_CHECKSUM_AS_IMAGE_TAG" ]] &&
#  IMAGE_TAG=$(git ls-files -s | git hash-object --stdin) ||
#  IMAGE_TAG=$(git rev-parse HEAD)
#echo $IMAGE_TAG
#echo -n $GITLAB_CICD_TOKEN_RW | docker login -u gitlab-cicd-token-rw --password-stdin $CI_REGISTRY

export DOCKER_CLI_EXPERIMENTAL=enabled

# echo "Try find image ${IMAGE_NAME}:${IMAGE_TAG}"

#if docker manifest inspect ${CI_REGISTRY}/${CI_PROJECT_NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG} > /dev/null; then
#  echo -e "\e[32m Docker image with tag ${IMAGE_TAG} exists, skip build \e[0m"
#else
#  echo -e "\e[31m Docker image with tag ${IMAGE_TAG} not found, lets build it \e[0m"

# https://forum.gitlab.com/t/cannot-get-multi-platform-docker-images-to-gitlab-registry/83777
# https://www.docker.com/blog/how-to-rapidly-build-multi-architecture-images-with-buildx/
# https://github.com/docker/buildx/issues/413
CONTEXT_NAME="tls-environment"

# Создаём контекст, если его нет
if ! docker context ls --format '{{.Name}}' | grep -qx "$CONTEXT_NAME"; then
  log_info "Creating Docker context ${CONTEXT_NAME}..."
  docker context create "$CONTEXT_NAME"
fi

DOCKER_IMAGE_CACHE_PATH="${SCRIPT_PATH}/../../.buildx-cache";
[ -z "${NO_LOCAL_CACHE}" ] && mkdir -p "${DOCKER_IMAGE_CACHE_PATH}"
DOCKER_IMAGE_CACHE_PATH=$(realpath "${SCRIPT_PATH}/../../.buildx-cache")

if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  log_info "Builder '$BUILDER_NAME' not found, creating..."
  docker buildx create \
    --name "${BUILDER_NAME}" \
    --use tls-environment \
    --driver-opt "network=host" \
    --driver-opt "env.BUILDKIT_STEP_LOG_MAX_SIZE=10485760" \
    --driver-opt "env.BUILDKIT_STEP_LOG_MAX_SPEED=10485760" \
    --driver-opt "env.BUILDKIT_CACHE_MOUNT_NS=shared" \
    --buildkitd-flags '--oci-worker-gc=false' \
    --bootstrap
  log_done "Builder '$BUILDER_NAME' created"
else
  log_done "Builder '$BUILDER_NAME' already exists."
fi
docker_builder_created=true
#     --buildkitd-flags '--oci-worker-gc=false' \
#--driver-opt "env.BUILDKIT_CACHE_EXPORTER=local,dest=${DOCKER_IMAGE_CACHE_PATH}" \
 #    --driver-opt "env.BUILDKIT_CACHE_IMPORTER=local,src=${DOCKER_IMAGE_CACHE_PATH}" \
 #


# log_done "Builder ${BUILDER_NAME} ready"

# docker buildx ls

export DATEFSSAFE=$(date -u "+%Y-%m-%dT%H-%M-%S")

get_build_stages() {
  grep -iE '^FROM .* AS ' "${DOCKER_FILEPATH}" |
    sed -E 's/^FROM .* AS //I' |
    sed 's/ *$//' |
    tr '[:upper:]' '[:lower:]'
  # | sort -u
}

### Build Images and tags for using for cache-from

CACHE_FROM_ARR=()

add_unique_cache_from() {
  local element="$1"

  if [ "${#STAGES_ARR[@]:-0}" -gt 0 ]; then
    for e in "${CACHE_FROM_ARR[@]:-0}}"; do
      [[ "$e" == "$element" ]] && return 0
    done
  fi

  CACHE_FROM_ARR+=("$element")

  log_info "Added to cache-from: $element"
}

PSEUDO_CACHE_TARGET='single'
IMAGE_CACHE_TAG_PREFIX='_cache-stage-'
IMAGE_CACHE_TAG_SUFFIX='-'

STAGES_ARR=($(get_build_stages || true))
[ "${#STAGES_ARR[@]:-0}" -eq 0 ] && STAGES_ARR+=("${PSEUDO_CACHE_TARGET}")

COMMIT_HASHES_HISTORY_ARR=($(git rev-list --max-count=10 HEAD))
imageForCacheFound=false;


for COMMIT_HASH in "${COMMIT_HASHES_HISTORY_ARR[@]}"; do
  STAGES_WITH_ZERO_ARR=("" "${STAGES_ARR[@]}");
  declare -a pids=()
  for STAGE in "${STAGES_WITH_ZERO_ARR[@]}"; do
    IMAGE_NAME_AND_TAG_FOR_CACHE=${IMAGE_NAME}:${STAGE:+${IMAGE_CACHE_TAG_PREFIX}${STAGE}${IMAGE_CACHE_TAG_SUFFIX}}${COMMIT_HASH}
    #if docker manifest inspect "${IMAGE_NAME_AND_TAG_FOR_CACHE}" >/dev/null 2>&1; then
    #  log_info "Image exists in registry: ${IMAGE_NAME_AND_TAG_FOR_CACHE}"
    #  add_unique_cache_from "${IMAGE_NAME_AND_TAG_FOR_CACHE}"
    #  imageForCacheFound=true
    #else
    #  log_warn "Image not found in registry: ${IMAGE_NAME_AND_TAG_FOR_CACHE}"
    #fi
    {
          if docker manifest inspect "${IMAGE_NAME_AND_TAG_FOR_CACHE}" >/dev/null 2>&1; then
            log_info "Image exists in registry: ${IMAGE_NAME_AND_TAG_FOR_CACHE}"
            add_unique_cache_from "${IMAGE_NAME_AND_TAG_FOR_CACHE}"
            echo "${COMMIT_HASH}" >"/tmp/cache_found.$$"
          else
            log_warn "Image not found in registry: ${IMAGE_NAME_AND_TAG_FOR_CACHE}"
          fi
    } &
    pids+=($!)
  done
  # Wait for all parallel jobs for this commit
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
  $imageForCacheFound && break;
done

### END Build Images and tags for using for cache-from

build_image_script() {
  local PLATFORMS=$1
  local TARGET="${2:-}"
  local SHOULD_PUSH="${3:-}"

  # ${VAR:+VALUE} означает:
  # «Если $VAR не пустой, вернуть VALUE, иначе — пустую строку».

  log_info "Building for platform: ${PLATFORMS}${TARGET:+, target: ${TARGET}}"

  local PARAMS_ARR=()

  [ "$SHOULD_PUSH" = true ] && [ -z $NO_PUSH ] && PARAMS_ARR+=(--push)

  [ ! -n "${TARGET}" ] && PARAMS_ARR+=(--load)

  [[ ! -n "${TARGET}" && -n "${IMAGE_TAG}" ]] \
    && PARAMS_ARR+=(--tag "${IMAGE_NAME}:${IMAGE_TAG}")

  local GIT_COMMIT_HASH=$(git rev-parse HEAD)
  local IMAGE_NAME_AND_TAG="${IMAGE_NAME}:${TARGET:+${IMAGE_CACHE_TAG_PREFIX}${TARGET}${IMAGE_CACHE_TAG_SUFFIX}}${GIT_COMMIT_HASH}"
  PARAMS_ARR+=(--tag "${IMAGE_NAME_AND_TAG}")

  [ -z "${NO_LOCAL_CACHE}" ] && PARAMS_ARR+=(--cache-to=type=local,dest=${DOCKER_IMAGE_CACHE_PATH},mode=max)
  [ -z "${NO_LOCAL_CACHE}" ] && [ -e "${DOCKER_IMAGE_CACHE_PATH}/index.json" ] && \
    PARAMS_ARR+=(--cache-from=type=local,src=${DOCKER_IMAGE_CACHE_PATH})

  PARAMS_ARR+=(--cache-from=type=docker)

  # [ -n "${TARGET}" ] && add_unique_cache_from "${IMAGE_NAME_AND_TAG}"

  PARAMS_ARR+=(--builder ${BUILDER_NAME})
  [[ -n "${TARGET}" && ( "${TARGET}" != "${PSEUDO_CACHE_TARGET}" ) ]] && PARAMS_ARR+=(--target ${TARGET});
  PARAMS_ARR+=(--platform ${PLATFORMS})
  PARAMS_ARR+=(--build-arg CACHEBUSTER=${DATEFSSAFE})
  PARAMS_ARR+=(--build-arg DATETIME=${DATEFSSAFE})

  [ -n "${TARGET}" ] && PARAMS_ARR+=(--cache-to=type=inline)
  [ ! -n "${TARGET}" ] && PARAMS_ARR+=(--squash)

  if [ "${#CACHE_FROM_ARR[@]:-0}" -gt 0 ]; then
    for CACHE_FROM_ITEM in "${CACHE_FROM_ARR[@]}"; do
      PARAMS_ARR+=(--cache-from=${CACHE_FROM_ITEM})
    done
  fi

  PARAMS_ARR+=(-f ${DOCKER_FILEPATH})

  log_info "Running docker buildx build..."

  docker buildx build "${PARAMS_ARR[@]}" "${IMAGE_CONTEXT}"

  log_done "Build finished for ${IMAGE_NAME_AND_TAG}"
}

build_images() {
  local PLATFORMS="$1"
  local SHOULD_PUSH="${2:-false}"

  #PLATFORMS="linux/amd64,linux/arm64"
  #[ "${BUILD_ONLY_AMD64:-}" = "true" ] && PLATFORMS="linux/amd64"

  if [ "${#STAGES_ARR[@]:-0}" -gt 0 ]; then
    for TARGET in "${STAGES_ARR[@]:-}"; do
      log_info "Building target: $TARGET"
      build_image_script $PLATFORMS $TARGET $SHOULD_PUSH
    done
  fi

  build_image_script $PLATFORMS "" $SHOULD_PUSH
}

build_images "linux/amd64"

build_images "linux/amd64,linux/arm64" true

log_done "All builds finished"
