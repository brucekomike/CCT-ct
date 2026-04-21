#!/bin/bash
# docker compose file generator
# usage: $0 <servers> <port_start> <image_name> <filename>
if [ "$1" = "" ]; then
    echo "Usage: $0 <servers> <port_start> [image_name] [filename]"
    exit 1
fi
servers=$1
port_start=$2
image_name=${3-"ghcr.io/brucekomike/cct-ct:latest"}
filename=${4-"docker-compose.yaml"}

echo "services:" > $filename
for i in $(seq 1 $servers); do
    port=$((port_start + i - 1))
    echo "  env$i:" >> $filename
    echo "    image: $image_name" >> $filename
    echo "    ports:" >> $filename
    echo "      - \"$port:8080\"" >> $filename
    echo "    environment:" >> $filename
    echo "      - PASSWORD=code$port" >> $filename
    echo "    volumes:" >> $filename
    echo "      - ./env$i:/root/Workspace" >> $filename
done