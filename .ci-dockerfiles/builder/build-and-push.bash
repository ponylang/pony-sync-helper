#!/bin/bash

set -o errexit
set -o nounset

#
# *** You should already be logged in to GitHub Container Registrṡ when you run
#     this ***
#

DOCKERFILE_DIR="$(dirname "$0")"
NAME="ghcr.io/ponylang/pony-sync-helper-ci-builder"

# built from standard-builder release tag
FROM_TAG=release
TAG_AS=release
docker build --pull --build-arg FROM_TAG="${FROM_TAG}" \
  -t "${NAME}:${TAG_AS}" \
  "${DOCKERFILE_DIR}"
docker push "${NAME}:${TAG_AS}"

# built from standard-builder nightly tag
FROM_TAG=nightly
TAG_AS=nightly
docker build --pull --build-arg FROM_TAG="${FROM_TAG}" \
  -t "${NAME}:${TAG_AS}" \
  "${DOCKERFILE_DIR}"
docker push "${NAME}:${TAG_AS}"
