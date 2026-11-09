# configs

## Prerequisites


- Install [`esh`](https://github.com/jirutka/esh) v0.2.0 (newer versions break on `\n` in `partials/vars.sh`)
- Have a POSIX-compliant shell (e.g. Bash)


## Quickstart

To render the template, simply run:

```
./render.sh
```
or
```
bash render.sh
```

The rendered files are under `network-configs/**/*` and `servers/**/*`, without
`.esh`. For example, `network-configs/csw1.esh` will be rendered as
`network-configs/csw1`, and `servers/aaa-server/clients.conf.esh` as
`servers/aaa-server/clients.conf`. Rendered files are git-ignored.


## Updating variables

Update the variables' values via the companion Microsoft Excel workbook, and
then copy-and-paste cell `TemplateVarSubstitutions!B3` into
[`partials/vars.sh`](./partials/vars.sh).


## More documentation

### AAA VM (`docs/aaa/`)

Original documentation and docs pre-templatisation, courtesy of
[@gongctf](https://github.com/gongctf).

- [VM-commands.txt](./docs/aaa/VM-commands.txt)
    - commands to setup the VM: tac_plus-ng (TACACS+) and FreeRADIUS (802.1X EAP-TLS, from a bare VM)

#### TACACS+ (`docs/aaa/tacacsplusng/`)

- tac_plus-ng.cfg
    - config for tacacs+ service

- R2-temp-config-oct30
    - just the temporary config for testing at R2

#### FreeRADIUS / 802.1X (`docs/aaa/freeradius/`)

- [asw1-8021x-ports.md](./docs/aaa/freeradius/asw1-8021x-ports.md)
    - what the ASW1 end-user port commands do, and how 802.1X layers with the other L2 defences
- [mkhost.md](./docs/aaa/freeradius/mkhost.md)
    - issuing / removing host and device certificates with `pki/mkhost.sh`
- [windows-8021x-client.md](./docs/aaa/freeradius/windows-8021x-client.md)
    - importing the host and CA certificates on Windows, Ethernet 802.1X settings, troubleshooting
- users-add.txt
    - hosts allowed on ASW1 802.1X ports and their VLANs (copy of the AAA VM's list)
- RADIUS clients: [`servers/aaa-server/clients.conf.esh`](./servers/aaa-server/clients.conf.esh)
