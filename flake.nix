{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = inputs:
    let
      inherit (inputs.nixpkgs) lib;
      foreach = xs: f: with lib; foldr recursiveUpdate { } (
        if isList xs then map f xs
        else if isAttrs xs then mapAttrsToList f xs
        else throw "foreach: expected list or attrset but got ${typeOf xs}"
      );
      overlay = final: prev: {
        zulip = final.callPackage ./package.nix { };
      };
      nixosConfig = { modulesPath, ... }: {
        imports = [
          "${modulesPath}/virtualisation/qemu-vm.nix"
          ./module.nix
        ];
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
      };
    in
    {
      inherit overlay;
    }
    //
    foreach inputs.nixpkgs.legacyPackages (system: pkgs':
      let pkgs = pkgs'.extend overlay; in
      {
        legacyPackages.${system} = pkgs;
        packages.${system} = rec {
          inherit (pkgs.nixos nixosConfig) vm;
          default = vm;
        };
        checks.${system}.default = pkgs.nixosTest (import ./test.nix);
      }
    );
}
