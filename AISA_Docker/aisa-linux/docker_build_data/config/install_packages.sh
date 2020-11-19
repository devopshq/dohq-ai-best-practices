#!/bin/bash
# (c) DevOpsHQ, 2020

# --- Variables ------------------------

ARTIFACTORY_LOGIN=$1
ARTIFACTORY_PASSWORD=$2
AISA_PACKAGE=$3
ARTIFACTORY_URL="https://repo.<your_repo>>.com:443"
ARTIFACTORY_REPO="your_repo"

# --- Download & install Aisa ----------
set -ex

wget --user ${ARTIFACTORY_LOGIN} --password ${ARTIFACTORY_PASSWORD} "${ARTIFACTORY_URL}/${ARTIFACTORY_REPO}/${AISA_PACKAGE}"
dpkg -i ${AISA_PACKAGE}
