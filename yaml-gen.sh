#!/bin/bash
# docker compose file generator
# usage: $0 <servers> <port_start> [version] [image_name] [filename]
if [ "$1" = "" ]; then
    echo "Usage: $0 <servers> <port_start> [version] [image_name] [filename]"
    echo "  version: 20.04 | 24.04 | 26.04 (default: 26.04)"
    exit 1
fi
servers=$1
port_start=$2
version=${3:-"26.04"}
image_name=${4:-"ghcr.io/brucekomike/cct-ct:$version"}
filename=${5:-"docker-compose.yaml"}

echo "services:" > "$filename"
for i in $(seq 1 "$servers"); do
    port=$((port_start + i - 1))
    echo "  env$i:" >> "$filename"
    echo "    image: $image_name" >> "$filename"
    echo "    runtime: nvidia" >> "$filename"
    echo "    ports:" >> "$filename"
    echo "      - \"$port:8080\"" >> "$filename"
    echo "    environment:" >> "$filename"
    echo "      - PASSWORD=code$port" >> "$filename"
    echo "    volumes:" >> "$filename"
    echo "      - ./env$i:/root/Workspace" >> "$filename"
    echo "      - ./opt:/opt" >> "$filename"
    echo "    deploy:" >> "$filename"
    echo "      resources:" >> "$filename"
    echo "        reservations:" >> "$filename"
    echo "          devices:" >> "$filename"
    echo "            - driver: nvidia" >> "$filename"
    echo "              count: all" >> "$filename"
    echo "              capabilities: [gpu]" >> "$filename"
done
