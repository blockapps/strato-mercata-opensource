FROM openresty/openresty:1.21.4.1-6-bullseye

LABEL org.opencontainers.image.authors="BlockApps Inc."

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y apache2-utils curl openresty-opm && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir -p /usr/local/openresty/nginx/lua && \
    rm /usr/local/openresty/nginx/conf/nginx.conf && \
    opm get zmartzone/lua-resty-openidc=1.7.5 && \
    curl -fLo /usr/local/openresty/lualib/resty/openidc.lua https://raw.githubusercontent.com/zmartzone/lua-resty-openidc/v1.7.6/lib/resty/openidc.lua && \
    opm remove bungle/lua-resty-session && \
    opm get bungle/lua-resty-session=3.10

HEALTHCHECK --interval=5s --timeout=1s --start-period=20s \
  CMD curl  --silent --output /dev/null --fail --insecure https://localhost:443/_ping || \
        exit 1

COPY nginx.tpl.conf openid.tpl.lua /tmp/

COPY docker-run.sh /

ENTRYPOINT ["/docker-run.sh"]
