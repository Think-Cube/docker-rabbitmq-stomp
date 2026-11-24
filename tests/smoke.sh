#!/usr/bin/env bash
set -euo pipefail

image=${1:?usage: smoke.sh <image>}
name=rabbitmq-smoke-$$
user=smoke
pass=smoke-pass

cleanup() {
  docker rm -f "$name" > /dev/null 2>&1 || true
}
trap cleanup EXIT

docker run -d --name "$name" \
  -p 127.0.0.1::15672 -p 127.0.0.1::15674 -p 127.0.0.1::61613 "$image" > /dev/null

for _ in $(seq 1 90); do
  docker exec -u rabbitmq "$name" rabbitmq-diagnostics -q check_running > /dev/null 2>&1 && break
  sleep 2
done
if ! docker exec -u rabbitmq "$name" rabbitmq-diagnostics -q check_running; then
  docker logs "$name"
  exit 1
fi
docker exec -u rabbitmq "$name" rabbitmq-diagnostics -q server_version

# The broker runs as rabbitmq, not root. Output is captured before matching: piping
# into grep -q can end the writer with SIGPIPE, which pipefail reports as a failure.
processes=$(docker exec -u rabbitmq "$name" ps -o user,comm)
awk '$2 ~ /beam/ && $1 == "rabbitmq" { found = 1 } END { exit !found }' <<< "$processes"

plugins=$(docker exec -u rabbitmq "$name" rabbitmq-plugins list -e -m)
for plugin in rabbitmq_management rabbitmq_stomp rabbitmq_web_stomp; do
  grep -qx "$plugin" <<< "$plugins"
done

port() {
  docker port "$name" "$1/tcp" | head -1 | cut -d: -f2
}
api="http://127.0.0.1:$(port 15672)/api/overview"

# guest must be refused from outside the container.
for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -u guest:guest "$api" || true)
  [ "$code" != "000" ] && break
  sleep 1
done
test "$code" = "401"

docker exec -u rabbitmq "$name" rabbitmqctl -q add_user "$user" "$pass" > /dev/null
docker exec -u rabbitmq "$name" rabbitmqctl -q set_user_tags "$user" administrator > /dev/null
docker exec -u rabbitmq "$name" rabbitmqctl -q set_permissions -p / "$user" '.*' '.*' '.*' > /dev/null

# Management HTTP API.
overview=$(curl -fsS -u "$user:$pass" "$api")
grep -q '"rabbitmq_version"' <<< "$overview"

# STOMP: a CONNECT frame must be answered with CONNECTED.
python3 - "$(port 61613)" "$user" "$pass" << 'PY'
import socket, sys

port, user, password = int(sys.argv[1]), sys.argv[2], sys.argv[3]
with socket.create_connection(("127.0.0.1", port), timeout=10) as s:
    s.sendall(f"CONNECT\naccept-version:1.2\nhost:/\nlogin:{user}\npasscode:{password}\n\n\x00".encode())
    reply = s.recv(1024)
if not reply.startswith(b"CONNECTED"):
    sys.exit(f"unexpected STOMP reply: {reply!r}")
print("STOMP CONNECTED")
PY

# Web STOMP: the WebSocket endpoint must accept the upgrade.
headers=$(curl -s -i --max-time 5 \
  -H 'Connection: Upgrade' -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Protocol: v12.stomp' \
  "http://127.0.0.1:$(port 15674)/ws" || true)
grep -q '^HTTP/1.1 101' <<< "$headers"
echo "Web STOMP upgrade accepted"
