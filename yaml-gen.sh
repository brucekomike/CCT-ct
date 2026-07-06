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
    echo "  -m, --claude-settings <file>  Map host .claude/settings.json into container"
    echo "  -H, --hostname <pattern>  Hostname pattern, %d replaced by instance number"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Legacy positional format is still supported:"
    echo "  $0 <servers> <port_start> [version] [image] [filename] [ssl] [claude_settings] [hostname]"
}

if [[ -z "$1" ]]; then
    show_usage
    exit 1
fi

servers=5
port_start=9001
container_name_input="cct-ct"
image_input="cct-ct"
version="main"
filename="docker-compose.yaml"
ssl_enabled="false"
claude_settings_path=""
hostname_pattern=""
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
    claude_settings_path=${7:-""}
    hostname_pattern=${8:-""}
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
            -m|--claude-settings)
                claude_settings_path=$2
                shift 2
                ;;
            -H|--hostname)
                hostname_pattern=$2
                shift 2
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

if [ -n "$claude_settings_path" ] && [ ! -f "$claude_settings_path" ]; then
    echo "Error: --claude-settings file not found: $claude_settings_path"
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

    tee -a "$filename" << EOF
  env${i}:
    image: $image_name
    container_name: $container_name
EOF

    if [ -n "$hostname_pattern" ]; then
        resolved_hostname=$(echo "$hostname_pattern" | sed "s/%d/${i}/g")
        echo "    hostname: $resolved_hostname" >> "$filename"
    fi

    tee -a "$filename" << EOF
    runtime: nvidia
    ports:
      - "$port:8080"
    environment:
      - PASSWORD=code$port
    volumes:
      - ./env${i}:/root/Workspace
      - opt-data:/opt
EOF

    if [ -n "$claude_settings_path" ]; then
        echo "      - $claude_settings_path:/root/.claude/settings.json:ro" >> "$filename"
    fi

    if [ "$ssl_enabled" = "true" ]; then
        tee -a "$filename" << EOF
      - $CERT_FILE:/certs/cert.pem:ro
      - $KEY_FILE:/certs/key.pem:ro
    command:
      - code-server
      - --auth
      - password
      - --host
      - 0.0.0.0
      - --port
      - "8080"
      - --cert
      - /certs/cert.pem
      - --cert-key
      - /certs/key.pem
EOF
    fi

    tee -a "$filename" << EOF
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
EOF
done

echo "volumes:" >> "$filename"
echo "  opt-data:" >> "$filename"

if [ "$ssl_enabled" = "true" ]; then
    echo ""
    echo "SSL enabled. Access code-server via https://localhost:<port>"
    echo "  Note: Browsers will show a security warning for self-signed certificates."
    echo "  You can safely proceed (click 'Advanced' → 'Proceed to localhost')."
fi
