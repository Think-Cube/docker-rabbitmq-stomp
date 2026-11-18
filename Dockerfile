FROM rabbitmq:4.4.1-alpine@sha256:6bf98f3f634a57951103efe3e9ff866b5d8b3faa35cc7be12b2ce052d8367a12

LABEL org.opencontainers.image.title="rabbitmq-stomp" \
      org.opencontainers.image.description="RabbitMQ with the management, STOMP and Web STOMP plugins enabled" \
      org.opencontainers.image.vendor="Think-Cube" \
      org.opencontainers.image.authors="contact@thinkcube.dev" \
      org.opencontainers.image.licenses="MIT"

# The upgrade is what lets the weekly rebuild pick up security patches
# while the base image stays pinned by digest.
RUN apk upgrade --no-cache

# Enable plugins as the rabbitmq user, the way the official image does, so the file stays writable at runtime.
RUN su-exec rabbitmq rabbitmq-plugins enable --offline rabbitmq_management rabbitmq_stomp rabbitmq_web_stomp

# Loaded after the official 10-defaults.conf, which opens the guest account to the network.
COPY --chown=rabbitmq:rabbitmq conf.d/30-guest-loopback.conf /etc/rabbitmq/conf.d/

# Management UI and HTTP API, Web STOMP, STOMP. AMQP 5672 is exposed by the base image.
EXPOSE 15672 15674 61613
