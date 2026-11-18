FROM rabbitmq:4.4.1-alpine@sha256:6bf98f3f634a57951103efe3e9ff866b5d8b3faa35cc7be12b2ce052d8367a12

LABEL org.opencontainers.image.title="rabbitmq-stomp" \
      org.opencontainers.image.description="RabbitMQ with the management, STOMP and Web STOMP plugins enabled" \
      org.opencontainers.image.vendor="Think-Cube" \
      org.opencontainers.image.authors="contact@thinkcube.dev" \
      org.opencontainers.image.licenses="MIT"

# The upgrade is what lets the weekly rebuild pick up security patches
# while the base image stays pinned by digest. The plugin setup follows the
# official management image: re-enable the metrics the UI needs, keep the
# plugin list writable by rabbitmq, and leave no build-time Erlang cookie behind.
RUN apk upgrade --no-cache && \
    rabbitmq-plugins enable --offline rabbitmq_management rabbitmq_stomp rabbitmq_web_stomp && \
    rm -f /etc/rabbitmq/conf.d/20-management_agent.disable_metrics_collector.conf && \
    chown rabbitmq:rabbitmq /etc/rabbitmq/enabled_plugins && \
    rm -f "$RABBITMQ_DATA_DIR/.erlang.cookie"

# Loaded after the official 10-defaults.conf, which opens the guest account to the network.
COPY --chown=rabbitmq:rabbitmq conf.d/30-guest-loopback.conf /etc/rabbitmq/conf.d/

# Management UI and HTTP API, Web STOMP, STOMP. AMQP 5672 is exposed by the base image.
EXPOSE 15672 15674 61613
