{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = builtins.attrNames nixpkgs.legacyPackages;
      forAllSystems = f: lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        system: pkgs: {
          default = self.packages.${system}.zulip-server;
          zulip-server = pkgs.callPackage ./package.nix { };
          vm = self.nixosConfigurations.vm.config.system.build.toplevel;
        }
      );

      overlays.default = final: prev: {
        inherit (self.packages.${final.system}) zulip-server;
      };

      nixosModules.default = ./module.nix;

      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [
            self.overlays.default
          ];
        };

        modules = [
          "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
          self.nixosModules.default
          (
            { modulesPath, ... }:
            {
              virtualisation.graphics = false;
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
            program = "${self.nixosConfigurations.vm.config.system.build.vm}/bin/run-nixos-vm";
          };
        }
      );

      checks = forAllSystems (
        system: pkgs: {
          default = (pkgs.extend self.overlays.default).nixosTest (import ./test.nix);
        }
      );
    };
}
