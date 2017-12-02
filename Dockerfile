FROM centos:centos7
MAINTAINER  Sharad Varshney "sharad.varshney@gmail.com"

# install dependencies
RUN yum -y update; yum clean all
RUN yum -y install vm vim-X11 vim-common vim-enhanced vim-minimal; yum clean all
RUN yum -y install tar vim wget nc curl zip unzip sudo git; yum clean all
RUN yum -y install epel-release; yum clean all

#install jdk
ENV JAVA_VERSION 8u31
ENV BUILD_VERSION b13

# Upgrading system
RUN yum -y upgrade
RUN yum -y install wget

# Inatalling Java
RUN yum -y install java-1.8.0-openjdk

RUN alternatives --install /usr/bin/java jar /usr/java/latest/bin/java 200000
RUN alternatives --install /usr/bin/javaws javaws /usr/java/latest/bin/javaws 200000
RUN alternatives --install /usr/bin/javac javac /usr/java/latest/bin/javac 200000

ENV JAVA_HOME /usr/lib/jvm/jre-1.8.0

# install Solr now
ARG SOLR_DOWNLOAD_SERVER
ENV SOLR_USER="solr" \
    SOLR_UID="8983" \
    SOLR_GROUP="solr" \
    SOLR_GID="8983" \
    SOLR_VERSION="7.0.1" \
    SOLR_URL="${SOLR_DOWNLOAD_SERVER:-https://archive.apache.org/dist/lucene/solr}/7.0.1/solr-7.0.1.tgz" \
    SOLR_SHA256="128239cadfd8cb95ce510ce68881cfbb5f16dc559051477f780e1bc490bb7000" \
    SOLR_KEYS="5F55943E13D49059D3F342777186B06E1ED139E7" \
    PATH="/opt/solr/bin:/opt/solr/docker-solr/scripts:$PATH"

RUN groupadd -r --gid $SOLR_GID $SOLR_GROUP && \
    useradd -r --uid $SOLR_UID --gid $SOLR_GID $SOLR_USER

RUN set -e; for key in $SOLR_KEYS; do \
        found=''; \
        for server in \
          ha.pool.sks-keyservers.net \
          hkp://keyserver.ubuntu.com:80 \
          hkp://p80.pool.sks-keyservers.net:80 \
          pgp.mit.edu \
        ; do \
          echo "  trying $server for $key"; \
          gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$key" && found=yes && break; \
        done; \
        test -z "$found" && echo >&2 "error: failed to fetch $key from several disparate servers -- network issues?" && exit 1; \
      done; \
      exit 0

  RUN mkdir -p /opt/solr && \
    echo "downloading $SOLR_URL" && \
    wget -nv $SOLR_URL -O /opt/solr.tgz && \
    echo "downloading $SOLR_URL.asc" && \
    wget -nv $SOLR_URL.asc -O /opt/solr.tgz.asc && \
    echo "$SOLR_SHA256 */opt/solr.tgz" | sha256sum -c - && \
    (>&2 ls -l /opt/solr.tgz /opt/solr.tgz.asc) && \
    gpg --batch --verify /opt/solr.tgz.asc /opt/solr.tgz && \
    tar -C /opt/solr --extract --file /opt/solr.tgz --strip-components=1 && \
    rm /opt/solr.tgz* && \
    rm -Rf /opt/solr/docs/ && \
    mkdir -p /opt/solr/server/solr/lib /opt/solr/server/solr/mycores /opt/solr/server/logs /docker-entrypoint-initdb.d /opt/solr/docker-solr && \
    sed -i -e 's/"\$(whoami)" == "root"/$(id -u) == 0/' /opt/solr/bin/solr && \
    sed -i -e 's/lsof -PniTCP:/lsof -t -PniTCP:/' /opt/solr/bin/solr && \
    sed -i -e 's/#SOLR_PORT=8983/SOLR_PORT=8983/' /opt/solr/bin/solr.in.sh && \
    sed -i -e '/-Dsolr.clustering.enabled=true/ a SOLR_OPTS="$SOLR_OPTS -Dsun.net.inetaddr.ttl=60 -Dsun.net.inetaddr.negative.ttl=60"' /opt/solr/bin/solr.in.sh && \
    chown -R $SOLR_USER:$SOLR_GROUP /opt/solr

COPY scripts /opt/solr/docker-solr/scripts
RUN chown -R $SOLR_USER:$SOLR_GROUP /opt/solr/docker-solr

EXPOSE 8983
WORKDIR /opt/solr/docker-solr/scripts
USER $SOLR_USER
RUN chmod -R 755 /opt/solr/docker-solr
RUN chmod +x /opt/solr/docker-solr/scripts/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["solr-foreground"]
