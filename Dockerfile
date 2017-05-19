FROM openjdk:8-jre-alpine


ENV PATH /usr/share/elasticsearch/bin:$PATH
ENV ELASTICSEARCH_VERSION 5.4.0


RUN addgroup -g 10000 elasticsearch && adduser -D -u 10000 -G elasticsearch -h /usr/share/elasticsearch elasticsearch

WORKDIR /usr/share/elasticsearch

RUN apk add --no-cache bash

RUN apk add --no-cache --virtual .fetch-deps \
 ca-certificates \
 gnupg \
 openssl \
 curl \
 tar


# Download/extract defined ES version. busybox tar can't strip leading dir.
RUN curl https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz > elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz && \
    EXPECTED_SHA=$(curl https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz.sha1) && \
    test $EXPECTED_SHA == $(sha1sum elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz | awk '{print $1}') && \
    tar zxf elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz && \
    chown -R elasticsearch:elasticsearch elasticsearch-${ELASTICSEARCH_VERSION} && \
    mv elasticsearch-${ELASTICSEARCH_VERSION}/* . && \
    rmdir elasticsearch-${ELASTICSEARCH_VERSION} && \
    rm elasticsearch-${ELASTICSEARCH_VERSION}.tar.gz

RUN apk del .fetch-deps

RUN set -ex && for esdirs in config data logs; do \
        mkdir -p "$esdirs"; \
        chown -R elasticsearch:elasticsearch "$esdirs"; \
    done

USER elasticsearch

# Install x-pack and also the ingest-{agent,geoip} modules required for Filebeat
#RUN for PLUGIN_TO_INST in 'x-pack' 'ingest-user-agent' 'ingest-geoip'; do elasticsearch-plugin install --batch "$PLUGIN_TO_INST"; done


COPY config/elasticsearch.yml config/
COPY config/log4j2.properties config/
COPY bin/es-docker bin/es-docker

USER root
RUN chown elasticsearch:elasticsearch config/elasticsearch.yml config/log4j2.properties bin/es-docker && \
    chmod 0750 bin/es-docker

USER elasticsearch
CMD ["/bin/bash", "bin/es-docker"]

EXPOSE 9200 9300
