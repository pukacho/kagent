#!/usr/bin/env bash
# Builds Skanyxx's kagent fork (SKANYXX.md): the controller image, the slim and -full agent runtime images (golang-adk,
# kagent-adk, app; kagent picks -full for agents with skills or code execution) and the kagent-crds chart.
# PUSH=true builds both platforms and pushes images and chart, refusing a dirty tree or a version already published;
# otherwise the images are loaded into the local Docker (this machine's platform, through a docker-driver builder so the
# app image finds the kagent-adk base just built) and the chart is left in dist/.
set -euo pipefail
cd "$(dirname "$0")/../.."

VERSION=${VERSION:-0.10.2-skanyxx.1}
REGISTRY=${REGISTRY:-ghcr.io}
REPO=${REPO:-skanyxx/kagent}
PUSH=${PUSH:-false}
KMCP_VERSION=0.3.0
SUBSTRATE_VERSION=0.0.9

IMAGES=$REGISTRY/$REPO
# The version package is linked by module path, which stays upstream's.
LDFLAGS="-X github.com/kagent-dev/kagent/go/core/internal/version.Version=v$VERSION \
-X github.com/kagent-dev/kagent/go/core/internal/version.GitCommit=$(git rev-parse --short HEAD) \
-X github.com/kagent-dev/kagent/go/core/internal/version.BuildDate=$(date -u +%Y-%m-%d)"

if [[ $PUSH == true ]]; then
  [[ -z $(git status --porcelain) ]] || { echo "uncommitted changes: commit them before publishing" >&2; exit 1; }
  if docker buildx imagetools inspect "$IMAGES/controller:$VERSION" >/dev/null 2>&1; then
    echo "$IMAGES/controller:$VERSION is already published: bump VERSION" >&2
    exit 1
  fi
  OUTPUT=(--platform linux/amd64,linux/arm64 --push)
else
  OUTPUT=(--load)
fi

build() { # image tag, context, dockerfile, extra args…
  local image=$1 context=$2 file=$3
  shift 3
  docker buildx build "${OUTPUT[@]}" --build-arg VERSION="$VERSION" --build-arg LDFLAGS="$LDFLAGS" "$@" \
    -t "$IMAGES/$image" -f "$file" "$context"
}

build "controller:$VERSION" go go/Dockerfile --build-arg BUILD_PACKAGE=core/cmd/controller/main.go
build "golang-adk:$VERSION" go go/Dockerfile --build-arg BUILD_PACKAGE=adk/cmd/main.go
build "golang-adk:$VERSION-full" go go/Dockerfile.full --build-arg BUILD_PACKAGE=adk/cmd/main.go
build "kagent-adk:$VERSION" python python/Dockerfile
build "kagent-adk:$VERSION-full" python python/Dockerfile.full
for flavour in "$VERSION" "$VERSION-full"; do
  build "app:$flavour" python python/Dockerfile.app \
    --build-arg KAGENT_ADK_VERSION="$flavour" --build-arg DOCKER_REGISTRY="$REGISTRY" --build-arg DOCKER_REPO="$REPO"
done

VERSION=$VERSION KMCP_VERSION=$KMCP_VERSION SUBSTRATE_VERSION=$SUBSTRATE_VERSION \
  SUBSTRATE_REPO=oci://ghcr.io/kagent-dev/substrate/helm \
  envsubst <helm/kagent-crds/Chart-template.yaml >helm/kagent-crds/Chart.yaml
helm dependency update helm/kagent-crds
mkdir -p dist
helm package -d dist helm/kagent-crds
if [[ $PUSH == true ]]; then
  helm push "dist/kagent-crds-$VERSION.tgz" "oci://$IMAGES/helm"
  # Pin the controller in Skanyxx as <tag>@<digest>. The runtime images are named by tag only: kagent appends -full to it.
  docker buildx imagetools inspect "$IMAGES/controller:$VERSION" --format '{{json .Manifest.Digest}}'
fi
