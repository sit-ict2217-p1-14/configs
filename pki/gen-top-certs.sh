mkdir ca radius

# === ROOT CA ===
openssl req -x509 -new -key ca/ca.key -sha256 -days 3650 -subj "/CN=PunggolBankSBBL-CA" -out ca/ca.pem



# === RADIUS ===
openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/CN=radius.internal.punggolbanksbbl.sitict.net" -out server.csr

cat > server.ext <<'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:radius.internal.punggolbanksbbl.sitict.net
EOF

openssl x509 -req -in server.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 825 -sha256 -extfile server.ext -out server.pem
