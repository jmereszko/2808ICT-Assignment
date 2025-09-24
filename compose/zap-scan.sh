#!/bin/bash
API_KEY="MySecretKey123"
TARGET="http://localhost"   # or https://localhost if nginx is TLS-only

# 1. Spider the site
SCANID=$(curl -s "http://localhost:8080/JSON/spider/action/scan?apikey=${API_KEY}&url=${TARGET}&recurse=true" | jq -r .scan)

# Wait for spider to finish
while true; do
  STATUS=$(curl -s "http://localhost:8080/JSON/spider/view/status?apikey=${API_KEY}&scanId=${SCANID}" | jq -r .status)
  echo "Spider status: $STATUS%"
  [ "$STATUS" = "100" ] && break
  sleep 5
done

# 2. Active scan
ASCANID=$(curl -s "http://localhost:8080/JSON/ascan/action/scan?apikey=${API_KEY}&url=${TARGET}&recurse=true" | jq -r .scan)

# Wait for active scan to finish
while true; do
  STATUS=$(curl -s "http://localhost:8080/JSON/ascan/view/status?apikey=${API_KEY}&scanId=${ASCANID}" | jq -r .status)
  echo "Active scan status: $STATUS%"
  [ "$STATUS" = "100" ] && break
  sleep 10
done

# 3. Save HTML report
curl "http://localhost:8080/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o zap-report.html
echo "Report saved to zap-report.html"

