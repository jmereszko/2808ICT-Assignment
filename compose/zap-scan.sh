# Run ZAP image on the same network
docker rm -f zap # Remove existing zap containers
docker run -u zap --name zap -p 8080:8080 \
  --network compose_frontend \
  -d ghcr.io/zaproxy/zaproxy:stable zap.sh -daemon -port 8080 -host 0.0.0.0 -config api.key=MySecretKey123

#!/bin/bash
API_KEY="MySecretKey123"
ZAP_BASE="http://localhost:8080"

# Helper to wait for an active scan to finish
wait_for_ascan() {
  local ID=$1
  while true; do
    STATUS=$(curl -s "${ZAP_BASE}/JSON/ascan/view/status/?apikey=${API_KEY}&scanId=${ID}" | jq -r .status)
    echo "Active scan status: $STATUS%"
    [ "$STATUS" = "100" ] && break
    sleep 10
  done
}

# -------------------
# 1. MERN-SOCIAL (scan known routes directly)
# -------------------
MERN_URLS=(
  "https://compose-nginx-1/"
  "https://compose-nginx-1/signin"
  "https://compose-nginx-1/signup"
)

for URL in "${MERN_URLS[@]}"; do
  echo "[*] Starting Active Scan on MERN-SOCIAL ($URL)"
  ASCANID=$(curl -s "${ZAP_BASE}/JSON/ascan/action/scan/?apikey=${API_KEY}&url=${URL}&recurse=true&inScopeOnly=false&ignoreCertificateErrors=true" | jq -r .scan)
  wait_for_ascan $ASCANID
done

curl "${ZAP_BASE}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o zap-report-mern.html
echo "[+] MERN Social report saved to zap-report-mern.html"

# -------------------
# 2. MONGO-EXPRESS
# -------------------
MONGO_URL="https://compose-nginx-1/mongo-express/"
echo "[*] Starting Active Scan on MONGO-EXPRESS ($MONGO_URL)"
ASCANID=$(curl -s "${ZAP_BASE}/JSON/ascan/action/scan/?apikey=${API_KEY}&url=${MONGO_URL}&recurse=true&inScopeOnly=false&ignoreCertificateErrors=true" | jq -r .scan)
wait_for_ascan $ASCANID

curl "${ZAP_BASE}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o zap-report-mongo-express.html
echo "[+] Mongo Express report saved to zap-report-mongo-express.html"
