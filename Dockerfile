FROM alpine:edge

RUN set -eu && \
    apk --no-cache add \
    tini \
    bash \
    samba \
    tzdata \
    shadow && \
    addgroup -S smb && \
    rm -f /etc/samba/smb.conf && \
    rm -rf /tmp/* /var/cache/apk/*

COPY --chmod=700 samba.sh /usr/bin/samba.sh
COPY --chmod=600 smb.conf /etc/samba/smb.conf
COPY --chmod=600 users.conf /etc/samba/users.conf

VOLUME /storage
EXPOSE 445

HEALTHCHECK --interval=60s --timeout=15s CMD smbclient --configfile=/etc/samba.conf -L \\localhost -U % -m SMB3

ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/samba.sh"]
