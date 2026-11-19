#!/usr/bin/env bash
# Docker healthcheck: send a UDP getstatus query to the local server and
# expect a statusResponse, the same query rcon/rcon-status.py sends.
set -euo pipefail

port="${GAME_PORT:-12203}"
exec 3<>"/dev/udp/127.0.0.1/$port"
printf '\xff\xff\xff\xff\x02getstatus' >&3
# One read() of the whole datagram: bash's own `read` takes a byte per call
# and the kernel drops the rest of a UDP datagram after the first read.
reply="$(timeout 3 dd bs=4096 count=1 <&3 2>/dev/null | tr -d '\000' | head -c 64 || true)"
exec 3>&-
[[ "$reply" == *statusResponse* ]]
