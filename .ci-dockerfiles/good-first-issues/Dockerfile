ARG FROM_TAG=release
FROM ghcr.io/ponylang/pony-sync-helper-ci-builder:${FROM_TAG}

RUN apk add --update --no-cache \
  python3 \
  python3-dev \
  py3-pip

RUN pip3 install --upgrade pip \
  pylint \
  zulip

COPY post-good-first-issues.py /post-good-first-issues.py

RUN chmod a+x /post-good-first-issues.py
