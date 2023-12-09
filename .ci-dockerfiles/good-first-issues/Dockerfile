ARG FROM_TAG=release
FROM ghcr.io/ponylang/shared-docker-ci-x86-64-unknown-linux-builder-with-libressl-3.7.3:${FROM_TAG}

RUN apk add --update --no-cache \
  pcre2-dev \
  python3 \
  python3-dev \
  py3-pip

RUN pip3 install --upgrade pip \
  pylint \
  zulip

COPY post-good-first-issues.py /post-good-first-issues.py

RUN chmod a+x /post-good-first-issues.py
