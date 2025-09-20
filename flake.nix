{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      systems = builtins.attrNames inputs.nixpkgs.legacyPackages;
      forAllSystems = f: lib.genAttrs systems (system: f system inputs.nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        system: pkgs: {
          default = inputs.self.packages.${system}.zulip-server;
          zulip-server = pkgs.callPackage ./package.nix { };
          zulip-static-content = inputs.self.packages.${system}.zulip-server.passthru.static-content;
          vm = inputs.self.nixosConfigurations.vm.config.system.build.toplevel;
        }
      );

      overlays.default = final: prev: {
        inherit (inputs.self.packages.${final.system}) zulip-server;
      };

      nixosModules.default = ./module.nix;

      nixosConfigurations.vm = inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        pkgs = import inputs.nixpkgs {
          system = "x86_64-linux";
          overlays = [
            inputs.self.overlays.default
          ];
        };

        modules = [
          "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          inputs.self.nixosModules.default
          (
            { modulesPath, ... }:
            {
              virtualisation.graphics = false;
              virtualisation.qemu.options = [
                "-netdev user,id=n0,hostfwd=tcp::8080-:443"
              ];
              users.extraUsers.root.password = "root";
              services.getty.autologinUser = "root";
              services.zulip = {
                enable = true;
                settings = {
                  EXTERNAL_HOST = "example.com";
                  ZULIP_ADMINISTRATOR = "admin@example.com";
                  ZULIP_SERVICE_PUSH_NOTIFICATIONS = true;
                };
              };
            }
          )
        ];
      };

      apps = forAllSystems (
        system: pkgs: {
          default = {
            type = "app";
            program = "${inputs.self.nixosConfigurations.vm.config.system.build.vm}/bin/run-nixos-vm";
          };
        }
      );

      checks = forAllSystems (
        system: pkgs: {
          default = (pkgs.extend inputs.self.overlays.default).nixosTest (import ./test.nix);
        }
      );
    };
}
