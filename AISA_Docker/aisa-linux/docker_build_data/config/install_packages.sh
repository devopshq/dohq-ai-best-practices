#!/bin/bash
# (c) DevOpsHQ, 2020

# --- Variables ------------------------

REGISTRY_LOGIN=$1
REGISTRY_PASSWORD=$2
AISA_PACKAGE=$3
REGISTRY_URL="https://repo.<your_repo>>.com:443"
REGISTRY_REPO="your_repo"

# --- Download & install Aisa ----------
set -ex

wget --user ${REGISTRY_LOGIN} --password ${REGISTRY_PASSWORD} "${REGISTRY_URL}/${REGISTRY_REPO}/${AISA_PACKAGE}"
dpkg -i ${AISA_PACKAGE}
