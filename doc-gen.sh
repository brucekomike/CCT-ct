#!/bin/bash
# generate connection docs with code-server URLs defaulting to /root/Workspace
# usage: $0 <count> [ip]
if [ "$1" = "" ]; then
    echo "Usage: $0 <count> [ip]"
    exit 1
fi
count=$1
IP=${2:-"localhost"}

for i in $(seq 1 "$count"); do
  port=$((9000 + i))
  URL="http://$IP:$port/?folder=/root/Workspace"
  echo "password: code$port"
  echo "$URL"
  echo ""
done
