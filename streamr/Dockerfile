ARG UPSTREAM_VERSION

FROM streamr/node:${UPSTREAM_VERSION}

USER root

RUN apt-get update && apt-get --assume-yes --no-install-recommends install \
	openssl jq uuid-runtime \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/streamr/.streamr && chown -R streamr:streamr /home/streamr/.streamr

USER streamr

COPY entrypoint.sh /usr/local/bin

WORKDIR /home/streamr/network/packages/broker

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]


