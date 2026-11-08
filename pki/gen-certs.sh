#!/bin/sh

set -eu
set -o pipefail

deviceName="$1"


gen_radius_


mkdir "$deviceName"

openssl genrsa -out "$deviceName"/"$deviceName".key 2048

openssl req -new -key "$deviceName"/"$deviceName".key -subj '/CN='"$deviceName"'.net.internal.punggolbanksbbl.sitict.net' -out "$deviceName"/"$deviceName".csr

cat >"$deviceName"/"$deviceName".ext <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=clientAuth
subjectAltName=DNS:"$deviceName".net.internal.punggolbanksbbl.sitict.net
EOF

openssl x509 -req -in "$deviceName"/"$deviceName".csr -CA ca/ca.pem -CAkey ca/ca.key -CAcreateserial -days 825 -sha256 -extfile "$deviceName"/"$deviceName".ext -out "$deviceName"/"$deviceName".pem -passin env:PKI_CA_KEY_PASSPHRASE

openssl pkcs12 -export -inkey "$deviceName"/"$deviceName".key -in "$deviceName"/"$deviceName".pem -certfile ca/ca.pem -name "$deviceName".net.internal.punggolbanksbbl.sitict.net -out "$deviceName"/"$deviceName".p12 -passout pass:'rzVt6C7EzguZpDbTlKUmzKyFEF4pSGwi'
