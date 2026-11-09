# ASW1 end-user ports: 802.1X and layered L2 defences

ASW1 g1/0/1-20 (Staff, ATM, HR, IT hosts) are rendered by `EndUserPortStanza`
in `network-configs/partials/common.esh.part`; the global part by
`EndUserL2SecurityGlobal`. Uplinks g1/0/23-24 are trusted (`TrustedUplinkStanza`).

## 802.1X port commands

| Command | What it does |
| --- | --- |
| `authentication port-control auto` | **Turns enforcement on.** The port starts *unauthorized* and only passes 802.1X (EAPOL) frames; it opens once FreeRADIUS sends Access-Accept. Without it the other lines do nothing. (Other values: `force-authorized` = always open, the default; `force-unauthorized` = always shut.) |
| `authentication host-mode single-host` | **One authenticated device per port.** A second MAC (hub/switch behind the PC) is a violation. (`multi-host` lets everyone in behind the first device; `multi-auth` authenticates each device; `multi-domain` = one PC + one IP phone.) |
| `authentication violation restrict` | **On violation:** drop and log the extra device's frames, keep the port up for the legitimate PC. (Default `shutdown` err-disables the whole port.) |
| `dot1x pae authenticator` | **Switch role.** The switch is the authenticator: it asks the host (supplicant) for credentials and relays them to FreeRADIUS (authentication server). |
| `dot1x timeout tx-period 10` | **Identity request interval:** ask "who are you?" (EAP-Request/Identity) every 10 s instead of 30 s, so hosts authenticate faster. |
| `dot1x timeout held-period 60` | **Quiet period after a failure:** ignore the host for 60 s (`Restart timeout: 60s` in `show access-session`). Slows down EAP floods and repeated attempts. |
| `dot1x max-req 2` | **Retries:** re-send a request at most 2 times before giving up on that attempt. |

`held-period 60` and `max-req 2` are the IOS-XE defaults, so `show run` hides them;
the template writes them out so the anti-flood behaviour is visible.

### What happens when a host plugs in

1. Port is shut (`port-control auto`).
2. The switch (`pae authenticator`) asks for the host's identity every 10 s (`tx-period`), up to 2 times (`max-req`).
3. The host answers with its certificate; the switch relays the EAP-TLS exchange to FreeRADIUS (`RADGRP`, via Mgmt-vrf).
4. **Accept:** port opens in the VLAN FreeRADIUS returns (`Tunnel-Private-Group-Id`); only that MAC is allowed (`single-host`), extra MACs are dropped (`violation restrict`).
5. **Reject / no answer:** port stays shut; 60 s quiet period (`held-period`), then it tries again.

## How 802.1X fits with the other defences

802.1X is the first gate. Until a port is **Authorized**, only EAPOL frames pass, so
there is no DHCP, ARP or IP traffic for the other features to act on. After a host
is authorized, every other defence still applies to it. That covers an attacker
holding a valid certificate (stolen laptop, misused `.p12`) and a legitimate user
misbehaving.

| Layer | Port / global config | Stops |
| --- | --- | --- |
| 802.1X (EAP-TLS) | `authentication ...`, `dot1x ...` | Devices without a valid, allow-listed certificate |
| Port-security | `switchport port-security ...` (max 3, restrict) | MAC flooding / many MACs on one port |
| DHCP snooping | `ip dhcp snooping vlan 10,20,30,40`, `limit rate 15`; uplinks `trust` | Rogue DHCP servers, DHCP starvation; builds the IP-MAC binding table |
| Dynamic ARP Inspection | `ip arp inspection vlan 10,20,30,40`; uplinks `trust` | ARP spoofing / man-in-the-middle |
| BPDU guard + portfast | `spanning-tree bpduguard enable` | Rogue switches |
| errdisable recovery | `errdisable recovery cause ...` | Ports staying down forever after a violation |

They don't conflict (tested live on g1/0/13: Authorized with port-security, BPDU
guard and DHCP snooping on). Points to keep in mind:

- **single-host vs port-security max 3:** both limit MACs; `single-host` (1
  authenticated MAC) is the stricter one. Both use `restrict`, so a violation drops
  frames instead of shutting the port.
- **Static IP hosts and DAI:** DAI (and IP Source Guard, if enabled later) only
  trust addresses in the DHCP snooping binding table. A host with a static IP has
  no binding, so its ARP is dropped even after 802.1X lets it in. Add one per host:
  `ip source binding <mac> vlan <id> <ip> interface GigabitEthernet1/0/<port>`.
- **Dynamic VLANs:** FreeRADIUS can place a host in any of VLAN 10/20/30/40 on any
  port, so DHCP snooping and DAI cover all four VLANs (`EndUserL2SecurityGlobal`).
- **Same-MAC piggybacking:** 802.1X authorizes a MAC address. A device behind the
  authorized PC that spoofs the *same* MAC isn't caught by `single-host`; that
  needs MACsec (link encryption), not used here.

## Verify

```
show access-session interface GigabitEthernet1/0/<port> details   ! Authorized, Vlan Policy, dot1x Authc Success
show dot1x interface GigabitEthernet1/0/<port>
show port-security interface GigabitEthernet1/0/<port>
show ip dhcp snooping binding
show ip arp inspection statistics
clear access-session interface GigabitEthernet1/0/<port>          ! restart authentication
```
