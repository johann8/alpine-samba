ARG ARCH=

ARG BASE_IMAGE=alpine:3.18

FROM ${ARCH}${BASE_IMAGE}

ARG BUILD_DATE

ARG VCS_REF

LABEL org.label-schema.schema-version="1.0" \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name=phpldapadmin \
      org.label-schema.authors="Johann H. <>" \ 
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/johann8/samba" \
      org.label-schema.description="Docker container with Samba AD DC based on Alpine Linux"

ARG SAMBA_DC_VERSION=4.18.5-r0

ENV TZ=Europe/Berlin

# Install packages
RUN apk --no-cache add \
        bash \
        krb5 \
        openldap-clients \
        samba-dc=${SAMBA_DC_VERSION} \
        #samba-winbind \
        samba-winbind-clients \
        bind-tools \
        supervisor \
        ldb-tools \
        rsyslog \
        tdb \
        py3-tdb \
        tzdata \
        acl \
        pwgen \
    # Remove alpine cache
    && rm -rf /var/cache/apk/*

# copy files
COPY rootfs/ /

RUN chmod 755 /bin/docker-entrypoint.sh

EXPOSE 53 389 88 135 139 138 445 464 3268 3269

VOLUME ["/var/lib/samba","[/etc/samba/]","[/var/lib/krb5kdc]"]

ENTRYPOINT ["/bin/docker-entrypoint.sh"]

CMD ["app:start"]
