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
COPY --chmod=600 secrets/users /run/secrets/users
COPY --chmod=600 secrets/agent /run/secrets/agent

RUN 

VOLUME /storage
EXPOSE 445

ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/samba.sh"]

HEALTHCHECK --interval=60s --timeout=15s CMD smbclient -L localhost --configfile=/etc/samba.conf -U $(cut -d":" -O"%" -f1-2 /run/secrets/agent) -m SMB3 -c 'exit'