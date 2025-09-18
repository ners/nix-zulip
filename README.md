# nix-zulip

We're packaging [zulip](https://github.com/zulip/zulip/) for NixOS. The repository includes a package + deps, a NixOS module and an integration test.

## Development

```console
# build the package
nix build

# run an interactive VM
nix run

# Build the test
nix build .#checks.<triplet>.default
```
