#!/bin/bash

for num in $(seq 9001 9030); do
  URL="http://$IP:$num"
  echo " password: code$num"
  echo " $URL"
  echo ""
done
