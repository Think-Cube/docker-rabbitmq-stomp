# docker-rabbitmq-stomp

[RabbitMQ](https://www.rabbitmq.com/) with the management, STOMP and Web STOMP plugins enabled, built on the official `rabbitmq` Alpine image.

Images are built for `linux/amd64` and `linux/arm64` and ship with an SBOM, build provenance and a keyless signature. The broker runs as the `rabbitmq` user.

## Images

Images are published to GitHub Container Registry as `ghcr.io/think-cube/rabbitmq-stomp`.

| Tag | Meaning | Changes? |
|---|---|---|
| `2.0.0` | Exact release | Never |
| `2.0`, `2`, `latest` | Newest matching release | With each release |
| `edge` | Newest build of `main` | With each merge and weekly rebuild |
| `edge-YYYYMMDD` | Weekly rebuild of `main` with current OS patches | Never |
| `sha-<commit>` | Build of one `main` commit | Never |

For production, pin by digest: `ghcr.io/think-cube/rabbitmq-stomp:2.0.0@sha256:...`.

The RabbitMQ version is on the `FROM` line of the `Dockerfile`. Patch releases arrive automatically; a new RabbitMQ minor version is adopted deliberately, because it can require a staged upgrade of existing data (see [Upgrading](#upgrading)).

## Usage

```bash
docker run -d --name rabbitmq \
  -e RABBITMQ_DEFAULT_USER=admin \
  -e RABBITMQ_DEFAULT_PASS='change-me' \
  -v rabbitmq-data:/var/lib/rabbitmq \
  -p 5672:5672 -p 15672:15672 -p 15674:15674 -p 61613:61613 \
  ghcr.io/think-cube/rabbitmq-stomp:2
```

| Port | Protocol |
|---|---|
| `5672` | AMQP |
| `15672` | Management UI and HTTP API |
| `15674` | STOMP over WebSockets, at `/ws` |
| `61613` | STOMP |

Always set `RABBITMQ_DEFAULT_USER` and `RABBITMQ_DEFAULT_PASS`. The built-in `guest` account only works from inside the container, so it cannot be used to log in to the management UI or to connect clients over the network. This overrides the official image, which opens `guest` to the network.

To change other settings, mount additional files into `/etc/rabbitmq/conf.d/`. They are loaded in alphabetical order.

Run CLI tools as the `rabbitmq` user, for example `docker exec -u rabbitmq rabbitmq rabbitmqctl status`. Running them as root before the broker has finished starting creates an Erlang cookie the broker cannot read, and it fails to boot.

## Upgrading

Image 2.x contains RabbitMQ 4.4. Earlier releases of this image contained RabbitMQ 4.1, and RabbitMQ does not support upgrading a node with existing data from 4.1 directly to 4.4. If you keep data in a volume:

1. Run the official `rabbitmq:4.2-alpine` image on the same volume until it has started.
2. Enable all feature flags: `docker exec -u rabbitmq rabbitmq rabbitmqctl enable_feature_flag all`.
3. Stop it and start this image's 2.x release on the same volume.

Without persistent data, or when migrating to a fresh cluster (blue-green), you can switch directly. See the [RabbitMQ upgrade guide](https://www.rabbitmq.com/docs/upgrade).

## Verify an image

Check the signature:

```bash
cosign verify ghcr.io/think-cube/rabbitmq-stomp:2.0.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/Think-Cube/workflows/\.github/workflows/container-image\.yml@refs/tags/v.+$'
```

Read the SBOM and provenance:

```bash
docker buildx imagetools inspect ghcr.io/think-cube/rabbitmq-stomp:2.0.0 --format '{{ json .SBOM }}'
docker buildx imagetools inspect ghcr.io/think-cube/rabbitmq-stomp:2.0.0 --format '{{ json .Provenance }}'
```

## Build and test locally

```bash
docker build -t rabbitmq-stomp:local .
bash tests/smoke.sh rabbitmq-stomp:local
```

The smoke test starts the broker, checks that it runs as `rabbitmq` with the three plugins enabled and that `guest` is refused from outside, then connects over the HTTP API, STOMP and Web STOMP.

## Support

Only the newest release receives fixes. `main` is rebuilt every week, and images with fixable critical vulnerabilities are not published. Report security issues through [GitHub private vulnerability reporting](https://github.com/Think-Cube/docker-rabbitmq-stomp/security/advisories/new).

## License

This project is licensed under the [MIT License](LICENSE).

## Contribution

Feel free to contribute by opening issues or pull requests. Your feedback and improvements are highly appreciated!
