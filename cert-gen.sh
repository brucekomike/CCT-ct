#!/bin/bash
# Self-signed SSL certificate generator
# usage: $0 [domain] [output_dir]
if [ "$1" = "" ]; then
    echo "Usage: $0 <domain> [output_dir]"
    echo "  domain:     domain name for the certificate (e.g. localhost, example.com)"
    echo "  output_dir: directory to save cert and key (default: ./certs)"
    exit 1
fi
domain=$1
outdir=${2:-"./certs"}
CERT_FILE="$outdir/cert.pem"
KEY_FILE="$outdir/key.pem"

if [ -f "$CERT_FILE" ] || [ -f "$KEY_FILE" ]; then
    echo "Certificate already exists in $outdir/"
    echo "  Remove $CERT_FILE and $KEY_FILE to regenerate."
    exit 1
fi

mkdir -p "$outdir"

echo "Generating self-signed SSL certificate for $domain..."
openssl req -x509 -newkey rsa:4096 \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" \
    -days 3650 -nodes \
    -subj "/C=US/ST=State/L=City/O=Dev/CN=$domain" \
    -addext "subjectAltName=DNS:$domain,DNS:*.$domain,IP:127.0.0.1,IP:0.0.0.0" \
    2>/dev/null

if [ $? -eq 0 ]; then
    echo "  Certificate: $CERT_FILE"
    echo "  Private key:  $KEY_FILE"
    echo "  Expires:      10 years"
    echo ""
    echo "Done. Use 'ssl' as the last argument to yaml-gen.sh to enable SSL."
else
    echo "Error: Failed to generate certificate. Is openssl installed?"
    exit 1
fi
