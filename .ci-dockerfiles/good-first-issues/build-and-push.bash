#!/bin/bash

set -o errexit
set -o nounset

#
# *** You should already be logged in to GitHub Container Registrṡ when you run
#     this ***
#
# ***
# This must be run from the root of the repository like:
#     bash .ci-dockerfiles/good-first-issues/build-and-push.bash
# ***
#

DOCKERFILE_DIR="$(dirname "$0")"
NAME="ghcr.io/ponylang/pony-sync-helper-ci-good-first-issues"

# built from x86-64-unknown-linux-builder release tag
FROM_TAG=release
TAG_AS=release
docker build --pull --build-arg FROM_TAG="${FROM_TAG}" \
  -t "${NAME}:${TAG_AS}" \
  -f "${DOCKERFILE_DIR}/Dockerfile" .
docker push "${NAME}:${TAG_AS}"

# built from x86-64-unknown-linux-builder latest tag
FROM_TAG=latest
TAG_AS=latest
docker build --pull --build-arg FROM_TAG="${FROM_TAG}" \
  -t "${NAME}:${TAG_AS}" \
  -f "${DOCKERFILE_DIR}/Dockerfile" .
docker push "${NAME}:${TAG_AS}"
