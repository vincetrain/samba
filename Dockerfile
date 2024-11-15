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

RUN echo -e "nobody\nnobody" | smbpasswd -a nobody

VOLUME /storage
EXPOSE 445

ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/samba.sh"]

HEALTHCHECK --interval=60s --timeout=15s CMD smbclient -L localhost --configfile=/etc/samba.conf -U nobody%nobody -m SMB3 -c 'exit'