# Issuing a host certificate with `mkhost.sh`

`pki/mkhost.sh` creates an 802.1X (EAP-TLS) client certificate signed by our CA
(it replaces the old `gen-certs.sh`):

| Command | For | Output |
| --- | --- | --- |
| `./mkhost.sh <host> <vlan-id>` | **End-user host** on ASW1 | `hosts/<host>/` + VLAN entry in `users-add.txt` |
| `./mkhost.sh <device>` | **Network device** (e.g. `msw`, `dssw`) | `<device>/` (no VLAN entry) |

Run it **on the AAA VM**, in `~/freeradius-pki/` (set up per the FreeRADIUS
section of [VM-commands.txt](../VM-commands.txt)).

| VLAN | ID | Example host name |
| --- | --- | --- |
| Staff | 10 | `staff-pc01` |
| ATM | 20 | `atm-pc01` |
| HR | 30 | `hr-pc01` |
| IT | 40 | `it-pc01` |

Names: lowercase letters, digits and `-` only. The certificate name (CN) becomes
`<host>.net.internal.punggolbanksbbl.sitict.net`.

## 1. Issue the certificate

```bash
cd ~/freeradius-pki
export P12PASS='<p12 export password>'     # protects the .p12 file in transit
./mkhost.sh hr-pc01 30                     # asks for the PKI_CA_KEY passphrase
```

To avoid the passphrase prompt for several hosts:
`read -rs -p "CA passphrase: " PKI_CA_KEY_PASSPHRASE; export PKI_CA_KEY_PASSPHRASE`
(then `unset PKI_CA_KEY_PASSPHRASE P12PASS` when done).

Output:

| File | Use |
| --- | --- |
| `hosts/hr-pc01/hr-pc01.p12` | **Copy to the host** (key + certificate + CA) |
| `hosts/hr-pc01/hr-pc01.key` | Host private key — never leaves the VM except inside the .p12 |
| `hosts/hr-pc01/hr-pc01.pem` | Host certificate |
| `users-add.txt` | One VLAN entry per host (appended once). FreeRADIUS only accepts hosts listed here |

Check the dates — `notBefore` must be in the past for the host:

```bash
openssl x509 -in hosts/hr-pc01/hr-pc01.pem -noout -subject -dates
```

For a network device: `./mkhost.sh msw` → `msw/msw.p12`. Skip step 2 (devices get
no VLAN entry; none of them use 802.1X yet).

## 2. Load the host list into FreeRADIUS

`mkhost.sh` only edits `~/freeradius-pki/users-add.txt`. FreeRADIUS reads its own
users file, so copy the list in (at the top) and restart:

```bash
sudo sh -c "cat $HOME/freeradius-pki/users-add.txt /etc/freeradius/3.0/mods-config/files/authorize.orig > /etc/freeradius/3.0/mods-config/files/authorize"
sudo freeradius -CX | tail -1              # "Configuration appears to be OK"
sudo systemctl restart freeradius
```

## 3. Copy the `.p12` to the host

Via the jump host / scp, or a USB stick. Give the p12 password to whoever imports it.
Then follow [windows-8021x-client.md](./windows-8021x-client.md).

## 4. Record it in the repo

Copy the VM's `~/freeradius-pki/users-add.txt` content into `docs/aaa/freeradius/users-add.txt`
and commit. Keys, `.p12` files and `hosts/` stay on the VM.

## Re-issuing (e.g. clock was wrong, "not yet valid")

Re-sign with the existing key, then re-import the new `.p12` on the host:

```bash
cd ~/freeradius-pki/hosts/hr-pc01
openssl x509 -req -in hr-pc01.csr -CA ../../ca/ca.pem -CAkey ../../ca/ca.key -CAcreateserial \
  -days 825 -sha256 -extfile hr-pc01.ext -out hr-pc01.pem
openssl pkcs12 -export -inkey hr-pc01.key -in hr-pc01.pem -certfile ../../ca/ca.pem \
  -name hr-pc01.net.internal.punggolbanksbbl.sitict.net -out hr-pc01.p12
```

## Removing a host

FreeRADIUS only accepts certificates whose name is in the users file (allow-list in
`check-eap-tls`), so removing the entry blocks the host even though its certificate
is still valid.

```bash
cd ~/freeradius-pki
rm -rf hosts/<host>                 # device: rm -rf <device>
cp users-add.txt users-add.txt.bak
awk -v cn="<host>.net.internal.punggolbanksbbl.sitict.net" 'BEGIN{RS=""; ORS="\n\n"} $1 != cn' users-add.txt.bak > users-add.txt
grep -c "^<host>\." users-add.txt   # 0
```

Then step 2 (reload the list, restart) and step 4 (update the repo copy).
On the host, delete the certificate (`certmgr.msc` → Personal).

## How the script works

1. `openssl genrsa` — host private key (2048-bit RSA).
2. `openssl req` — signing request carrying the host's name (CN).
3. `.ext` file — `CA:FALSE`, `extendedKeyUsage=clientAuth`, SAN = CN.
4. `openssl x509 -req ... -CAkey ca/ca.key` — CA signs it (needs the CA passphrase), valid 825 days.
5. `openssl pkcs12 -export` — key + cert + CA in one password-protected `.p12`.
6. Hosts only: appends `Tunnel-Type`/`Tunnel-Medium-Type`/`Tunnel-Private-Group-Id` (the VLAN) to `users-add.txt`, once per host.
