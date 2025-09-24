#!/bin/bash
API_KEY="MySecretKey123"
ZAP_BASE="http://localhost:8080"

# Helper function to wait for scan completion
wait_for_scan() {
  local TYPE=$1
  local ID=$2
  while true; do
    STATUS=$(curl -s "${ZAP_BASE}/JSON/${TYPE}/view/status/?apikey=${API_KEY}&scanId=${ID}" | jq -r .status)
    echo "${TYPE} status: $STATUS%"
    [ "$STATUS" = "100" ] && break
    sleep 5
  done
}

# -------------------
# 1. MERN-SOCIAL (internal Docker host)
# -------------------
TARGET="https://compose-nginx-1/"
echo "[*] Starting Spider on MERN-SOCIAL ($TARGET)"
SCANID=$(curl -s "${ZAP_BASE}/JSON/spider/action/scan/?apikey=${API_KEY}&url=${TARGET}&recurse=true&ignoreCertificateErrors=true" | jq -r .scan)
wait_for_scan spider $SCANID

echo "[*] Starting Active Scan on MERN-SOCIAL"
ASCANID=$(curl -s "${ZAP_BASE}/JSON/ascan/action/scan/?apikey=${API_KEY}&url=${TARGET}&recurse=true&ignoreCertificateErrors=true" | jq -r .scan)
wait_for_scan ascan $ASCANID

curl "${ZAP_BASE}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o zap-report-mern.html
echo "[+] MERN report saved to zap-report-mern.html"

# -------------------
# 2. MONGO-EXPRESS (internal Docker host)
# -------------------
TARGET="https://compose-nginx-1/mongo-express/"
echo "[*] Starting Spider on MONGO-EXPRESS ($TARGET)"

SCANID=$(curl -s "${ZAP_BASE}/JSON/spider/action/scan/?apikey=${API_KEY}&url=${TARGET}&recurse=true&ignoreCertificateErrors=true" | jq -r .scan)
wait_for_scan spider $SCANID

echo "[*] Starting Active Scan on MONGO-EXPRESS"
ASCANID=$(curl -s "${ZAP_BASE}/JSON/ascan/action/scan/?apikey=${API_KEY}&url=${TARGET}&recurse=true&ignoreCertificateErrors=true" | jq -r .scan)
wait_for_scan ascan $ASCANID

curl "${ZAP_BASE}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o zap-report-mongo-express.html
echo "[+] Mongo-Express report saved to zap-report-mongo-express.html"
