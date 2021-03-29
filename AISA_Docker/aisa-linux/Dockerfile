# (c) DevOpsHQ, 2020

FROM mcr.microsoft.com/dotnet/core/aspnet:3.1.6-bionic

# You must define some specific variables:

# All Access tokens are here: https://<your-aie-server>/ui/admin/settings
ARG AISA_TOKEN

# URL of Application Inspector Enterprise Server
ARG AISA_URI

# Name of Aisa package like this: aisa.${minor}.${major}.${path}.ubuntu-x64.deb
ARG AISA_PACKAGE

# User login to your registry
ARG REGISTRY_LOGIN

# Password for your registry login
ARG REGISTRY_PASSWORD

COPY docker_build_data/config/ /tmp/aisa_config/
COPY docker_build_data/applications/ /usr/src/app/

# INSTALL EXTERNAL PACKAGES
RUN set -ex && apt-get update && apt-get install -y --no-install-recommends \
    wget libunwind8-dev liblttng-ust0 cmake tree jq git tar xz-utils gcc make locales openssl ssh openssh-server openssh-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# INSTALL PYTHON 3.7
RUN mkdir /tmp/py3.7_build && \
    cd /tmp/py3.7_build && \
    apt-get update && \
    apt-get install --no-install-recommends -y libssl-dev libsqlite3-dev zlib1g-dev libffi-dev  && \
    apt-get clean && \
    wget -c "https://www.python.org/ftp/python/3.7.7/Python-3.7.7.tgz" && \
    tar xf "Python-3.7.7.tgz" && \
    cd "Python-3.7.7" && \
    LDFLAGS="-Wl,-rpath,/usr/local/lib" ./configure --enable-optimizations --enable-shared --with-ensurepip=install && \
    make -j$(nproc) build_all && \
    make altinstall && \
    apt-get remove -y libssl-dev libsqlite3-dev zlib1g-dev libffi-dev && \
    cd - && \
    rm -rf /tmp/py3.7_build /var/lib/apt/lists/*

RUN ln -s python3.7 /usr/local/bin/python && \
    ln -s python3.7 /usr/local/bin/python3 && \
    python --version

RUN python -m pip install --upgrade pip && \
    python -m pip install --upgrade virtualenv pip-review && \
    pip-review --auto

RUN pip3 install pyyaml requests crosspm

# INSTALL AISA HELP TOOLS
RUN set -ex && \
    cd /usr/src/app/ && \
    chmod +x /usr/src/app/aisa-codequality.py && \
    chmod +x /usr/src/app/aisa-set-policy.py && \
    chmod +x /usr/src/app/aisa-set-settings.py && \
    ln -s /usr/src/app/aisa-codequality.py /usr/bin/aisa-codequality && \
    ln -s /usr/src/app/aisa-set-policy.py /usr/bin/aisa-set-policy && \
    ln -s /usr/src/app/aisa-set-settings.py /usr/bin/aisa-set-settings

# INSTALL CERT
#RUN set -ex && \
#    cd /tmp/aisa_config/ ;\
#    cp <you-cert>>.crt /usr/local/share/ca-certificates/<you-cert>.crt ;\
#    cp <you-cert>.crt /usr/local/share/ca-certificates/<you-cert>.pem.crt ;\
#    update-ca-certificates

# INSTALL AISA
RUN set -ex && \
    cd /tmp/aisa_config/ && \
    chmod +x ./install_packages.sh && \
    ./install_packages.sh ${REGISTRY_LOGIN} ${REGISTRY_PASSWORD} ${AISA_PACKAGE}

# GENERATE en_US LOCALE
RUN set -ex; \
    echo "en_US.UTF-8 UTF-8" >/etc/locale.gen; \
    locale-gen

# SET ENVIRONMENT
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

RUN rm -rf /tmp/aisa_config

# SET AISA SETTINGS
RUN aisa --set-settings -u ${AISA_URI} -t ${AISA_TOKEN}
