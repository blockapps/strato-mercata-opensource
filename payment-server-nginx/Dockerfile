FROM openresty/openresty:1.19.3.1-7-buster

LABEL org.opencontainers.image.authors="BlockApps Inc."

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y apache2-utils curl wget vim nano openresty-opm dnsutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir -p /usr/local/openresty/nginx/lua && \
    wget -P /usr/local/openresty/nginx/lua https://raw.githubusercontent.com/knyar/nginx-lua-prometheus/0.20181120/prometheus.lua && \
    rm /usr/local/openresty/nginx/conf/nginx.conf && \
    opm get zmartzone/lua-resty-openidc=1.7.4 && \
    opm remove bungle/lua-resty-session && \
    opm get bungle/lua-resty-session=3.10    
    # ^ Remove lines to reinstall lua-resty-session once switched to lua-resty-openidc=1.7.6-3 (when 1.7.6 is available in OPM, see here in the bottoms: https://opm.openresty.org/package/zmartzone/lua-resty-openidc/ )
    # ^ Additional dependency issue context: https://github.com/zmartzone/lua-resty-openidc/issues/463
    # ^ NOTE: There is a same workaround used in STRATO nginx

HEALTHCHECK --interval=5s --timeout=1s --start-period=180s \
  CMD curl  --silent --output /dev/null --fail localhost:80/_ping || \
        exit 1

COPY nginx.tpl.conf openid.tpl.lua /tmp/

COPY docker-run.sh /

COPY licenses /licenses

ENTRYPOINT ["/docker-run.sh"]
