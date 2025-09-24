#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
EC2_IP="3.227.150.252"     # replace with your actual EC2 public IP if different
OUTPUT_DIR="./evidence"
MONGO_USER="admin"
MONGO_PASS="pass"
mkdir -p "$OUTPUT_DIR"

# --- Helpers ---
grab () {
  local url=$1
  local base=$(echo "$url" | sed 's#https\?://##; s#[^a-zA-Z0-9]#_#g')
  echo "[*] Fetching $url"
  curl -k -s -D "${OUTPUT_DIR}/${base}-headers.txt" "$url" \
       -o "${OUTPUT_DIR}/${base}-body.html" || true
}

# --- 1. Basic app pages ---
grab "https://${EC2_IP}/"
grab "https://${EC2_IP}/signin"
grab "https://${EC2_IP}/signup"

# --- 2. Mongo Express (auth required) ---
curl -k -s -u "${MONGO_USER}:${MONGO_PASS}" \
     -D "${OUTPUT_DIR}/mongo-express-headers.txt" \
     "https://${EC2_IP}/mongo-express/" \
     -o "${OUTPUT_DIR}/mongo-express-body.html"

# --- 3. Cloud metadata endpoint (if reachable through nginx) ---
grab "https://${EC2_IP}/opc/v1/instance"

# --- 4. Example API probes ---
# adjust paths if your app exposes APIs
grab "https://${EC2_IP}/api"
grab "https://${EC2_IP}/api/users/1"
grab "https://${EC2_IP}/api/users/2"

# --- 5. File upload test (if endpoint exists) ---
TMPFILE=$(mktemp /tmp/testfile.XXXX.txt)
echo "manual-test-$(date +%s)" > "$TMPFILE"
curl -k -s -X POST -F "file=@${TMPFILE}" \
     -D "${OUTPUT_DIR}/upload-headers.txt" \
     "https://${EC2_IP}/upload" \
     -o "${OUTPUT_DIR}/upload-body.txt" || true
rm -f "$TMPFILE"

echo "[+] Manual evidence saved in ${OUTPUT_DIR}"
