# (c) DevOpsHQ, 2021

FROM gradle:7-jdk8

# You must define some specific variables:
# All Access tokens are here: https://<your-aie-server>/ui/admin/settings
ARG PLUGIN_TOKEN

# URL of Application Inspector Enterprise Server
ARG AI_URI

COPY docker_build_data/config/ /tmp/plugin_config/
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
    python -m pip install --upgrade virtualenv pip-review texttable psycopg2-binary psycopg2 && \
    pip-review --auto

RUN pip3 install pyyaml requests crosspm texttable psycopg2-binary psycopg2

# INSTALL PLUGIN HELP TOOLS
RUN set -ex && \
    cd /usr/src/app/ && \
    chmod +x /usr/src/app/codequality.py && \
    chmod +x /usr/src/app/set-policy.py && \
    chmod +x /usr/src/app/set-settings.py && \
    ln -s /usr/src/app/codequality.py /usr/bin/codequality && \
    ln -s /usr/src/app/set-policy.py /usr/bin/set-policy && \
    ln -s /usr/src/app/set-settings.py /usr/bin/set-settings

# INSTALL CERT
RUN set -ex && \
    cd /tmp/plugin_config/ ;\
	for cert in $(ls *.crt) ; do keytool -importcert -keystore $JAVA_HOME/jre/lib/security/cacerts -storepass "changeit" -alias $cert -file $cert -noprompt ; done
    
# INSTALL PLUGIN
RUN set -ex && \
    mkdir /tmp/plugin_src/ ;\
	cd /tmp/plugin_src/ ;\
	git clone https://github.com/PositiveTechnologies/ptaiPlugins ;\
	cd ptaiPlugins/ptai-cli-plugin/ ;\
    gradle build ;\
	mv build/libs/ptai-cli-plugin.jar /root/ptai-plugin.jar ;\
	echo "java -jar /root/ptai-plugin.jar \"\$@\" --token=${PLUGIN_TOKEN} --url=${AI_URI}" > /usr/src/app/ptai-plugin.sh ;\
	chmod +x /usr/src/app/ptai-plugin.sh ;\
	ln -s /usr/src/app/ptai-plugin.sh /usr/bin/ptai-plugin

# GENERATE en_US LOCALE
RUN set -ex; \
    echo "en_US.UTF-8 UTF-8" >/etc/locale.gen; \
    locale-gen

# SET ENVIRONMENT
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8"

RUN rm -rf /tmp/plugin_config
RUN rm -rf /tmp/plugin_src
