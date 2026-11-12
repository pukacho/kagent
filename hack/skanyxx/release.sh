#!/usr/bin/env bash
# Builds Skanyxx's kagent fork (SKANYXX.md): the controller, golang-adk, kagent-adk and app images and the kagent-crds
# chart. PUSH=true builds both platforms and pushes images and chart; otherwise the images are loaded into the local
# Docker (this machine's platform) and the chart is left in dist/.
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
  OUTPUT=(--platform linux/amd64,linux/arm64 --push)
else
  OUTPUT=(--load)
fi

build() { # image, context, dockerfile, extra args…
  local image=$1 context=$2 file=$3
  shift 3
  docker buildx build "${OUTPUT[@]}" --build-arg VERSION="$VERSION" --build-arg LDFLAGS="$LDFLAGS" "$@" \
    -t "$IMAGES/$image:$VERSION" -f "$file" "$context"
}

build controller go go/Dockerfile --build-arg BUILD_PACKAGE=core/cmd/controller/main.go
build golang-adk go go/Dockerfile --build-arg BUILD_PACKAGE=adk/cmd/main.go
build kagent-adk python python/Dockerfile
build app python python/Dockerfile.app \
  --build-arg KAGENT_ADK_VERSION="$VERSION" --build-arg DOCKER_REGISTRY="$REGISTRY" --build-arg DOCKER_REPO="$REPO"

VERSION=$VERSION KMCP_VERSION=$KMCP_VERSION SUBSTRATE_VERSION=$SUBSTRATE_VERSION \
  SUBSTRATE_REPO=oci://ghcr.io/kagent-dev/substrate/helm \
  envsubst <helm/kagent-crds/Chart-template.yaml >helm/kagent-crds/Chart.yaml
helm dependency update helm/kagent-crds
mkdir -p dist
helm package -d dist helm/kagent-crds
if [[ $PUSH == true ]]; then
  helm push "dist/kagent-crds-$VERSION.tgz" "oci://$IMAGES/helm"
fi
