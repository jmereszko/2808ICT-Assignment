#!/bin/bash
API_KEY="MySecretKey123"
ZAP_BASE="http://localhost:8080"
TARGET_IP="3.227.150.252"

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
# 1. MERN-SOCIAL
# -------------------
TARGET="https://${TARGET_IP}/"
echo "[*] Starting Spider on MERN-SOCIAL ($TARGET)"
SCANID=$(curl -s "${ZAP_BASE}/JSON/spider/action/scan/?apikey=${API_KEY}&url=${TARGET}&recurse=true" | jq -r .scan)
wait_for_scan spider $SCANID

echo "[*] Starting Active Scan on MERN-SOCIAL"
ASCANID=$(curl -s "${ZAP_BASE}/JSON/ascan/action/scan/?apikey=${API_KEY}&url=${TARGET}&recurse=true" | jq -r .scan)
wait_for_scan ascan $ASCANID

curl "${ZAP_BASE}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o zap-report-mern.html
echo "[+] MERN report saved to zap-report-mern.html"

# -------------------
# 2. MONGO-EXPRESS
# -------------------
TARGET="https://${TARGET_IP}/mongo-express/"
echo "[*] Starting Spider on MONGO-EXPRESS ($TARGET)"

# Add the site and auth to ZAP context (basic auth: admin:pass)
curl -s "${ZAP_BASE}/JSON/core/action/accessUrl/?apikey=${API_KEY}&url=${TARGET}&userId=" >/dev/null
curl -s "${ZAP_BASE}/JSON/context/action/includeInContext/?apikey=${API_KEY}&contextName=Default%20Context&regex=$(python3 -c "import urllib.parse; print(urllib.parse.quote('^${TARGET}.*'))")"

# Set basic auth credentials
curl -s "${ZAP_BASE}/JSON/authentication/action/setAuthenticationMethod/?apikey=${API_KEY}&contextId=1&authMethodName=basicAuthentication&authMethodConfig=$(python3 -c "import urllib.parse; print(urllib.parse.quote('hostname=${TARGET_IP}&realm=&port=443'))")"
curl -s "${ZAP_BASE}/JSON/users/action/newUser/?apikey=${API_KEY}&contextId=1&name=mongoUser" | jq
curl -s "${ZAP_BASE}/JSON/users/action/setAuthenticationCredentials/?apikey=${API_KEY}&contextId=1&userId=0&authCredentials=$(python3 -c "import urllib.parse; print(urllib.parse.quote('username=admin&password=pass'))")"
curl -s "${ZAP_BASE}/JSON/users/action/setUserEnabled/?apikey=${API_KEY}&contextId=1&userId=0&enabled=true"

# Run scans
SCANID=$(curl -s "${ZAP_BASE}/JSON/spider/action/scan/?apikey=${API_KEY}&url=${TARGET}&recurse=true" | jq -r .scan)
wait_for_scan spider $SCANID

echo "[*] Starting Active Scan on MONGO-EXPRESS"
ASCANID=$(curl -s "${ZAP_BASE}/JSON/ascan/action/scan/?apikey=${API_KEY}&url=${TARGET}&recurse=true" | jq -r .scan)
wait_for_scan ascan $ASCANID

curl "${ZAP_BASE}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o zap-report-mongo-express.html
echo "[+] Mongo-Express report saved to zap-report-mongo-express.html"
