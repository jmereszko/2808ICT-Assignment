#!/usr/bin/env bash
set -euo pipefail

API_KEY="MySecretKey123"
ZAP_BASE="http://localhost:8080"
TARGET_HOST="compose-nginx-1"                # internal Docker service name
TARGET_BASE="https://${TARGET_HOST}"
CONTEXT_NAME="AssignmentContext"
CONTEXT_ID=1   # pragmatic default; change if your ZAP uses different IDs
MONGO_USER="admin"
MONGO_PASS="pass"
REPORT_DIR="./zap-evidence"
mkdir -p "$REPORT_DIR"

SEED_PATHS=(
  "/"
  "/signin"
  "/signup"
  "/api"
  "/admin"
  "/upload"
  "/opc/v1/instance"
  "/mongo-express/"
)

urlenc(){ python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"; }

wait_for_zap(){
  for i in {1..60}; do
    v=$(curl -s "${ZAP_BASE}/JSON/core/view/version/?apikey=${API_KEY}" | jq -r .version 2>/dev/null || true)
    [ -n "$v" ] && { echo "[+] ZAP ready: $v"; return 0; }
    sleep 1
  done
  echo "ERROR: ZAP not ready" >&2
  exit 1
}

wait_for_ascan(){
  local id=$1
  while true; do
    s=$(curl -s "${ZAP_BASE}/JSON/ascan/view/status/?apikey=${API_KEY}&scanId=${id}" | jq -r .status)
    echo "ascan status: ${s}%"
    [ "$s" = "100" ] && break
    sleep 8
  done
}

# start
wait_for_zap

# create context and include host (id may still be 1)
curl -s "${ZAP_BASE}/JSON/context/action/newContext/?apikey=${API_KEY}&contextName=$(urlenc "${CONTEXT_NAME}")" >/dev/null
INCLUDE_REGEX="^https?://$(echo "${TARGET_HOST}" | sed 's/\./\\./g')(:[0-9]+)?/.*"
curl -s "${ZAP_BASE}/JSON/context/action/includeInContext/?apikey=${API_KEY}&contextName=$(urlenc "${CONTEXT_NAME}")&regex=$(urlenc "${INCLUDE_REGEX}")" >/dev/null

# configure basic auth (pragmatic default contextId=1)
AUTH_CFG="hostname=${TARGET_HOST}&realm=&port=443"
curl -s "${ZAP_BASE}/JSON/authentication/action/setAuthenticationMethod/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&authMethodName=basicAuthentication&authMethodConfig=$(urlenc "${AUTH_CFG}")" >/dev/null

# create user and set creds
NEWUSER_JSON=$(curl -s "${ZAP_BASE}/JSON/users/action/newUser/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&name=$(urlenc "mongo-user")")
USER_ID=$(echo "$NEWUSER_JSON" | jq -r .userId 2>/dev/null || echo "0")
[ -z "$USER_ID" ] && USER_ID=0
CREDS="username=${MONGO_USER}&password=${MONGO_PASS}"
curl -s "${ZAP_BASE}/JSON/users/action/setAuthenticationCredentials/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&userId=${USER_ID}&authCredentials=$(urlenc "${CREDS}")" >/dev/null
curl -s "${ZAP_BASE}/JSON/users/action/setUserEnabled/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&userId=${USER_ID}&enabled=true" >/dev/null

# enable forced-user mode so scans use that user session
curl -s "${ZAP_BASE}/JSON/forcedUser/action/setForcedUser/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&userId=${USER_ID}" >/dev/null
curl -s "${ZAP_BASE}/JSON/forcedUser/action/setForcedUserModeEnabled/?apikey=${API_KEY}&boolean=true" >/dev/null

# active-scan each seed path
for p in "${SEED_PATHS[@]}"; do
  FULL="${TARGET_BASE%/}${p}"
  echo "[*] Active scanning $FULL"
  R=$(curl -s "${ZAP_BASE}/JSON/ascan/action/scan/?apikey=${API_KEY}&url=$(urlenc "${FULL}")&contextId=${CONTEXT_ID}&recurse=true&inScopeOnly=false")
  SCAN_ID=$(echo "$R" | jq -r .scan 2>/dev/null || true)
  if [ -n "$SCAN_ID" ] && [ "$SCAN_ID" != "null" ]; then
    wait_for_ascan "$SCAN_ID"
  else
    echo "Warning: could not start ascan for $FULL"
  fi
done

# export evidence
curl -s "${ZAP_BASE}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o "${REPORT_DIR}/zap-report-combined.html"
curl -s "${ZAP_BASE}/JSON/core/view/alerts/?apikey=${API_KEY}" -o "${REPORT_DIR}/zap-alerts.json"
echo "[+] Reports -> ${REPORT_DIR}"

# optional SCA (if tools exist)
if [ -f package.json ] && command -v npm >/dev/null 2>&1; then
  npm audit --json > "${REPORT_DIR}/npm-audit.json" || true
fi
if command -v trivy >/dev/null 2>&1; then
  trivy fs --format json -o "${REPORT_DIR}/trivy-fs.json" . || true
fi

echo "Done."
