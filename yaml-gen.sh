#!/bin/bash
# docker compose file generator
# usage: $0 <servers> <port_start> [version] [image_name] [filename] [ssl]
if [ "$1" = "" ]; then
    echo "Usage: $0 <servers> <port_start> [version] [image_name] [filename] [ssl]"
    echo "  version: 20.04 | 24.04 | 26.04 (default: 26.04)"
    echo "  ssl:     set to 'ssl' to enable self-signed SSL certificates (default: disabled)"
    exit 1
fi
servers=$1
port_start=$2
version=${3:-"26.04"}
image_name=${4:-"ghcr.io/brucekomike/cct-ct:$version"}
filename=${5:-"docker-compose.yaml"}
ssl_enabled=${6:-""}
CERT_DIR="./certs"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/key.pem"

if [ "$ssl_enabled" = "ssl" ] || [ "$ssl_enabled" = "true" ]; then
    if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
        echo "Error: SSL certificate not found in $CERT_DIR/"
        echo "  Run ./cert-gen.sh <domain> to generate one first."
        exit 1
    fi
    echo "SSL enabled. Using certificates from $CERT_DIR/"
fi

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
    # Mount certificates and override command if SSL is enabled
    if [ "$ssl_enabled" = "ssl" ] || [ "$ssl_enabled" = "true" ]; then
        echo "      - $CERT_FILE:/certs/cert.pem:ro" >> "$filename"
        echo "      - $KEY_FILE:/certs/key.pem:ro" >> "$filename"
        echo "    command:" >> "$filename"
        echo "      - code-server" >> "$filename"
        echo "      - --auth" >> "$filename"
        echo "      - password" >> "$filename"
        echo "      - --host" >> "$filename"
        echo "      - 0.0.0.0" >> "$filename"
        echo "      - --port" >> "$filename"
        echo "      - \"8080\"" >> "$filename"
        echo "      - --cert" >> "$filename"
        echo "      - /certs/cert.pem" >> "$filename"
        echo "      - --cert-key" >> "$filename"
        echo "      - /certs/key.pem" >> "$filename"
    fi
    echo "    deploy:" >> "$filename"
    echo "      resources:" >> "$filename"
    echo "        reservations:" >> "$filename"
    echo "          devices:" >> "$filename"
    echo "            - driver: nvidia" >> "$filename"
    echo "              count: all" >> "$filename"
    echo "              capabilities: [gpu]" >> "$filename"
done

if [ "$ssl_enabled" = "ssl" ] || [ "$ssl_enabled" = "true" ]; then
    echo ""
    echo "SSL enabled. Access code-server via https://localhost:<port>"
    echo "  Note: Browsers will show a security warning for self-signed certificates."
    echo "  You can safely proceed (click 'Advanced' → 'Proceed to localhost')."
fi
