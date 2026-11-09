# Windows host: 802.1X (EAP-TLS) on ASW1

Sets up a Windows 10/11 laptop to authenticate on an ASW1 end-user port with its
host certificate. You need the host's `.p12` from [mkhost.md](./mkhost.md) and its
p12 password. What the switch port does is explained in
[asw1-8021x-ports.md](./asw1-8021x-ports.md).

## 1. Import the host certificate (.p12)

1. Double-click `<host>.p12` → **Current User** → Next.
2. Enter the **p12 password** → Next.
3. **Place all certificates in the following store** → **Personal** → Finish.

## 2. Trust the CA (computer store)

The `.p12` also contains the CA certificate (`PunggolBankSBBL-CA`); Windows' 802.1X
service needs it in the **computer's** Trusted Root store.

1. Win+R → `certmgr.msc` → **Personal → Certificates** → right-click
   **PunggolBankSBBL-CA** → All Tasks → **Export** → **Base-64 encoded X.509 (.CER)**
   → save as `ca.cer`.
   (Or copy `~/freeradius-pki/ca/ca.pem` from the AAA VM and rename to `ca.cer`.)
2. Win+R → `certlm.msc` (admin) → **Trusted Root Certification Authorities →
   Certificates** → right-click → All Tasks → **Import** → `ca.cer` → Finish.

## 3. Check the certificates

In a normal Command Prompt / PowerShell:

```
certutil -verifystore Root PunggolBankSBBL-CA
certutil -user -verifystore My
```

- The CA is found and "Certificate is valid".
- The host certificate shows a `Key Container`, `Encryption test passed`, and
  **no "Expired certificate"** line (Windows also uses that wording for
  *not yet valid* — see Troubleshooting).

## 4. Start the wired 802.1X service

Win+R → `services.msc` → **Wired AutoConfig** → Startup type **Automatic** → **Start**.

## 5. Ethernet adapter settings

Control Panel → Network Connections → right-click **Ethernet** → Properties →
**Authentication** tab:

1. Tick **Enable IEEE 802.1X authentication**.
2. Network authentication method: **Microsoft: Smart Card or other certificate** →
   **Settings**:
   - **Use a certificate on this computer** (not "Use my smart card")
   - **Untick** "Use simple certificate selection"
   - Tick **Verify the server's identity by validating the certificate**
   - Under Trusted Root Certification Authorities, tick **PunggolBankSBBL-CA**
   - OK
3. Tick **Remember my credentials for this connection each time I'm logged on**.
4. **Additional settings** → tick **Specify authentication mode** → **User authentication** → OK.
5. OK to close.

## 6. Connect

Plug into the ASW1 port. Windows authenticates automatically with the certificate.
To restart authentication from the switch side:

```
clear access-session interface GigabitEthernet1/0/<port>
```

## 7. Verify

On ASW1:

```
show access-session interface GigabitEthernet1/0/<port> details
```

Expect `User-Name: <host>.net.internal.punggolbanksbbl.sitict.net`,
`Status: Authorized`, `Server Policies → Vlan Group: Vlan: <id>`,
`dot1x Authc Success`.

On the AAA VM: `sudo tail /var/log/freeradius/radius.log` → `Login OK`.

Set the host's IP for its VLAN (see the VLAN plan). With DHCP snooping/DAI on ASW1,
a static-IP host also needs a binding on ASW1, e.g.
`ip source binding <mac> vlan <id> <ip> interface GigabitEthernet1/0/<port>`.

## Troubleshooting

Event Viewer → Applications and Services Logs → Microsoft → Windows →
**Wired-AutoConfig → Operational**, or `netsh lan show interfaces` (admin).

| Symptom | Cause | Fix |
| --- | --- | --- |
| `0x80420014` "user certificate ... can't be found"; nothing in `freeradius -X` | No usable certificate: missing private key, wrong store, "Use my smart card" selected, or certificate **not yet valid** | Steps 1, 3 and 5. If `certutil` shows "Expired certificate" but the dates look current, the AAA VM clock was ahead — fix it and re-issue ([mkhost.md](./mkhost.md#re-issuing-eg-clock-was-wrong-not-yet-valid)) |
| `0x50005` / `0x40420110` during TLS | Handshake refused by either side | Run `sudo freeradius -X` and look for `tls:` / `TLS Alert` / `ERROR` lines |
| `freeradius -X` shows `[files] = noop` then `reject` in `check-eap-tls` | Host not in the users file (allow-list) | [mkhost.md](./mkhost.md) step 2: load `users-add.txt` and restart FreeRADIUS |
| `Certificate CN (...) does not match specified value (...)` in `freeradius -X` | Identity sent ≠ certificate CN | Check `User-Name` in the log; the host name must match the certificate |
| ASW1 shows `dot1x Stopped`, `Restart timeout: 60s` | Host didn't answer; port in quiet period | `clear access-session interface ...` and retry |
| Windows says the p12 password is wrong | OpenSSL 3 .p12 format on older Windows | Re-export the `.p12` on the VM with `-legacy` added |
