# Run ZAP image on the same network
docker rm -f zap
docker run -u zap --name zap -p 8080:8080 \
  --network compose_frontend \
  -d ghcr.io/zaproxy/zaproxy:stable \
  zap.sh -daemon -port 8080 -host 0.0.0.0 \
  -config api.key=MySecretKey123 \
  -config api.addrs.addr.name=.* \
  -config api.addrs.addr.regex=true
