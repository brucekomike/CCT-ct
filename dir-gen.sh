#!/bin/bash
# usage $0 <amount> <dirname>
if [ "$1" = "" ]; then
    echo "Usage: $0 <amount> <dirname>"
    exit 1
fi
amount=$1
dirname=$2
for i in $(seq 1 $amount); do
    cp -r $dirname env$i
done