FROM alpine:edge

RUN set -eu && \
    apk --no-cache add \
    tini \
    bash \
    samba \
    tzdata \
    shadow && \
    rm -f /etc/samba/smb.conf && \
    rm -rf /tmp/* /var/cache/apk/*

COPY --chmod=700 samba.sh /usr/bin/samba.sh
COPY --chmod=600 smb.conf /etc/samba/smb.conf
COPY --chmod=600 users.conf /etc/samba/users.conf
COPY --chmod=555 healthcheck.sh /healthcheck.sh

VOLUME /storage
EXPOSE 445

HEALTHCHECK --interval=60s --timeout=15s CMD /healthcheck.sh

ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/samba.sh"]
