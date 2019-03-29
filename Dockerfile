
FROM golang:1.10-alpine as builder

ARG BUILD_DATE
ARG BUILD_TYPE
ARG BUILD_VERSION
ARG ETCD_VERSION

ENV \
  GOPATH=/opt/go \
  GOMAXPROCS=4

# ---------------------------------------------------------------------------------------

# hadolint ignore=DL3017,DL3018,DL3019
RUN \
  apk update  --quiet --no-cache && \
  apk upgrade --quiet --no-cache && \
  apk add     --quiet --no-cache \
    bash \
    g++ \
    git \
    make

# hadolint ignore=
RUN \
  echo "get sources ..." && \
  go get github.com/coreos/etcd

WORKDIR ${GOPATH}/src/github.com/coreos/etcd

RUN \
  if [ "${BUILD_TYPE}" == "stable" ] ; then \
    echo "switch to stable Tag v${ETCD_VERSION}" && \
    git checkout "tags/v${ETCD_VERSION}" 2> /dev/null ; \
  fi

RUN \
  export PATH=${GOPATH}/bin:${PATH} && \
  make && \
  cp -v bin/etcd* /usr/bin/ && \
  cp -v etcd.conf.yml.sample /etc/

# ---------------------------------------------------------------------------------------

FROM alpine:3.9

ENV \
  TZ='Europe/Berlin'
# hadolint ignore=DL3017,DL3018,DL3019
RUN \
  echo "export BUILD_DATE=${BUILD_DATE}"      > /etc/profile.d/etcd.sh && \
  echo "export BUILD_TYPE=${BUILD_TYPE}"     >> /etc/profile.d/etcd.sh && \
  echo "export ETCD_VERSION=${ETCD_VERSION}" >> /etc/profile.d/etcd.sh && \
  apk update  --quiet --no-cache && \
  apk upgrade --quiet --no-cache && \
  apk add     --quiet --no-cache --virtual .build-deps \
    shadow \
    tzdata && \
  cp "/usr/share/zoneinfo/${TZ}" /etc/localtime && \
  echo "${TZ}" > /etc/localtime && \
  mkdir -p \
    /var/etcd \
    /var/lib/etcd && \
  /usr/sbin/useradd \
    --user-group \
    --shell /bin/false \
    --comment "User for etcd" \
    --no-create-home \
    --home-dir /home/etcd \
    --uid 1000 \
    etcd && \
  mkdir -p /home/etcd/data && \
  chown -R etcd:etcd \
    /home/etcd \
    /var/etcd \
    /var/lib/etcd && \
  echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
  apk del --quiet --purge .build-deps && \
  rm -rf \
    /tmp/* \
    /src/* \
    /var/cache/apk/

COPY --from=builder /usr/bin/etcd* /usr/bin/
COPY --from=builder /etc/etcd.conf.yml.sample /etc/

VOLUME ["/etc","/data"]

ENTRYPOINT ["/usr/bin/etcd"]

CMD ["--data-dir", "/data", "--listen-client-urls 'http://0.0.0.0:2379'", "--advertise-client-urls 'http://0.0.0.0:2380'"]

EXPOSE 2379 2380

HEALTHCHECK \
  --interval=5s \
  --timeout=2s \
  --retries=12 \
  --start-period=10s \
  CMD ps ax | grep -v grep | grep -c etcd || exit 1

# ---------------------------------------------------------------------------------------

LABEL \
  version="${BUILD_VERSION}" \
  maintainer="Bodo Schulz <bodo@boone-schulz.de>" \
  org.label-schema.build-date=${BUILD_DATE} \
  org.label-schema.name="etcd Docker Image" \
  org.label-schema.description="Inofficial etcd Docker Image" \
  org.label-schema.url="https://coreos.com/etcd" \
  org.label-schema.vcs-url="https://github.com/bodsch/docker-etcd" \
  org.label-schema.vcs-ref=${VCS_REF} \
  org.label-schema.vendor="Bodo Schulz" \
  org.label-schema.version=${ETCD_VERSION} \
  org.label-schema.schema-version="1.0" \
  com.microscaling.docker.dockerfile="/Dockerfile" \
  com.microscaling.license="The Unlicense"

# ---------------------------------------------------------------------------------------
