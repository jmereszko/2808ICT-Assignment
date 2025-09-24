#!/bin/bash
API_KEY="MySecretKey123"
ZAP="http://localhost:8080"
TARGET_APP="https://compose-nginx-1"
TARGET_ME="https://compose-nginx-1/mongo-express/"

# Wait for ZAP ready
echo "[*] Waiting for ZAP..."
for i in {1..60}; do
  v=$(curl -s "${ZAP}/JSON/core/view/version/?apikey=${API_KEY}" | jq -r .version 2>/dev/null)
  [ -n "$v" ] && { echo "[+] ZAP ready: $v"; break; }
  sleep 1
done

# ---- MERN Social (classic spider + ascan) ----
echo "[*] Spider MERN: ${TARGET_APP}"
SCANID=$(curl -s "${ZAP}/JSON/spider/action/scan?apikey=${API_KEY}&url=${TARGET_APP}&recurse=true" | jq -r .scan)
while true; do
  STATUS=$(curl -s "${ZAP}/JSON/spider/view/status?apikey=${API_KEY}&scanId=${SCANID}" | jq -r .status)
  echo "spider status: ${STATUS}%"
  [ "$STATUS" = "100" ] && break
  sleep 3
done

echo "[*] Active scan MERN"
ASCANID=$(curl -s "${ZAP}/JSON/ascan/action/scan?apikey=${API_KEY}&url=${TARGET_APP}&recurse=true&inScopeOnly=false" | jq -r .scan)
while true; do
  STATUS=$(curl -s "${ZAP}/JSON/ascan/view/status?apikey=${API_KEY}&scanId=${ASCANID}" | jq -r .status)
  echo "ascan status: ${STATUS}%"
  [ "$STATUS" = "100" ] && break
  sleep 5
done
curl -s "${ZAP}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o zap-report-mern.html
echo "[+] Saved zap-report-mern.html"

# ---- Mongo Express (classic spider + ascan) ----
echo "[*] Spider Mongo-Express: ${TARGET_ME}"
SCANID=$(curl -s "${ZAP}/JSON/spider/action/scan?apikey=${API_KEY}&url=${TARGET_ME}&recurse=true" | jq -r .scan)
while true; do
  STATUS=$(curl -s "${ZAP}/JSON/spider/view/status?apikey=${API_KEY}&scanId=${SCANID}" | jq -r .status)
  echo "spider status: ${STATUS}%"
  [ "$STATUS" = "100" ] && break
  sleep 3
done

echo "[*] Active scan Mongo-Express"
ASCANID=$(curl -s "${ZAP}/JSON/ascan/action/scan?apikey=${API_KEY}&url=${TARGET_ME}&recurse=true&inScopeOnly=false" | jq -r .scan)
while true; do
  STATUS=$(curl -s "${ZAP}/JSON/ascan/view/status?apikey=${API_KEY}&scanId=${ASCANID}" | jq -r .status)
  echo "ascan status: ${STATUS}%"
  [ "$STATUS" = "100" ] && break
  sleep 5
done
curl -s "${ZAP}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o zap-report-mongo-express.html
echo "[+] Saved zap-report-mongo-express.html"
