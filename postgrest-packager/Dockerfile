FROM ubuntu:16.04

LABEL org.opencontainers.image.authors="BlockApps Inc."

ENV POSTGREST_VERSION=v12.0.0

ENV POSTGREST_SOURCE=https://github.com/PostgREST/postgrest/releases/download \
    POSTGREST_LISTEN_PORT=3001 \
    POSTGREST_FILE=postgrest-${POSTGREST_VERSION}-linux-static-x64.tar.xz \
    POSTGREST_SCHEMA=public \
    POSTGREST_ANONYMOUS=postgres \
    POSTGREST_JWT_SECRET=thisisnotarealsecret \
    POSTGREST_MAX_ROWS=1000000 \
    POSTGREST_POOL=200 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y tar xz-utils wget postgresql-client curl lsof && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    wget "$POSTGREST_SOURCE/$POSTGREST_VERSION/$POSTGREST_FILE" && \
    tar xvJf $POSTGREST_FILE && \
    mv postgrest /usr/local/bin/postgrest && \
    rm $POSTGREST_FILE

COPY doit.sh postgrest.conf.tpl /

COPY licenses /licenses

HEALTHCHECK --interval=5s --timeout=2s --start-period=60s \
  CMD lsof -i :3001 || \
    exit 1

EXPOSE 3001

CMD ["sh", "/doit.sh"]
