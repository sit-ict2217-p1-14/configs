#!/bin/bash
# Issue an 802.1X (EAP-TLS) client certificate signed by our CA.
# Replaces gen-certs.sh.
#
# Usage:
#   ./mkhost.sh <name> <vlan-id>   END-USER HOST on ASW1, e.g. ./mkhost.sh hr-pc01 30
#                                  -> hosts/<name>/ + VLAN entry in users-add.txt
#                                  VLANs: Staff 10, ATM 20, HR 30, IT 40
#   ./mkhost.sh <name>             NETWORK DEVICE, e.g. ./mkhost.sh msw
#                                  -> <name>/ (no VLAN entry)
#
#   CA key passphrase: prompted, or set PKI_CA_KEY_PASSPHRASE
#   p12 export password: prompted, or set P12PASS
# Output: <dir>/<name>.{key,csr,ext,pem,p12}   (the .p12 goes to the host/device)
set -euo pipefail
cd "$(dirname "$0")"

n="${1:-}"; v="${2:-}"
[ -n "$n" ] || { echo "usage: $0 <name> [vlan-id]"; exit 1; }
case "$n" in *[!a-z0-9-]*) echo "name: lowercase letters, digits and '-' only"; exit 1;; esac
cn="$n.net.internal.punggolbanksbbl.sitict.net"
if [ -n "$v" ]; then dir="hosts/$n"; else dir="$n"; fi

passArgs=()
[ -n "${PKI_CA_KEY_PASSPHRASE:-}" ] && passArgs=(-passin env:PKI_CA_KEY_PASSPHRASE)
[ -n "${P12PASS:-}" ] || { read -rs -p "p12 export password: " P12PASS; echo; }
export P12PASS

mkdir -p "$dir"

# 1. private key (stays with the host/device, inside the .p12)
openssl genrsa -out "$dir/$n.key" 2048
# 2. certificate signing request with the name (CN)
openssl req -new -key "$dir/$n.key" -subj "/CN=$cn" -out "$dir/$n.csr"
# 3. certificate rules: not a CA, client authentication only
printf 'basicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=clientAuth\nsubjectAltName=DNS:%s\n' "$cn" > "$dir/$n.ext"
# 4. sign with the CA (asks for the CA key passphrase)
openssl x509 -req -in "$dir/$n.csr" -CA ca/ca.pem -CAkey ca/ca.key "${passArgs[@]}" \
  -CAcreateserial -days 825 -sha256 -extfile "$dir/$n.ext" -out "$dir/$n.pem"
# 5. bundle key + cert + CA into a password-protected .p12
openssl pkcs12 -export -inkey "$dir/$n.key" -in "$dir/$n.pem" -certfile ca/ca.pem \
  -name "$cn" -out "$dir/$n.p12" -passout env:P12PASS
# 6. hosts only: FreeRADIUS users entry, CN -> VLAN (added once)
if [ -n "$v" ] && ! grep -qxF "$cn" users-add.txt 2>/dev/null; then
  printf '%s\n\tTunnel-Type = VLAN,\n\tTunnel-Medium-Type = IEEE-802,\n\tTunnel-Private-Group-Id = "%s"\n\n' "$cn" "$v" >> users-add.txt
fi

echo "OK: $dir/$n.p12  (CN=$cn${v:+, VLAN $v})"
