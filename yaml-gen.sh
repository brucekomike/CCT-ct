#!/bin/bash
# docker compose file generator

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -c, --count <count>       Server count (default: 5)"
    echo "  -p, --port <port>         Starting host port (default: 9001)"
    echo "  -n, --name <name>         Container base name (default: cct-ct)"
    echo "                            If name does not start with cct-ct, cct-ct- is prefixed"
    echo "  -i, --image <image>       Image name suffix (default: cct-ct)"
    echo "                            If image does not start with cct-ct, cct-ct- is prefixed"
    echo "  -v, --version <version>   Image tag version (default: main)"
    echo "  -f, --filename <file>     Output filename (default: docker-compose.yaml)"
    echo "  -s, --ssl                 Enable self-signed SSL certificates"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Legacy positional format is still supported:"
    echo "  $0 <servers> <port_start> [version] [image] [filename] [ssl]"
}

servers=5
port_start=9001
container_name_input="cct-ct"
image_input="cct-ct"
version="main"
filename="docker-compose.yaml"
ssl_enabled="false"
image_name=""

if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
    servers=$1
    port_start=$2
    version=${3:-"main"}
    image_input=${4:-"cct-ct"}
    filename=${5:-"docker-compose.yaml"}
    if [ "$6" = "ssl" ] || [ "$6" = "true" ]; then
        ssl_enabled="true"
    fi
else
    while [ $# -gt 0 ]; do
        case "$1" in
            -c|--count)
                servers=$2
                shift 2
                ;;
            -p|--port)
                port_start=$2
                shift 2
                ;;
            -n|--name)
                container_name_input=$2
                shift 2
                ;;
            -i|--image)
                image_input=$2
                shift 2
                ;;
            -v|--version)
                version=$2
                shift 2
                ;;
            -f|--filename)
                filename=$2
                shift 2
                ;;
            -s|--ssl)
                ssl_enabled="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
fi

if [ -z "$image_input" ]; then
    image_base="cct-ct"
elif [[ "$image_input" == */* ]]; then
    if [[ "$image_input" == *:* ]]; then
        image_name="$image_input"
    else
        image_name="${image_input}:$version"
    fi
else
    if [[ "$image_input" == cct-ct* ]]; then
        image_base="$image_input"
    else
        image_base="cct-ct-$image_input"
    fi
fi

if [ -z "$image_name" ]; then
    image_name="ghcr.io/brucekomike/${image_base}:$version"
fi

if [ -z "$container_name_input" ]; then
    container_name_base="cct-ct"
elif [[ "$container_name_input" == cct-ct* ]]; then
    container_name_base="$container_name_input"
else
    container_name_base="cct-ct-$container_name_input"
fi

case "$servers" in
    ''|*[!0-9]*)
        echo "Error: --count must be a positive integer."
        exit 1
        ;;
esac

case "$port_start" in
    ''|*[!0-9]*)
        echo "Error: --port must be a positive integer."
        exit 1
        ;;
esac

if [ "$servers" -lt 1 ]; then
    echo "Error: --count must be at least 1."
    exit 1
fi

if [ "$port_start" -lt 1 ]; then
    echo "Error: --port must be at least 1."
    exit 1
fi

CERT_DIR="./certs"
CERT_FILE="$CERT_DIR/cert.pem"
KEY_FILE="$CERT_DIR/key.pem"

if [ "$ssl_enabled" = "true" ]; then
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
    container_name="$container_name_base"
    if [ "$servers" -gt 1 ]; then
        container_name="${container_name_base}-${i}"
    fi

    echo "  env$i:" >> "$filename"
    echo "    image: $image_name" >> "$filename"
    echo "    container_name: $container_name" >> "$filename"
    echo "    runtime: nvidia" >> "$filename"
    echo "    ports:" >> "$filename"
    echo "      - \"$port:8080\"" >> "$filename"
    echo "    environment:" >> "$filename"
    echo "      - PASS""WORD=code$port" >> "$filename"
    echo "    volumes:" >> "$filename"
    echo "      - ./env$i:/root/Workspace" >> "$filename"
    echo "      - opt-data:/opt" >> "$filename"

    if [ "$ssl_enabled" = "true" ]; then
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

echo "volumes:" >> "$filename"
echo "  opt-data:" >> "$filename"

if [ "$ssl_enabled" = "true" ]; then
    echo ""
    echo "SSL enabled. Access code-server via https://localhost:<port>"
    echo "  Note: Browsers will show a security warning for self-signed certificates."
    echo "  You can safely proceed (click 'Advanced' → 'Proceed to localhost')."
fi
