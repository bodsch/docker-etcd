
FROM golang:1.10-alpine as builder

ARG BUILD_DATE
ARG BUILD_TYPE
ARG BUILD_VERSION
ARG ETCD_VERSION

# ---------------------------------------------------------------------------------------

RUN \
  apk update --no-cache && \
  apk upgrade --no-cache && \
  apk add \
    bash git make zip

RUN \
  export GOPATH=/opt/go && \
  echo "get sources ..." && \
  go get github.com/coreos/etcd || true && \
  cd ${GOPATH}/src/github.com/coreos/etcd && \
  if [ "${BUILD_TYPE}" == "stable" ] ; then \
    echo "switch to stable Tag v${ETCD_VERSION}" && \
    git checkout tags/v${ETCD_VERSION} 2> /dev/null ; \
  fi

RUN \
  export GOPATH=/opt/go && \
  export PATH=${GOPATH}/bin:${PATH} && \
  cd ${GOPATH}/src/github.com/coreos/etcd && \
  export GOMAXPROCS=4 && \
  make && \
  cp -v bin/etcd* /usr/bin/ && \
  cp -v etcd.conf.yml.sample /etc/

CMD ["/bin/bash"]

# ---------------------------------------------------------------------------------------

FROM alpine:latest

EXPOSE 2379 2380

LABEL \
  version="${BUILD_VERSION}" \
  maintainer="Bodo Schulz <bodo@boone-schulz.de>" \
  org.label-schema.build-date=${BUILD_DATE} \
  org.label-schema.name="Consul Docker Image" \
  org.label-schema.description="Inofficial Consul Docker Image" \
  org.label-schema.url="https://coreos.com/etcd" \
  org.label-schema.vcs-url="https://github.com/bodsch/docker-etcd" \
  org.label-schema.vendor="Bodo Schulz" \
  org.label-schema.version=${ETCD_VERSION} \
  org.label-schema.schema-version="1.0" \
  com.microscaling.docker.dockerfile="/Dockerfile" \
  com.microscaling.license="The Unlicense"

COPY --from=builder /usr/bin/etcd* /usr/bin/
COPY --from=builder /etc/etcd.conf.yml.sample /etc/

RUN \
  echo 'hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4' >> /etc/nsswitch.conf && \
  mkdir -p /var/etcd/ /var/lib/etcd/

VOLUME [ "/data" ]

ENTRYPOINT [ "/usr/bin/etcd" ]

CMD [ "--data-dir", "/data", "--listen-client-urls", "'http://0.0.0.0:2379'", "--advertise-client-urls", "http://0.0.0.0:2380" ]

# ---------------------------------------------------------------------------------------
