#!/usr/bin/env bash
set -euo pipefail

# ====== Config ======
API_KEY="MySecretKey123"
ZAP_BASE="http://localhost:8080"
TARGET_HOST="compose-nginx-1"                # container service name (internal Docker DNS)
TARGET_BASE="https://${TARGET_HOST}"
CONTEXT_NAME="AssignmentContext"
MONGO_USER="admin"
MONGO_PASS="pass"
REPORT_DIR="./zap-evidence"
mkdir -p "$REPORT_DIR"

# High-value seed paths to actively test (add or remove as needed)
SEED_PATHS=(
  "/" 
  "/signin"
  "/signup"
  "/api"               # REST API base
  "/admin"             # admin UI
  "/upload"            # upload endpoints
  "/opc/v1/instance"   # cloud metadata path discovered earlier
  "/mongo-express/"
)

# ====== Helpers ======
echo_stamp(){ printf "\n==> %s\n" "$1"; }

wait_for_zap(){
  echo_stamp "Waiting for ZAP API to respond..."
  for i in {1..60}; do
    v=$(curl -s "${ZAP_BASE}/JSON/core/view/version/?apikey=${API_KEY}" | jq -r .version 2>/dev/null || true)
    if [ -n "$v" ] && [ "$v" != "null" ]; then
      echo "[+] ZAP ready: $v"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: ZAP did not become ready in time." >&2
  exit 1
}

# Poll active scan (id) until done
wait_for_ascan(){
  local scanid=$1
  echo_stamp "Waiting for active scan $scanid"
  while true; do
    status=$(curl -s "${ZAP_BASE}/JSON/ascan/view/status/?apikey=${API_KEY}&scanId=${scanid}" | jq -r .status)
    echo "  ascan status: ${status}%"
    [ "$status" = "100" ] && break
    sleep 8
  done
}

# Poll forced-browse (if used)
wait_for_forcedbrowse(){
  local scanid=$1
  echo_stamp "Waiting for forced-browse $scanid"
  while true; do
    status=$(curl -s "${ZAP_BASE}/JSON/forcedBrowse/view/status/?apikey=${API_KEY}&scanId=${scanid}" | jq -r .status 2>/dev/null || true)
    # some versions return numeric percentage; if missing, break after a delay
    echo "  forced-browse status: ${status:-unknown}"
    if [ "$status" = "100" ]; then break; fi
    sleep 5
  done
}

# URL-escape helper
urlenc(){ python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$1"; }

# ====== Start ======
wait_for_zap

# 1) Create context and include target host
echo_stamp "Creating context '${CONTEXT_NAME}' and including host"
curl -s "${ZAP_BASE}/JSON/context/action/newContext/?apikey=${API_KEY}&contextName=$(urlenc "${CONTEXT_NAME}")" >/dev/null
INCLUDE_REGEX="^https?://$(echo "${TARGET_HOST}" | sed 's/\./\\./g')(:[0-9]+)?/.*"
curl -s "${ZAP_BASE}/JSON/context/action/includeInContext/?apikey=${API_KEY}&contextName=$(urlenc "${CONTEXT_NAME}")&regex=$(urlenc "${INCLUDE_REGEX}")" >/dev/null

# 2) Configure basic authentication for mongo-express (contextId assumed to be 1 in many setups)
#    If your ZAP uses different contextId mapping, you may need to adjust. This is a pragmatic default.
CONTEXT_ID=1
AUTH_CFG="hostname=${TARGET_HOST}&realm=&port=443"
curl -s "${ZAP_BASE}/JSON/authentication/action/setAuthenticationMethod/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&authMethodName=basicAuthentication&authMethodConfig=$(urlenc "${AUTH_CFG}")" >/dev/null

# 3) Create a user for the context and set credentials
echo_stamp "Creating user for mongo-express authentication"
NEWUSER_JSON=$(curl -s "${ZAP_BASE}/JSON/users/action/newUser/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&name=$(urlenc "mongo-user")")
USER_ID=$(echo "$NEWUSER_JSON" | jq -r .userId)
if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
  echo "Could not create/get userId from ZAP. Using userId=0 as fallback."
  USER_ID=0
fi
CREDS="username=${MONGO_USER}&password=${MONGO_PASS}"
curl -s "${ZAP_BASE}/JSON/users/action/setAuthenticationCredentials/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&userId=${USER_ID}&authCredentials=$(urlenc "${CREDS}")" >/dev/null
curl -s "${ZAP_BASE}/JSON/users/action/setUserEnabled/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&userId=${USER_ID}&enabled=true" >/dev/null

# 4) Enable forced user mode so scans use that user session (helps hit protected admin)
curl -s "${ZAP_BASE}/JSON/forcedUser/action/setForcedUser/?apikey=${API_KEY}&contextId=${CONTEXT_ID}&userId=${USER_ID}" >/dev/null
curl -s "${ZAP_BASE}/JSON/forcedUser/action/setForcedUserModeEnabled/?apikey=${API_KEY}&boolean=true" >/dev/null

# 5) Forced-browse to discover hidden files/dirs
echo_stamp "Starting forced-browse (directory bruteforce) on ${TARGET_BASE}/"
FB_SCAN_JSON=$(curl -s "${ZAP_BASE}/JSON/forcedBrowse/action/scan/?apikey=${API_KEY}&url=${TARGET_BASE}/&recursive=true")
FB_SCAN_ID=$(echo "$FB_SCAN_JSON" | jq -r .scan 2>/dev/null || true)
if [ -n "$FB_SCAN_ID" ]; then
  wait_for_forcedbrowse "$FB_SCAN_ID"
fi

# 6) Active-scan each seed path (authenticated context if applicable)
echo_stamp "Starting active scans for seed paths"
for PATH in "${SEED_PATHS[@]}"; do
  FULL_URL="${TARGET_BASE%/}${PATH}"
  echo "[*] Active scan: $FULL_URL"
  R=$(curl -s "${ZAP_BASE}/JSON/ascan/action/scan/?apikey=${API_KEY}&url=$(urlenc "${FULL_URL}")&contextId=${CONTEXT_ID}&recurse=true&inScopeOnly=false")
  SCAN_ID=$(echo "$R" | jq -r .scan)
  if [ -n "$SCAN_ID" ] && [ "$SCAN_ID" != "null" ]; then
    wait_for_ascan "$SCAN_ID"
  else
    echo "  Warning: could not start active scan for $FULL_URL"
  fi
done

# 7) Save HTML reports and alerts JSON for evidence
echo_stamp "Exporting reports and alerts"
curl -s "${ZAP_BASE}/OTHER/core/other/htmlreport/?apikey=${API_KEY}" -o "${REPORT_DIR}/zap-report-combined.html"
curl -s "${ZAP_BASE}/JSON/core/view/alerts/?apikey=${API_KEY}" -o "${REPORT_DIR}/zap-alerts.json"
echo "[+] Reports saved to ${REPORT_DIR}"

# 8) Run SCA and container checks if tools exist (npm audit and trivy)
echo_stamp "Running npm audit (if package.json exists)"
if [ -f package.json ]; then
  if command -v npm >/dev/null 2>&1; then
    npm audit --json > "${REPORT_DIR}/npm-audit.json" || true
    echo "[+] npm audit written to ${REPORT_DIR}/npm-audit.json"
  else
    echo "npm not found, skipping npm audit"
  fi
else
  echo "package.json not present, skipping npm audit"
fi

echo_stamp "Running trivy (if installed)"
if command -v trivy >/dev/null 2>&1; then
  trivy fs --format json -o "${REPORT_DIR}/trivy-fs.json" . || true
  # optionally scan docker image if you have one: trivy image <image>
  echo "[+] trivy filesystem scan saved to ${REPORT_DIR}/trivy-fs.json"
else
  echo "trivy not installed, skipping trivy scans"
fi

echo_stamp "Done. Evidence directory: ${REPORT_DIR}"
