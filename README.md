# configs

## Prerequisites


- Install [`esh`](https://github.com/jirutka/esh)
- Have a POSIX-compliant shell (e.g. Bash)


## Quickstart

To render the template, simply run:

```
./render.sh
```

The rendered files are under `network-configs/**/*`, without `.esh`. For
example, `network-configs/csw1.esh` will be rendered as
`network-configs/csw1`.


## Updating variables

Update the variables' values via the companion Microsoft Excel workbook, and
then copy-and-paste cell `TemplateVarSubstitutions!B3` into
[`partials/vars.sh`](./partials-vars.sh).


## More documentation

### AAA tacacs+ config (`docs/aaa/`)

Original documentation and docs pre-templatisation, courtesy of
[@gongctf](https://github.com/gongctf).

- tac_plus-ng.cfg
    - config for tacacs+ service
- tacacs VM config commands (VM-commands.txt)
    - commands to setup the VM
- R2-temp-config-oct30
    - just the temporary config for testing at R2
