#!/bin/bash
# usage $0 <amount>
if [ "$1" = "" ]; then
    echo "Usage: $0 <amount>"
    exit 1
fi
amount=$1
for i in $(seq 1 $amount); do
    rm -rf env$i
done